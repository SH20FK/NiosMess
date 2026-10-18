import contextlib
import hashlib
import io
import json
import pathlib
import tempfile
import unittest
import release_metadata
from unittest.mock import patch


class ReleaseMetadataTest(unittest.TestCase):
    def test_published_abi_hashes_and_single_version_notes(self):
        with tempfile.TemporaryDirectory() as temporary:
            project = pathlib.Path(temporary) / 'pulse_flutter'
            (project / 'tool').mkdir(parents=True)
            (project / 'dist/android').mkdir(parents=True)
            (project / 'pubspec.yaml').write_text('version: 3.100.0+229\n')
            (project.parent / 'CHANGELOG.md').write_text('## [3.100.0]\n\nАктивация NiosPlus\n\n## [3.99.2]\n\nOld notes\n', encoding='utf-8')
            for abi in ('universal', 'arm64-v8a', 'armeabi-v7a', 'x86_64'):
                name = 'niosmess.apk' if abi == 'universal' else f'niosmess-{abi}.apk'
                (project / 'dist/android' / name).write_bytes(abi.encode())
            previous = release_metadata.__file__
            release_metadata.__file__ = str(project / 'tool/release_metadata.py')
            try:
                with contextlib.redirect_stdout(io.StringIO()), patch.dict('os.environ', {
                    'GITHUB_REF_TYPE': 'tag', 'GITHUB_REF_NAME': 'v3.100.0+229',
                }):
                    release_metadata.main()
            finally:
                release_metadata.__file__ = previous
            self.assertTrue((project / 'version.json').read_bytes().isascii())
            data = json.loads((project / 'version.json').read_text())
            self.assertEqual(data['changelog'], 'Активация NiosPlus')
            self.assertIn('build_commit', data)
            self.assertEqual(data['tag_name'], 'v3.100.0+229')
            self.assertIn('/v3.100.0%2B229/', data['download_url'])
            self.assertIn('/v3.100.0%2B229/', data['windows_download_url'])
            for abi, artifact in data['android_assets'].items():
                self.assertEqual(artifact['sha256'], hashlib.sha256(abi.encode()).hexdigest())
                self.assertEqual(artifact['size'], len(abi))
            installer = b'Windows installer fixture'
            (project / 'niosmess-windows-setup.exe').write_bytes(installer)
            release_metadata.add_windows_asset(project)
            final = json.loads((project / 'version.json').read_text())
            self.assertEqual(final['windows_asset']['sha256'], hashlib.sha256(installer).hexdigest())
            self.assertEqual(final['windows_asset']['size'], len(installer))
            self.assertEqual(final['android_assets'], data['android_assets'])


if __name__ == '__main__':
    unittest.main()
