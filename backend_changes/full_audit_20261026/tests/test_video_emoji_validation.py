"""Run against proposal copies only. Real ffmpeg/ffprobe, no DB/server access."""
import ast
import asyncio
import base64
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = ROOT / 'fixtures'


def load_functions(path):
    tree = ast.parse(path.read_text(encoding='utf-8'))
    imports = {'asyncio','base64','json','math','os','pathlib','re','tempfile','uuid'}
    nodes = [node for node in tree.body if
        isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) or
        isinstance(node, (ast.Import, ast.ImportFrom)) and
        (node.module if isinstance(node, ast.ImportFrom) else node.names[0].name) in imports or
        isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id in {'_probe_slots','_save_slots'} for target in node.targets)]
    namespace = {}
    exec(compile(ast.Module(body=nodes, type_ignores=[]), str(path), 'exec'), namespace)
    return namespace


class NoDatabase:
    async def scalar(self, *args):
        raise AssertionError('Inline media validation must not query a database')
    async def delete(self, *args):
        raise AssertionError('Inline media validation must not delete database data')


@unittest.skipUnless(shutil.which('ffprobe') and shutil.which('ffmpeg'), 'ffprobe/ffmpeg required for real media validation')
class VideoEmojiValidation(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='nios_video_emoji_audit_')
        self.root = Path(self.directory.name)
        self.module = load_functions(ROOT / 'candidate/app/services/public_media_uploads.py')
        self.module['settings'] = SimpleNamespace(UPLOAD_DIR=str(self.root))

    async def asyncTearDown(self):
        self.directory.cleanup()

    def video(self, *, size='64x64', seconds=.4):
        path = self.root / f'fixture_{size}_{seconds}.mp4'
        subprocess.run(['ffmpeg','-nostdin','-v','error','-y','-f','lavfi','-i',f'color=c=black:s={size}:d={seconds}',
                        '-c:v','libx264','-pix_fmt','yuv420p','-an','-movflags','+faststart',str(path)],
                       check=True, timeout=15, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        return path.read_bytes()

    async def save(self, data, **extra):
        return await self.module['save_public_media'](
            {'filename':'fixture.mp4','data_base64':base64.b64encode(data).decode('ascii'),
             'width':128,'height':128,'duration_seconds':1,**extra}, NoDatabase(), SimpleNamespace(id=7),
            directory='emoji/7',limit=512*1024,max_seconds=3,max_dimension=2048,
            max_aspect_ratio=2,require_video=True)

    def assert_no_permanent_files(self):
        self.assertFalse(list((self.root / 'emoji').glob('**/*')) if (self.root / 'emoji').exists() else [])
        self.assertFalse(list((self.root / 'temp').glob('*')))

    async def test_real_video_uses_actual_metadata_and_cleans_probe_file(self):
        data = self.video(size='128x64',seconds=.4)
        result = await self.save(data, width=1,height=1,duration_seconds=999)
        self.assertEqual((result['width'],result['height']), (128,64))
        self.assertAlmostEqual(result['duration'],.4,delta=.1)
        self.assertEqual(result['mime'],'video/mp4')
        self.assertEqual((self.root / result['path']).read_bytes(),data)
        self.assertFalse(list((self.root / 'temp').glob('*')))

    async def test_fake_mp4_bytes_are_rejected_before_storage(self):
        with self.assertRaises(ValueError): await self.save(b'not a video')
        self.assert_no_permanent_files()

    async def test_truncated_mp4_is_rejected_by_real_ffprobe(self):
        with self.assertRaises(ValueError): await self.save(self.video()[:24])
        self.assert_no_permanent_files()

    async def test_real_duration_over_limit_cannot_be_hidden_by_client_metadata(self):
        with self.assertRaisesRegex(ValueError,'duration'): await self.save(self.video(seconds=4),duration_seconds=1)
        self.assert_no_permanent_files()

    async def test_actual_aspect_ratio_rejects_fake_square_dimensions(self):
        with self.assertRaisesRegex(ValueError,'aspect'): await self.save(self.video(size='192x64'),width=128,height=128)
        self.assert_no_permanent_files()

    async def test_actual_dimensions_over_limit_are_rejected(self):
        with self.assertRaisesRegex(ValueError,'dimensions'): await self.save(self.video(size='4096x64'))
        self.assert_no_permanent_files()

    async def test_spoofed_image_named_as_video_is_not_adopted(self):
        with self.assertRaisesRegex(ValueError,'Expected a video'): await self.save(b'\x89PNG\r\n\x1a\n' + b'not decoded')
        self.assert_no_permanent_files()

    async def test_bounded_body_rejects_oversized_payload_before_probe(self):
        with self.assertRaisesRegex(ValueError,'large'): await self.save(b'x' * (512*1024+1))
        self.assert_no_permanent_files()

    async def test_cancelled_probe_always_removes_temporary_file(self):
        started = asyncio.Event()
        async def pending_probe(*_):
            started.set(); await asyncio.Future()
        self.module['_probe'] = pending_probe
        job = asyncio.create_task(self.save(self.video()))
        await started.wait(); job.cancel()
        with self.assertRaises(asyncio.CancelledError): await job
        self.assert_no_permanent_files()


class BaselineEvidence(unittest.TestCase):
    def test_live_snapshot_bypasses_video_inspection(self):
        path = SNAPSHOT / 'app/services/custom_emojis.py'
        tree=ast.parse(path.read_text(encoding='utf-8'))
        function = next(node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name=='validate_image')
        namespace={}
        exec(compile(ast.Module(body=[function],type_ignores=[]),str(path),'exec'),namespace)
        self.assertIsNone(namespace['validate_image'](b'not a video','mp4'))
        self.assertIsNone(namespace['validate_image'](b'not a video','webm'))

    def test_candidate_sources_compile_and_handler_uses_verified_video_metadata(self):
        for path in (ROOT / 'candidate').rglob('*.py'): ast.parse(path.read_text(encoding='utf-8'))
        source=(ROOT / 'candidate/app/ws/handlers/media_handler.py').read_text(encoding='utf-8')
        self.assertIn('require_video=True',source)
        self.assertIn("relative, mime = verified_video['path'], verified_video['mime']",source)
        self.assertNotIn('duration = actual_duration if inspected else payload.get',source)


if __name__ == '__main__': unittest.main(verbosity=2)
