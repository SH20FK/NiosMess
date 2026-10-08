"""Prepare and test a copied release. Does not switch current or restart."""
from pathlib import Path
from inspect_remote import connect, run

RELEASE = '/opt/niosmess/releases/secret-chats-v2-20261008'
CHECKS = '/opt/niosmess/checks-secret-v2-20261008'

if __name__ == '__main__':
    client = connect()
    try:
        print(run(client, "python3 - <<'PY'\nfrom pathlib import Path\nimport shutil\nsource=Path('/opt/niosmess/current').resolve()\ntarget=Path('" + RELEASE + "')\nassert source == Path('/opt/niosmess/releases/nios-apps-endpoint-20261005'), 'Active release changed'\nif not target.exists(): shutil.copytree(source,target,symlinks=True)\nassert target.resolve() != source\nfor name in ('app/models/models.py','app/services/utils.py','app/migrations.py','app/ws/handlers/profile_handler.py','app/ws/router.py','app/ws/connection_manager.py','app/ws/handlers/media_handler.py'):\n shutil.copy2(source/name,target/name)\nPath('" + CHECKS + "').mkdir(exist_ok=True)\nprint('Staged copy ready')\nPY"))
        with client.open_sftp() as sftp:
            for name in ('apply.py', 'secret_chat_v2.py', 'test_secret_delivery.py', 'serve_isolated.py'):
                sftp.put(str(Path(__file__).with_name(name)), CHECKS + '/' + name)
        print(run(client, f'/opt/niosmess/venv/bin/python {CHECKS}/apply.py {RELEASE}'))
        print(run(client, f'/opt/niosmess/venv/bin/python -m compileall -q {RELEASE}/app'))
        print(run(client, f'/opt/niosmess/venv/bin/python -m pip install --quiet --target {CHECKS}/deps pytest==8.3.5 pytest-asyncio==0.25.3'))
        print(run(client, f"cd {RELEASE} && PYTHONPATH={CHECKS}/deps:{RELEASE}:{RELEASE}/tests SECRET_KEY=test-only ENCRYPTION_KEY=00000000000000000000000000000000 DATABASE_URL=sqlite+aiosqlite:// /opt/niosmess/venv/bin/python -m pytest {CHECKS}/test_secret_delivery.py -q -c {RELEASE}/pytest.ini"))
        print('Active service and database were not changed.')
    finally:
        client.close()
