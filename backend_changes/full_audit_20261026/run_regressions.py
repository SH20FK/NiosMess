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
AST_FINGERPRINT_ALGORITHM = 'sha256-canonical-ast-v1-empty-type-params'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_ast(value):
    """Retain semantic fields without depending on ast.dump's Python version.

    Python 3.12 added empty type_params to FunctionDef/AsyncFunctionDef/ClassDef.
    Only this empty field is equivalent to its absence; real type parameters,
    annotations, decorators, defaults and function bodies remain fingerprinted.
    Source locations are excluded, as with include_attributes=False.
    """
    if isinstance(value, ast.AST):
        return {
            'node': type(value).__name__,
            'fields': [
                [name, canonical_ast(field)]
                for name, field in ast.iter_fields(value)
                if not (name == 'type_params' and isinstance(field, list) and not field)
            ],
        }
    if isinstance(value, list):
        return [canonical_ast(item) for item in value]
    if isinstance(value, tuple):
        return {'tuple': [canonical_ast(item) for item in value]}
    if isinstance(value, bytes):
        return {'bytes': value.hex()}
    if isinstance(value, complex):
        return {'complex': [value.real, value.imag]}
    if value is Ellipsis:
        return {'ellipsis': True}
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    raise TypeError(f'Unsupported AST field value: {type(value).__name__}')


def ast_fingerprint(node):
    encoded = json.dumps(
        canonical_ast(node), ensure_ascii=True, sort_keys=True,
        separators=(',', ':'), allow_nan=False,
    ).encode('utf-8')
    return hashlib.sha256(encoded).hexdigest()


def function_fingerprints(tree):
    return {
        node.name: ast_fingerprint(node)
        for node in tree.body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
    }


def check_symbols(tree, expected, path):
    if function_fingerprints(tree) != expected:
        raise RuntimeError(f'Source AST mismatch: {path}')


def verify_ast_fingerprint_regression():
    """Isolated 3.10/3.12 shape equivalence and real-change rejection checks."""
    source = 'def fixture(value: int = 1) -> int:\n    return value + 7\n'

    def version_shape(include_type_params):
        tree = ast.parse(source)
        function = tree.body[0]
        fields = tuple(name for name in function._fields if name != 'type_params')
        function._fields = fields + (('type_params',) if include_type_params else ())
        if include_type_params:
            function.type_params = []
        elif hasattr(function, 'type_params'):
            del function.type_params
        return tree

    legacy = version_shape(False)
    modern = version_shape(True)
    expected = function_fingerprints(legacy)
    if ast.dump(legacy) == ast.dump(modern):
        raise RuntimeError('Verifier regression did not model distinct AST shapes')
    check_symbols(modern, expected, 'self-test Python 3.10/3.12 shape')

    mutations = []
    changed_body = version_shape(True)
    changed_body.body[0].body[0].value.right.value = 8
    mutations.append(('changed return value', changed_body))
    changed_default = version_shape(True)
    changed_default.body[0].args.defaults[0].value = 2
    mutations.append(('changed default argument', changed_default))
    generic = version_shape(True)
    generic.body[0].type_params = [ast.Name(id='T', ctx=ast.Load())]
    mutations.append(('nonempty type_params', generic))
    for label, tree in mutations:
        try:
            check_symbols(tree, expected, f'self-test {label}')
        except RuntimeError:
            continue
        raise RuntimeError(f'AST verifier accepted a semantic mutation: {label}')


def verify_package():
    verify_ast_fingerprint_regression()
    manifest = json.loads((ROOT / 'manifest.json').read_text(encoding='utf-8'))
    if manifest.get('ast_fingerprint_algorithm') != AST_FINGERPRINT_ALGORITHM:
        raise RuntimeError('Unknown AST fingerprint format')
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
        check_symbols(tree, item['symbols'], item['path'])
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
