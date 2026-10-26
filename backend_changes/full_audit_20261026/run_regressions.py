"""Offline regression entry point: no production configuration, SSH or network."""

import ast
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_package():
    manifest = json.loads((ROOT / 'manifest.json').read_text(encoding='utf-8'))
    for relative, expected in manifest['files'].items():
        path = (ROOT / relative).resolve()
        if ROOT not in path.parents or digest(path) != expected:
            raise RuntimeError(f'Package integrity mismatch: {relative}')
    for item in manifest['deployed_files']:
        path = ROOT / 'candidate' / item['path']
        if digest(path) != item['after_sha256']:
            raise RuntimeError(f'Deployed source mismatch: {item["path"]}')
    for item in manifest['fixture_sources']:
        tree = ast.parse((ROOT / item['path']).read_text(encoding='utf-8'))
        symbols = {
            node.name: hashlib.sha256(
                ast.dump(node, include_attributes=False).encode()
            ).hexdigest()
            for node in tree.body
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
        }
        if symbols != item['symbols']:
            raise RuntimeError(f'Source AST mismatch: {item["path"]}')
    schema = manifest['orm_fixture']
    if digest(ROOT / schema['path']) != schema['source_sha256']:
        raise RuntimeError('The actual ORM schema fixture was modified')


def run(script, *, baseline=False):
    environment = os.environ.copy()
    environment.pop('NIOS_CALL_ACCESS_BASELINE', None)
    environment['PYTHONDONTWRITEBYTECODE'] = '1'
    if baseline:
        environment['NIOS_CALL_ACCESS_BASELINE'] = '1'
    subprocess.run(
        [sys.executable, '-B', str(ROOT / 'tests' / script)],
        cwd=ROOT,
        env=environment,
        check=True,
    )


def main():
    if sys.version_info < (3, 10):
        raise RuntimeError('Python 3.10 or newer is required')
    for command in ('ffmpeg', 'ffprobe'):
        if not shutil.which(command):
            raise RuntimeError(f'{command} is required; skipping media tests is forbidden')
        subprocess.run(
            [command, '-version'],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
    verify_package()
    print('Source hashes and extracted baseline AST verified.', flush=True)
    print('1/3: patched call handlers, 15 isolated SQLite regressions', flush=True)
    run('test_call_access.py')
    print('2/3: actual ffmpeg/ffprobe video validation, 11 checks', flush=True)
    run('test_video_emoji_validation.py')
    print('3/3: baseline vulnerability evidence, 5 isolated checks', flush=True)
    run('test_call_access.py', baseline=True)
    print('PASS: 26 candidate/video checks and 5 baseline evidence checks.', flush=True)


if __name__ == '__main__':
    main()
