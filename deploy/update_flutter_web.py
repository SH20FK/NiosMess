"""Install only the public web artifact matching the published app commit.

No GitHub credential is needed on the host. Sources and databases are untouched.
"""
import fcntl
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import tempfile
import time
import urllib.request
import zipfile

ROOT=Path('/var/www/nios-flutter')
CACHE=Path('/var/cache/nios-web')
BASE='https://github.com/SH20FK/NiosMess/releases/download/latest/'
MAX_ARCHIVE=256*1024*1024


def read_json(url):
    request=urllib.request.Request(url,headers={'User-Agent':'Nios-Web-Updater','Cache-Control':'no-cache'})
    with urllib.request.urlopen(request,timeout=30) as response:
        data=response.read(65537)
    if len(data)>65536:raise ValueError('Oversized web metadata')
    return json.loads(data)


def validate(metadata):
    if not re.fullmatch('[0-9a-f]{40}',str(metadata.get('build_commit',''))):raise ValueError('Invalid commit')
    if not re.fullmatch('[0-9a-f]{64}',str(metadata.get('sha256',''))):raise ValueError('Invalid SHA256')
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+',str(metadata.get('version',''))):raise ValueError('Invalid version')
    if type(metadata.get('size')) is not int or not 1<=metadata['size']<=MAX_ARCHIVE:raise ValueError('Invalid archive size')
    if metadata.get('base_path')!='/web/':raise ValueError('Invalid base path')


def prepare_release(metadata,bundle):
    validate(metadata)
    digest=hashlib.sha256()
    with Path(bundle).open('rb') as source:
        for chunk in iter(lambda:source.read(1024*1024),b''):digest.update(chunk)
    if Path(bundle).stat().st_size!=metadata['size'] or digest.hexdigest()!=metadata['sha256']:
        raise ValueError('Web archive integrity failed')
    releases=ROOT/'releases';releases.mkdir(parents=True,exist_ok=True)
    dest=releases/(metadata['build_commit']+'-'+metadata['sha256'][:12])
    if dest.exists():
        if dest.is_symlink() or json.loads((dest/'deployment.json').read_text())['sha256']!=metadata['sha256']:
            raise ValueError('Unexpected existing release')
        return dest
    pending=Path(tempfile.mkdtemp(prefix='.incoming-',dir=releases))
    try:
        with zipfile.ZipFile(bundle) as z:
            entries=z.infolist()
            if len(entries)>5000 or sum(e.file_size for e in entries)>512*1024*1024:raise ValueError('Oversized expanded archive')
            seen=set()
            for entry in entries:
                path=PurePosixPath(entry.filename)
                if (path.is_absolute() or '..' in path.parts or '\\' in entry.filename or not path.parts
                    or path.parts[0]!='web' or (entry.external_attr>>16)&0o170000==0o120000
                    or entry.filename in seen):raise ValueError('Unsafe archive path')
                seen.add(entry.filename)
                target=(pending/str(path)).resolve()
                if not target.is_relative_to(pending.resolve()):raise ValueError('Escaped archive path')
            z.extractall(pending)
        info=json.loads((pending/'web/release-info.json').read_text())
        if any(info.get(k)!=metadata[k] for k in ('build_commit','version','base_path')):raise ValueError('Web metadata mismatch')
        if '<base href="/web/">' not in (pending/'web/index.html').read_text():raise ValueError('Wrong web base')
        for file in list(pending.rglob('*')):
            if file.is_file() and file.suffix in ('.js','.wasm','.json','.css','.svg') and file.stat().st_size>1024:
                with file.open('rb') as source,gzip.open(str(file)+'.gz','wb',compresslevel=6) as compressed:
                    shutil.copyfileobj(source,compressed)
                os.utime(str(file)+'.gz',(file.stat().st_atime,file.stat().st_mtime))
        (pending/'deployment.json').write_text(json.dumps(metadata,indent=2))
        for path in pending.rglob('*'):path.chmod(0o755 if path.is_dir() else 0o644)
        pending.chmod(0o755);os.replace(pending,dest)
        return dest
    finally:
        if pending.exists() and pending.resolve().parent==releases.resolve() and not pending.is_symlink():shutil.rmtree(pending)


def switch(target):
    if not target.resolve().is_relative_to((ROOT/'releases').resolve()):raise ValueError('Invalid release target')
    link=ROOT/('.current-'+str(os.getpid()))
    link.symlink_to(target);os.replace(link,ROOT/'current')


def main():
    CACHE.mkdir(parents=True,exist_ok=True)
    with (CACHE/'update.lock').open('w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        metadata=read_json(BASE+'web-version.json?ts='+str(time.time_ns()));validate(metadata)
        native=read_json(BASE+'version.json?ts='+str(time.time_ns()))
        if native.get('build_commit')!=metadata['build_commit'] or native.get('version')!=metadata['version']:
            print('Web publication has not caught up with the app release; keeping current version');return
        current=ROOT/'current'
        previous=current.resolve(strict=True) if current.exists() else None
        if previous and json.loads((previous/'deployment.json').read_text()).get('sha256')==metadata['sha256']:
            print('Web artifact is current');return
        bundle=CACHE/'incoming.zip'
        request=urllib.request.Request(BASE+'niosmess-web.zip?ts='+str(time.time_ns()),headers={'User-Agent':'Nios-Web-Updater'})
        with urllib.request.urlopen(request,timeout=60) as source,bundle.open('wb') as output:
            size=0
            while chunk:=source.read(1024*1024):
                size+=len(chunk)
                if size>metadata['size']:raise ValueError('Oversized download')
                output.write(chunk)
        dest=prepare_release(metadata,bundle)
        # Recheck the publishing race after the potentially long download.
        latest=read_json(BASE+'version.json?ts='+str(time.time_ns()))
        if latest.get('build_commit')!=metadata['build_commit']:
            print('A newer release appeared; keeping current web version');return
        switch(dest)
        try:
            info=read_json('https://ni-os.ru/web/release-info.json?ts='+str(time.time_ns()))
            if info.get('build_commit')!=metadata['build_commit']:raise ValueError('Web health mismatch')
        except BaseException:
            if previous:switch(previous)
            raise
        (CACHE/'last-success.json').write_text(json.dumps(metadata,indent=2))
        print(json.dumps({'installed':metadata['version'],'commit':metadata['build_commit']}))


if __name__=='__main__':main()
