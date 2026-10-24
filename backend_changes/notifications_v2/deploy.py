"""Stage isolated tests, then atomically activate a guarded additive release.

No credentials, tokens, payload bodies or database contents are printed. The
SQLite migration is additive and remains compatible with the previous release.
"""
import argparse
from datetime import datetime, timezone
import importlib.util
from pathlib import Path
import posixpath
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent


def connect():
    spec = importlib.util.spec_from_file_location('private_ssh', ROOT/'backend_changes/secret_chat_v2/inspect_remote.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.connect()


def execute(client, source, timeout=60):
    stdin, stdout, stderr = client.exec_command('/opt/niosmess/venv/bin/python -', timeout=timeout)
    stdin.write(source)
    stdin.channel.shutdown_write()
    output, error = stdout.read().decode(), stderr.read().decode()
    status = stdout.channel.recv_exit_status()
    print(output, end='', flush=True)
    if status:
        raise RuntimeError(f'notification_deployment_failed:{status}:{error[-6000:]}')
    if error:
        print(error[-6000:], file=sys.stderr)


def upload(client, destination):
    with client.open_sftp() as sftp:
        def mkdir(path):
            try: sftp.stat(path)
            except FileNotFoundError:
                mkdir(posixpath.dirname(path)); sftp.mkdir(path, 0o700)
        for file in SOURCE.rglob('*.py'):
            if '__pycache__' in file.parts: continue
            target = destination + '/' + file.relative_to(SOURCE).as_posix()
            mkdir(posixpath.dirname(target))
            sftp.put(str(file), target)
            sftp.chmod(target, 0o600)


def stage(client, name):
    tools = '/opt/niosmess/notification-tools/' + name
    upload(client, tools)
    execute(client, STAGE.replace('TOOLS_VALUE', repr(tools)).replace('NAME_VALUE', repr(name)), timeout=60)


STAGE = '''
import hashlib,importlib.util,json,os,pathlib,shutil,subprocess,sys,tempfile
tools=pathlib.Path(TOOLS_VALUE)
current=pathlib.Path('/opt/niosmess/current').resolve(strict=True)
candidate=pathlib.Path('/opt/niosmess/releases')/NAME_VALUE
if not str(current).startswith('/opt/niosmess/releases/') or candidate.exists():raise RuntimeError('release_precondition')
if shutil.disk_usage(current).free < 256*1024**2:raise RuntimeError('insufficient_disk')
spec=importlib.util.spec_from_file_location('patch',tools/'patch_host.py');patch=importlib.util.module_from_spec(spec);spec.loader.exec_module(patch)
guarded=list(patch.FILES)
if (current/'app/services/notification_delivery.py').exists():guarded.append('app/services/notification_delivery.py')
hashes={f:hashlib.sha256((current/f).read_bytes()).hexdigest() for f in guarded}
for f in patch.FILES:
 if (current/f).is_symlink():raise RuntimeError('unexpected_source_symlink')
shutil.copytree(current,candidate,symlinks=True,ignore=shutil.ignore_patterns('__pycache__','.pytest_cache','.git'))
modified=patch.apply(candidate)
for base,dirs,files in os.walk(candidate,followlinks=False):
 for name in ['.']+dirs+files:
  target=pathlib.Path(base)/name;original=current/target.relative_to(candidate)
  if original.exists() or original.is_symlink():
   stat=original.lstat();os.chown(target,stat.st_uid,stat.st_gid,follow_symlinks=False)
module=candidate/'app/services/notification_delivery.py';stat=(current/'app/services/secret_chat_v2.py').stat()
os.chown(module,stat.st_uid,stat.st_gid);os.chmod(module,stat.st_mode & 0o777)
for f in modified:compile((candidate/f).read_text(),f,'exec')
env=dict(os.environ, PYTHONPATH=str(candidate), DATABASE_URL='sqlite+aiosqlite:///:memory:', NIOS_NOTIFICATION_HOST_TEST='1')
result=subprocess.run(['/opt/niosmess/venv/bin/python','-m','unittest','discover','-s',str(tools/'tests'),'-v'],cwd='/var/lib/niosmess',env=env,text=True,capture_output=True,timeout=50)
print(result.stdout);print(result.stderr)
if result.returncode:raise RuntimeError('isolated_tests_failed')
receipt={'previous':str(current),'candidate':str(candidate),'hashes':hashes,'modified':modified}
(tools/'receipt.json').write_text(json.dumps(receipt));os.chmod(tools/'receipt.json',0o600)
print('STAGED_AND_TESTED '+candidate.name)
'''


ACTIVATE = r'''
import asyncio,hashlib,json,os,pathlib,re,sqlite3,subprocess,sys,time,urllib.request
tools=pathlib.Path(TOOLS_VALUE);receipt=json.loads((tools/'receipt.json').read_text())
current=pathlib.Path('/opt/niosmess/current').resolve(strict=True)
if str(current)!=receipt['previous']:raise RuntimeError('concurrent_release_change')
for f,digest in receipt['hashes'].items():
 if hashlib.sha256((current/f).read_bytes()).hexdigest()!=digest:raise RuntimeError('concurrent_source_change')
exec_start=subprocess.check_output(['systemctl','show','niosmess.service','-p','ExecStart','--value'],text=True)
port=re.search(r'--port (\d+)',exec_start)
if not port or '--host 127.0.0.1' not in exec_start:raise RuntimeError('unexpected_service_binding')
health_url='http://127.0.0.1:'+port.group(1)+'/openapi.json'
def healthy():
 with urllib.request.urlopen(health_url,timeout=3) as response:
  document=json.load(response)
  return response.status==200 and bool(document.get('openapi')) and any(path.startswith('/v1/devices/') for path in document.get('paths',{}))
if not healthy():raise RuntimeError('pre_release_health_failed')
candidate=pathlib.Path(receipt['candidate']);sys.path.insert(0,str(candidate));os.chdir('/var/lib/niosmess')
from app.database import engine
from sqlalchemy import inspect,text
async def migrate():
 async with engine.begin() as conn:
  columns=await conn.run_sync(lambda c:[v['name'] for v in inspect(c).get_columns('users_fcm_tokens')])
  if 'notification_preferences' not in columns:await conn.execute(text('ALTER TABLE users_fcm_tokens ADD COLUMN notification_preferences TEXT'))
 await engine.dispose()
database=engine.url.database
if engine.url.get_backend_name()!='sqlite' or not database:raise RuntimeError('unexpected_database_backend')
backup=tools/'before.sqlite3'
with sqlite3.connect(database) as src,sqlite3.connect(backup) as dst:src.backup(dst)
os.chmod(backup,0o600)
subprocess.run(['systemctl','stop','niosmess.service'],check=True)
try:
 asyncio.run(migrate())
 temporary=pathlib.Path('/opt/niosmess/current-notification-next')
 if temporary.exists() or temporary.is_symlink():raise RuntimeError('activation_link_exists')
 temporary.symlink_to(candidate);os.replace(temporary,'/opt/niosmess/current')
 subprocess.run(['systemctl','start','niosmess.service'],check=True)
 is_healthy=False
 for attempt in range(20):
  time.sleep(1)
  try:
   if healthy():is_healthy=True;break
  except Exception:pass
 if not is_healthy:raise RuntimeError('post_release_health_failed')
except Exception:
 subprocess.run(['systemctl','stop','niosmess.service'],check=False)
 rollback=pathlib.Path('/opt/niosmess/current-notification-rollback');rollback.symlink_to(current);os.replace(rollback,'/opt/niosmess/current')
 subprocess.run(['systemctl','start','niosmess.service'],check=True)
 raise
print('ACTIVATED_HEALTHY '+candidate.name)
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['stage', 'activate'])
    parser.add_argument('--name', default='notifications-v2-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    args = parser.parse_args()
    if not args.name.startswith('notifications-v2-') or not all(c.isalnum() or c=='-' for c in args.name):
        raise ValueError('invalid_release_name')
    client = connect()
    try:
        if args.mode == 'stage': stage(client, args.name)
        else: execute(client, ACTIVATE.replace('TOOLS_VALUE', repr('/opt/niosmess/notification-tools/'+args.name)))
    finally: client.close()


if __name__ == '__main__':
    main()
