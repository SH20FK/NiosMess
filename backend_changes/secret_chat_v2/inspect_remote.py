"""Read-only deployment preflight; credentials are never printed."""
from pathlib import Path
import paramiko


def connect():
    cfg = {}
    for line in Path(__file__).resolve().parents[2].joinpath('.env').read_text(encoding='utf-8-sig').splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            key, value = line.split('=', 1)
            cfg[key.strip()] = value.strip().strip('\"\'')
    client = paramiko.SSHClient()
    client.load_system_host_keys()
    client.connect(cfg['SSH_HOST'], username=cfg['SSH_USER'], password=cfg['SSH_PASSWORD'],
                   timeout=15, allow_agent=False, look_for_keys=False)
    return client


def run(client, command):
    _, stdout, stderr = client.exec_command(command, timeout=60)
    out, err = stdout.read().decode(), stderr.read().decode()
    status = stdout.channel.recv_exit_status()
    if status:
        raise RuntimeError(f'Remote check failed ({status}): {err[:1000]}')
    return out


if __name__ == '__main__':
    client = connect()
    try:
        print(run(client, 'readlink -f /opt/niosmess/current'))
        print(run(client, 'systemctl show niosmess.service -p WorkingDirectory -p EnvironmentFiles'))
        print(run(client, "/opt/niosmess/venv/bin/python -c \"import importlib.util; print('pytest:', bool(importlib.util.find_spec('pytest'))); print('pytest_asyncio:', bool(importlib.util.find_spec('pytest_asyncio')))\""))
        print(run(client, "find /opt/niosmess/current/tests -maxdepth 1 -name 'test_secret_chat_hardening.py'"))
    finally:
        client.close()
