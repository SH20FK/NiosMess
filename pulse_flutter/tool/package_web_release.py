"""Package a verified Flutter artifact for the /web/ subdirectory; no Dart rebuild."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile


def package(source, output, commit, version):
    assert re.fullmatch('[0-9a-f]{40}', commit)
    metadata=json.loads((source/'version.json').read_text(encoding='utf-8'))
    assert version==metadata['version']+'+'+metadata['build_number']
    files={str(p.relative_to(source)).replace('\\','/'):p.read_bytes() for p in source.rglob('*') if p.is_file()}
    assert 'main.dart.js' in files and 'canvaskit/canvaskit.wasm' in files
    html=files['index.html'].decode('utf-8')
    assert html.count('<base href="/">')==1
    html=html.replace('<base href="/">','<base href="/web/">',1)
    html=html.replace('content="A new Flutter project."','content="NiosMess — сообщения, звонки и общие планы."',1)
    files['index.html']=html.encode()
    bootstrap=files['flutter_bootstrap.js'].decode('utf-8')
    # Use the artifact's local renderer, avoiding a critical CDN dependency.
    # The generated cleanup worker unregisters itself; do not register it anew.
    start=bootstrap.rindex('_flutter.loader.load({')
    bootstrap=bootstrap[:start]+'_flutter.loader.load({config: {canvasKitBaseUrl: "/web/canvaskit/"}});\n'
    files['flutter_bootstrap.js']=bootstrap.encode()
    worker=files['firebase-messaging-sw.js'].decode('utf-8')
    worker=worker.replace("'/icons/Icon-192.png'", "'/web/icons/Icon-192.png'")
    worker=worker.replace("const targetPath = chatId ? ('#/chat/' + chatId) : '#/';",
        "const targetPath = chatId ? ('/web/#/chat/' + encodeURIComponent(chatId)) : '/web/#/';")
    worker=worker.replace("if (client.url && 'focus' in client) {",
        "if (client.url && new URL(client.url).origin === self.location.origin && /^\\/web(?:\\/|$)/.test(new URL(client.url).pathname) && 'focus' in client) {")
    files['firebase-messaging-sw.js']=worker.encode()
    info={'version':version,'build_commit':commit,'base_path':'/web/'}
    files['release-info.json']=json.dumps(info,ensure_ascii=True).encode()
    output.mkdir(parents=True,exist_ok=True)
    archive=output/'niosmess-web.zip'
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for path,data in sorted(files.items()):
            zi=zipfile.ZipInfo('web/'+path,date_time=(2026,1,1,0,0,0))
            zi.external_attr=0o100644<<16;zi.compress_type=zipfile.ZIP_DEFLATED
            z.writestr(zi,data)
    info.update(size=archive.stat().st_size,sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
                file_count=len(files),url='https://github.com/SH20FK/NiosMess/releases/download/latest/niosmess-web.zip')
    (output/'web-version.json').write_text(json.dumps(info,ensure_ascii=True,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(info))


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--commit',required=True)
    parser.add_argument('--version',required=True)
    args=parser.parse_args()
    package(args.input,args.output,args.commit,args.version)
