"""Published artifacts are authoritative; include each ABI's size and SHA256."""
import datetime
import hashlib
import json
import pathlib
import re
import sys
import os
from urllib.parse import quote


def add_windows_asset(folder):
    manifest = folder / 'version.json'
    result = json.loads(manifest.read_text(encoding='utf-8'))
    file = folder / 'niosmess-windows-setup.exe'
    with file.open('rb') as source:
        digest = hashlib.file_digest(source, 'sha256').hexdigest()
    result['windows_asset'] = {
        'url': result['windows_download_url'],
        'size': file.stat().st_size, 'sha256': digest,
    }
    manifest.write_text(json.dumps(result, ensure_ascii=True, indent=2), encoding='utf-8')


def main():
    root = pathlib.Path(__file__).resolve().parents[1]
    version = re.search(r'^version:\s*(\S+)', (root / 'pubspec.yaml').read_text(encoding='utf-8'), re.M).group(1)
    base = version.split('+')[0]
    content = (root.parent / 'CHANGELOG.md').read_text(encoding='utf-8')
    section = re.search(r'##\s*\[' + re.escape(base) + r'\][^\n]*\n(.*?)(?=\n##\s*\[|\Z)', content, re.S)
    if not section:
        raise ValueError('Latest version changelog is missing')
    tag = os.environ.get('GITHUB_REF_NAME', 'latest') if os.environ.get('GITHUB_REF_TYPE') == 'tag' else 'latest'
    url = f'https://github.com/SH20FK/NiosMess/releases/download/{quote(tag, safe="")}/'
    assets = {}
    for abi in ('universal', 'arm64-v8a', 'armeabi-v7a', 'x86_64'):
        name = 'niosmess.apk' if abi == 'universal' else f'niosmess-{abi}.apk'
        file = root / 'dist/android' / name
        if not file.is_file():
            raise ValueError(f'Missing artifact: {name}')
        with file.open('rb') as source:
            digest = hashlib.file_digest(source, 'sha256').hexdigest()
        assets[abi] = {'url': url + name, 'size': file.stat().st_size, 'sha256': digest}
    result = {'version': version, 'tag_name': tag,
              'build_commit': os.environ.get('GITHUB_SHA', 'unknown'),
              'changelog': section.group(1).strip(),
              'download_url': assets['universal']['url'],
              'windows_download_url': url + 'niosmess-windows-setup.exe',
              'android_assets': assets,
              'published_at': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    (root / 'version.json').write_text(json.dumps(result, ensure_ascii=True, indent=2), encoding='utf-8')
    (root / 'changelog_release.txt').write_text(result['changelog'], encoding='utf-8')
    print(f'app_version={version}')


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--windows-dir':
        add_windows_asset(pathlib.Path(sys.argv[2]))
    else:
        main()
