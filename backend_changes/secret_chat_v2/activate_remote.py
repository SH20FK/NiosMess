"""Activate the tested additive release; keep a DB backup and code rollback."""
from inspect_remote import connect, run
from stage_remote import RELEASE, CHECKS

SCRIPT = r'''
import json, os, sqlite3, subprocess, time, urllib.request
from pathlib import Path
from dotenv import dotenv_values

current=Path('/opt/niosmess/current')
old=current.resolve()
target=Path('/opt/niosmess/releases/secret-chats-v2-20261008')
assert old == Path('/opt/niosmess/releases/nios-apps-endpoint-20261005'), 'Active release changed'
assert target.is_dir() and target != old
pid=subprocess.check_output(['systemctl','show','niosmess.service','-p','MainPID','--value'],text=True).strip()
env={}
for item in Path('/proc/'+pid+'/environ').read_bytes().split(b'\0'):
 if b'=' in item:
  key,value=item.split(b'=',1); env[key.decode()]=value.decode()
working=Path('/var/lib/niosmess')
config=dict(dotenv_values(working/'.env')); config.update(env)
url=config.get('DATABASE_URL','sqlite+aiosqlite:///./messenger.db')
assert url.startswith('sqlite+aiosqlite:///'), 'Expected SQLite deployment'
database=Path(url[len('sqlite+aiosqlite:///'):])
if not database.is_absolute(): database=working/database
database=database.resolve()
assert database.is_file() and database.is_relative_to(working), 'Unexpected database location'
backups=Path('/opt/niosmess/checks-secret-v2-20261008/backups')
backups.mkdir(mode=0o700,exist_ok=True); backups.chmod(0o700)
backup=backups/'before-secret-v2.sqlite'
assert not backup.exists(), 'Backup already exists; inspect deployment state before retrying'
with sqlite3.connect('file:'+str(database)+'?mode=ro',uri=True) as source:
 with sqlite3.connect(backup) as destination: source.backup(destination)
backup.chmod(0o600)
print('Consistent database backup saved',flush=True)

def switch(path):
 next_path=Path('/opt/niosmess/current.secret-v2-next')
 assert not next_path.exists() and not next_path.is_symlink()
 next_path.symlink_to(path,target_is_directory=True)
 os.replace(next_path,current)
 subprocess.run(['systemctl','restart','niosmess.service'],check=True)

try:
 switch(target)
 healthy=False
 for attempt in range(20):
  time.sleep(1)
  try:
   with urllib.request.urlopen('http://127.0.0.1:5095/api/public/stats',timeout=2) as response:
    healthy=response.status==200
   if healthy: break
  except Exception: pass
 assert healthy, 'Health endpoint failed'
 subprocess.run(['systemctl','is-active','--quiet','niosmess.service'],check=True)
 with sqlite3.connect('file:'+str(database)+'?mode=ro',uri=True) as db:
  tables={row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
  assert {'secret_events','secret_operations','secret_device_capabilities','secret_legacy_cursors'} <= tables
  assert 'client_message_id' in {row[1] for row in db.execute('PRAGMA table_info(messages)')}
  assert 'session_id' in {row[1] for row in db.execute('PRAGMA table_info(users_fcm_tokens)')}
 print('New release active; health and additive schema verified',flush=True)
except Exception:
 switch(old)
 print('Code rolled back; additive database and client queues are preserved',flush=True)
 raise
'''

if __name__ == '__main__':
    client = connect()
    try:
        with client.open_sftp() as sftp:
            with sftp.file(CHECKS + '/activate.py', 'w') as output:
                output.write(SCRIPT)
        print(run(client, f'/opt/niosmess/venv/bin/python {CHECKS}/activate.py'))
    finally:
        client.close()
