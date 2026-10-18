"""Stage/test additive APIs, then atomically activate an already tested release.

Uses the existing private SSH helper; never prints credentials or server source.
The marker records the precise current release and modified-file hashes. Any
concurrent deployment or source change aborts activation instead of overwriting.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import posixpath

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent


def helper():
    specification = importlib.util.spec_from_file_location("ssh_helper", ROOT / "backend_changes/secret_chat_v2/inspect_remote.py")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def remote_python(client, source: str, *, timeout=60):
    stdin, stdout, stderr = client.exec_command("/opt/niosmess/venv/bin/python -", timeout=timeout)
    stdin.write(source)
    stdin.channel.shutdown_write()
    output, error = stdout.read().decode(), stderr.read().decode()
    status = stdout.channel.recv_exit_status()
    if output:
        print(output, end="", flush=True)
    if status:
        # Only our diagnostics/test output, never environment dumps or source.
        raise RuntimeError(f"remote_operation_failed:{status}:{error[-3000:]}")
    return output


def upload(client, source: Path, destination: str):
    sftp = client.open_sftp()
    try:
        def mkdir(path):
            try:
                sftp.stat(path)
            except FileNotFoundError:
                mkdir(posixpath.dirname(path))
                sftp.mkdir(path, 0o700)
        for local in source.rglob("*"):
            if not local.is_file() or "__pycache__" in local.parts or ".pytest_cache" in local.parts:
                continue
            if local.suffix not in (".py", ".txt", ".md", ".toml", ".ini"):
                continue
            target = destination + "/" + local.relative_to(source).as_posix()
            mkdir(posixpath.dirname(target))
            sftp.put(str(local), target)
            sftp.chmod(target, 0o600)
    finally:
        sftp.close()


def stage(client, name: str):
    if not name.startswith("protocol-v1-") or not all(char.isalnum() or char == "-" for char in name):
        raise ValueError("invalid_release_name")
    candidate = "/opt/niosmess/releases/" + name
    uploaded = "/opt/niosmess/protocol-tools/" + name
    upload(client, SOURCE, uploaded)
    print("Uploaded protocol sources and isolated tests", flush=True)
    script = '''
import hashlib,importlib.util,json,os,pathlib,pwd,grp,shutil,subprocess,sys
candidate=pathlib.Path(CANDIDATE)
tools=pathlib.Path(TOOLS)
sys.path.insert(0,str(tools))
from release_guard import fingerprint,assert_regular_sources
previous=pathlib.Path('/opt/niosmess/current').resolve(strict=True)
if not str(previous).startswith('/opt/niosmess/releases/') or candidate.exists():raise RuntimeError('release_precondition')
if shutil.disk_usage('/var/lib/niosmess').free < 2*1024**3:raise RuntimeError('insufficient_disk')
assert_regular_sources(previous,('app/main.py','app/services/secret_chat_v2.py','app/services/utils.py','app/ws/handlers/profile_handler.py'))
snapshot=fingerprint(previous)
shutil.copytree(previous,candidate,symlinks=True,ignore=shutil.ignore_patterns('__pycache__','.pytest_cache','.git'))
for base,dirs,files in os.walk(candidate,followlinks=False):
 for name in ['.']+dirs+files:
  target=pathlib.Path(base)/name;relative=target.relative_to(candidate)
  source=previous/relative
  if source.exists() or source.is_symlink():
   st=source.lstat();os.chown(target,st.st_uid,st.st_gid,follow_symlinks=False)
shutil.copytree(tools/'nios_protocol',candidate/'nios_protocol')
service_user=subprocess.check_output(['systemctl','show','niosmess.service','-p','User','--value'],text=True).strip() or 'root'
service=pwd.getpwnam(service_user)
for base,dirs,files in os.walk(candidate/'nios_protocol'):
 os.chown(base,0,service.pw_gid);os.chmod(base,0o750)
 for name in files:os.chown(pathlib.Path(base)/name,0,service.pw_gid);os.chmod(pathlib.Path(base)/name,0o640)
s=importlib.util.spec_from_file_location('patch_host',tools/'patch_host.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
patched=m.apply(candidate)
subprocess.run([sys.executable,'-m','compileall','-q',str(candidate/'nios_protocol')],check=True)
venv=pathlib.Path('/opt/niosmess/protocol-test-venv')
if not (venv/'bin/python').exists():subprocess.run([sys.executable,'-m','venv','--system-site-packages',str(venv)],check=True)
subprocess.run([str(venv/'bin/python'),'-m','pip','install','--disable-pip-version-check','--quiet','pytest>=8,<9','pytest-asyncio>=0.24,<2'],check=True)
env=dict(os.environ,NIOS_HOST_SOURCE=str(candidate),PYTHONPATH=str(candidate)+':'+str(tools),
         PYTEST_ADDOPTS='--asyncio-mode=auto',ENCRYPTION_KEY='protocol-fixture-only-isolated-key',
         DATABASE_URL='sqlite+aiosqlite:///'+str(tools/'unused-host.sqlite3'))
result=subprocess.run([str(venv/'bin/python'),'-m','pytest',str(tools/'tests'),'-q','--tb=short'],env=env,cwd='/var/lib/niosmess',text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
(tools/'test-results.txt').write_text(result.stdout)
print(result.stdout[-18000:],flush=True)
if result.returncode:raise RuntimeError('candidate_tests_failed')
env.pop('NIOS_HOST_SOURCE',None)
legacy=subprocess.run([str(venv/'bin/python'),str(tools/'run_host_regressions.py'),str(candidate)],env=env,cwd='/var/lib/niosmess',text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
(tools/'legacy-test-results.txt').write_text(legacy.stdout)
print(legacy.stdout[-8000:],flush=True)
if legacy.returncode:raise RuntimeError('legacy_tests_failed')
if fingerprint(previous)!=snapshot:raise RuntimeError('source_changed_during_stage')
marker={'candidate':str(candidate),'previous':str(previous),'original_hashes':snapshot,'candidate_hashes':fingerprint(candidate),'patched_hashes':patched,'tools':str(tools),'tested':True}
(tools/'release.json').write_text(json.dumps(marker,indent=2))
os.chmod(tools/'release.json',0o600)
print(json.dumps({'staged':str(candidate),'tests':'passed','previous':str(previous)}),flush=True)
'''.replace("CANDIDATE", repr(candidate)).replace("TOOLS", repr(uploaded))
    remote_python(client, script, timeout=300)
    return {"candidate": candidate, "tools": uploaded, "name": name}


def activate(client, marker_path: str):
    if not marker_path.startswith("/opt/niosmess/protocol-tools/protocol-v1-") or not marker_path.endswith("/release.json"):
        raise ValueError("invalid_marker")
    script = '''
import asyncio,fcntl,hashlib,json,os,pathlib,pwd,secrets,shutil,stat,subprocess,sys,time,urllib.request,urllib.error
deployment_lock=open('/opt/niosmess/.protocol-deploy.lock','a+b')
fcntl.flock(deployment_lock.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
marker=json.loads(pathlib.Path(MARKER).read_text())
sys.path.insert(0,marker['tools'])
from release_guard import fingerprint
candidate=pathlib.Path(marker['candidate']);previous=pathlib.Path(marker['previous'])
current=pathlib.Path('/opt/niosmess/current')
if not marker['tested'] or current.resolve()!=previous:raise RuntimeError('concurrent_deployment')
if fingerprint(previous)!=marker['original_hashes']:raise RuntimeError('concurrent_source_change')
if fingerprint(candidate)!=marker['candidate_hashes']:raise RuntimeError('candidate_changed')
service_user=subprocess.check_output(['systemctl','show','niosmess.service','-p','User','--value'],text=True).strip() or 'root'
service=pwd.getpwnam(service_user)
root=pathlib.Path('/var/lib/niosmess/protocol-v1')
if root.is_symlink():raise RuntimeError('protocol_data_symlink')
root.mkdir(mode=0o700,exist_ok=True);os.chmod(root,0o700);os.chown(root,service.pw_uid,service.pw_gid)
key=root/'key-log.seed'
if key.is_symlink() or (key.exists() and not key.is_file()):raise RuntimeError('protocol_key_must_be_regular')
if not key.exists():
 fd=os.open(key,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
 with os.fdopen(fd,'wb') as h:h.write(secrets.token_bytes(32));h.flush();os.fsync(h.fileno())
key_fd=os.open(key,os.O_RDONLY|os.O_NOFOLLOW)
try:
 if not stat.S_ISREG(os.fstat(key_fd).st_mode):raise RuntimeError('protocol_key_must_be_regular')
 os.fchmod(key_fd,0o600);os.fchown(key_fd,service.pw_uid,service.pw_gid)
finally:os.close(key_fd)
initialize="import asyncio;from pathlib import Path;from nios_protocol.store import ProtocolStore;from nios_protocol.blobs import SCHEMA;root=Path('/var/lib/niosmess/protocol-v1');store=ProtocolStore(root/'protocol.sqlite3',root);asyncio.run(store.ensure_schema(SCHEMA))"
subprocess.run(['runuser','-u',service_user,'--',sys.executable,'-c',initialize],
               env=dict(os.environ,PYTHONPATH=str(candidate)),cwd='/var/lib/niosmess',check=True)
# Nginx's existing catch-all limits uploads to 30 MiB. Scope streaming's
# larger bodies/backpressure to /v1 only, preserving all other applications.
nginx=pathlib.Path('/etc/nginx/sites-enabled/ni-os.ru').resolve(strict=True)
original=nginx.read_text()
needle='    location / {'
if original.count(needle)!=1 or 'location ^~ /v1/' in original:raise RuntimeError('nginx_patch_precondition')
addition=''' + repr('''    # Nios protocol v1: immutable ciphertext, bounded by authenticated API quotas.
    location ^~ /v1/ {
        client_max_body_size 272m;
        client_body_timeout 30s;
        proxy_pass http://127.0.0.1:5095;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
        proxy_request_buffering off;
        proxy_buffering off;
        proxy_read_timeout 330s;
        proxy_send_timeout 330s;
    }

''') + '''
backup=pathlib.Path(marker['tools'])/'nginx-before.conf';backup.write_text(original);os.chmod(backup,0o600)
updated=original.replace(needle,addition+needle,1)
def write_nginx(value):
 temp=nginx.with_name(nginx.name+'.protocol.tmp');temp.write_text(value);os.chmod(temp,0o644);os.replace(temp,nginx)
def switch(path):
 temp=pathlib.Path('/opt/niosmess/current.protocol.tmp')
 if temp.is_symlink():temp.unlink()
 temp.symlink_to(path,target_is_directory=True);os.replace(temp,current)
switched=False
nginx_changed=False
try:
 if current.resolve()!=previous or fingerprint(previous)!=marker['original_hashes']:raise RuntimeError('concurrent_deployment_before_switch')
 if fingerprint(candidate)!=marker['candidate_hashes']:raise RuntimeError('candidate_changed_before_switch')
 if nginx.read_text()!=original:raise RuntimeError('concurrent_nginx_change')
 write_nginx(updated)
 nginx_changed=True
 result=subprocess.run(['nginx','-t'],capture_output=True,text=True)
 if result.returncode:raise RuntimeError('nginx_validation_failed')
 switch(candidate)
 switched=True
 subprocess.run(['systemctl','restart','niosmess.service'],check=True)
 good=False
 for unused in range(25):
  try:
   with urllib.request.urlopen('http://127.0.0.1:5095/health/ready',timeout=2) as r:good=r.status==200
  except Exception:pass
  if good:break
  time.sleep(1)
 if not good:raise RuntimeError('readiness_failed')
 subprocess.run(['systemctl','reload','nginx'],check=True)
 for url in ('http://127.0.0.1:5095/v1/protocols','https://ni-os.ru/v1/protocols'):
  try:urllib.request.urlopen(url,timeout=10);raise RuntimeError('unauthenticated_protocol_access')
  except urllib.error.HTTPError as e:
   if e.code!=401:raise RuntimeError('protocol_route_failed')
except BaseException:
 if nginx_changed and nginx.read_text()==updated:write_nginx(original)
 if switched and current.resolve() in (candidate,previous):
  switch(previous)
  subprocess.run(['systemctl','restart','niosmess.service'],check=False)
  subprocess.run(['systemctl','reload','nginx'],check=False)
 elif switched:print('Concurrent deployment detected; third-party release preserved',flush=True)
 raise
marker['activated']=True;marker['nginx_backup']=str(backup)
pathlib.Path(MARKER).write_text(json.dumps(marker,indent=2))
print(json.dumps({'active':str(current.resolve()),'readiness':'ok','https_protocol_auth':'401','rollback':str(previous)}),flush=True)
'''
    script = script.replace("MARKER", repr(marker_path))
    remote_python(client, script, timeout=120)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("stage", "activate"))
    parser.add_argument("--name")
    parser.add_argument("--marker")
    args = parser.parse_args()
    client = helper().connect()
    try:
        if args.mode == "stage":
            name = args.name or "protocol-v1-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            result = stage(client, name)
            destination = ROOT / "output/protocol-server-2026-10-18/deployment.json"
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(json.dumps(result, indent=2))
            print("Local deployment receipt:", destination)
        else:
            if not args.marker:
                parser.error("--marker required")
            activate(client, args.marker)
    finally:
        client.close()


if __name__ == "__main__":
    main()
