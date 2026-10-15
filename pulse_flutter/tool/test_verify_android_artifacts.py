"""Small binary-XML/ELF ZIP fixtures; no Android SDK or application build."""
import contextlib
import io
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

import verify_android_artifacts as verifier


ANDROID = 'http://schemas.android.com/apk/res/android'
ABSENT = 0xFFFFFFFF


def _chunk(kind, header_size, header_tail=b'', payload=b''):
    return struct.pack('<HHI', kind, header_size, 8 + len(header_tail) + len(payload)) + header_tail + payload


def _length8(value):
    return bytes([(value >> 8) | 0x80, value & 255]) if value > 127 else bytes([value])


def manifest(*, code=3230, version='3.100.0', package='com.niosmess.pulse', debug=None, utf8=True, raw_code=None, debug_type=0x12):
    strings = ['manifest', 'application', 'package', 'versionName', 'versionCode', 'debuggable', 'android', ANDROID, package, version, 'x' * 140 + 'Облака']
    if raw_code is not None:
        strings.append(raw_code)
    index = {text: position for position, text in enumerate(strings)}
    offsets, body = [], b''
    for text in strings:
        offsets.append(len(body))
        encoded = text.encode('utf-8' if utf8 else 'utf-16le')
        units = len(text.encode('utf-16le')) // 2
        body += (_length8(units) + _length8(len(encoded)) + encoded + b'\0') if utf8 else struct.pack('<H', units) + encoded + b'\0\0'
    body += bytes((-len(body)) % 4)
    pool_header = struct.pack('<IIIII', len(strings), 0, 0x100 if utf8 else 0, 28 + len(strings) * 4, 0)
    pool = _chunk(1, 28, pool_header, struct.pack('<' + 'I' * len(offsets), *offsets) + body)

    def node(kind, payload):
        return _chunk(kind, 16, struct.pack('<II', 1, ABSENT), payload)

    def attribute(namespace, name, value_type, value, raw=ABSENT):
        return struct.pack('<IIIHBBI', ABSENT if namespace is None else index[namespace], index[name], raw, 8, 0, value_type, index[value] if value_type == 3 else value)

    def start(name, attributes):
        return node(0x102, struct.pack('<IIHHHHHH', ABSENT, index[name], 20, 20, len(attributes), 0, 0, 0) + b''.join(attributes))

    def end(name):
        return node(0x103, struct.pack('<II', ABSENT, index[name]))

    xml = pool + node(0x100, struct.pack('<II', index['android'], index[ANDROID]))
    xml += start('manifest', [
        attribute(None, 'package', 3, package),
        attribute(ANDROID, 'versionName', 3, version),
        attribute(ANDROID, 'versionCode', 0x10, code, ABSENT if raw_code is None else index[raw_code]),
    ])
    application = [] if debug is None else [attribute(ANDROID, 'debuggable', debug_type, debug)]
    xml += start('application', application) + end('application') + end('manifest')
    xml += node(0x101, struct.pack('<II', index['android'], index[ANDROID]))
    return _chunk(3, 8, payload=xml)


def elf(abi):
    # ELF ABI constants are fixed by the format, independent of verifier code.
    elf_class, machine = {'armeabi-v7a': (1, 40), 'arm64-v8a': (2, 183), 'x86_64': (2, 62)}[abi]
    return b'\x7fELF' + bytes([elf_class, 1, 1]) + bytes(9) + struct.pack('<HH', 3, machine) + bytes(44)


def apk(path, abis, *, xml=None, omit=None, extra=None, wrong_elf=None):
    with zipfile.ZipFile(path, 'w') as archive:
        archive.writestr('AndroidManifest.xml', xml or manifest())
        for abi in abis:
            for library in ('libapp.so', 'libflutter.so'):
                if (abi, library) != omit:
                    archive.writestr(f'lib/{abi}/{library}', elf(wrong_elf or abi))
        if extra:
            archive.writestr(extra, b'Debug fixture')


class VerifyAndroidArtifactsTest(unittest.TestCase):
    def test_binary_manifest_utf8_utf16_and_default_release_flag(self):
        for utf8 in (True, False):
            with self.subTest(utf8=utf8):
                actual = verifier.read_manifest(manifest(utf8=utf8))
                self.assertEqual(actual, verifier.ManifestInfo('com.niosmess.pulse', '3.100.0', 3230, False))
        self.assertFalse(verifier.read_manifest(manifest(debug=0)).debuggable)
        with self.assertRaises(verifier.VerificationError):
            verifier.read_manifest(manifest()[:-1])

    def test_all_four_apks_must_have_the_same_actual_pubspec_build(self):
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            artifacts = project / 'artifacts'
            artifacts.mkdir()
            (project / 'pubspec.yaml').write_text('name: fixture\nversion: 3.100.0+3230\n', encoding='utf-8')
            variants = {'universal': ['armeabi-v7a', 'arm64-v8a', 'x86_64'], 'armeabi-v7a': ['armeabi-v7a'], 'arm64-v8a': ['arm64-v8a'], 'x86_64': ['x86_64']}
            for variant, abis in variants.items():
                name = 'niosmess.apk' if variant == 'universal' else f'niosmess-{variant}.apk'
                apk(artifacts / name, abis)
            self.assertEqual(len(verifier.verify_artifacts(project, artifacts)), 4)
            for code in (4230, 5230, 6230, 7230):
                with self.subTest(offset_code=code):
                    apk(artifacts / 'niosmess-arm64-v8a.apk', ['arm64-v8a'], xml=manifest(code=code, raw_code='3230'))
                    with self.assertRaisesRegex(verifier.VerificationError, f'Manifest version 3.100.0\\+{code}'):
                        verifier.verify_artifacts(project, artifacts)

    def test_debug_wrong_package_or_version_cannot_be_published(self):
        cases = [
            (manifest(debug=0xFFFFFFFF), 'debuggable'),
            (manifest(debug=1), 'debuggable'),
            (manifest(debug=0, debug_type=1), 'non-boolean'),
            (manifest(package='com.niosmess.wrong'), 'package'),
            (manifest(version='3.99.3'), 'Manifest version'),
        ]
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'release.apk'
            for xml, error in cases:
                with self.subTest(error=error):
                    apk(path, ['arm64-v8a'], xml=xml)
                    with self.assertRaisesRegex(verifier.VerificationError, error):
                        verifier.verify_apk(path, '3.100.0', 3230, {'arm64-v8a'})

    def test_aot_libraries_strict_abi_and_actual_elf_machine(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'release.apk'
            cases = [
                ({'omit': ('arm64-v8a', 'libapp.so')}, 'Missing AOT'),
                ({'wrong_elf': 'x86_64'}, 'ELF architecture'),
                ({'extra': 'assets/flutter_assets/kernel_blob.bin'}, 'Debug Dart kernel'),
            ]
            for kwargs, error in cases:
                with self.subTest(error=error):
                    apk(path, ['arm64-v8a'], **kwargs)
                    with self.assertRaisesRegex(verifier.VerificationError, error):
                        verifier.verify_apk(path, '3.100.0', 3230, {'arm64-v8a'})
            apk(path, ['arm64-v8a', 'x86_64'])
            with self.assertRaisesRegex(verifier.VerificationError, 'ABI contents'):
                verifier.verify_apk(path, '3.100.0', 3230, {'arm64-v8a'})

    def test_cli_fails_closed_without_exposing_absolute_paths(self):
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            (project / 'pubspec.yaml').write_text('version: 3.100.0+3230\n')
            error = io.StringIO()
            with contextlib.redirect_stderr(error):
                status = verifier.main(['--project', str(project)])
            self.assertEqual(status, 1)
            self.assertIn('niosmess.apk', error.getvalue())
            self.assertNotIn(str(project), error.getvalue())


if __name__ == '__main__':
    unittest.main()
