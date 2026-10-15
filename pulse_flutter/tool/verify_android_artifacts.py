"""Verify actual release APK contents before metadata/publication (stdlib only).

Binary XML layout follows AOSP ResourceTypes.h, not a textual manifest dump:
https://android.googlesource.com/platform/frameworks/base/+/master/libs/androidfw/include/androidfw/ResourceTypes.h
"""
import argparse
from collections import Counter
from dataclasses import dataclass
import json
from pathlib import Path
import re
import struct
import sys
import zipfile


ANDROID_NS = 'http://schemas.android.com/apk/res/android'
PACKAGE = 'com.niosmess.pulse'
ABI_ELF = {'armeabi-v7a': (1, 40), 'arm64-v8a': (2, 183), 'x86_64': (2, 62)}
NO_STRING = 0xFFFFFFFF


class VerificationError(ValueError):
    pass


def _chunk(data, offset, limit):
    if offset + 8 > limit:
        raise VerificationError('Truncated binary XML chunk')
    kind, header, size = struct.unpack_from('<HHI', data, offset)
    if header < 8 or size < header or offset + size > limit:
        raise VerificationError('Invalid binary XML chunk bounds')
    return kind, header, size


def _strings(data, header):
    if header < 28:
        raise VerificationError('Invalid binary XML string pool header')
    count, styles, flags, start, style_start = struct.unpack_from('<IIIII', data, 8)
    end = style_start or len(data)
    if not header + (count + styles) * 4 <= start <= end <= len(data):
        raise VerificationError('Invalid binary XML string pool bounds')

    def length(offset, width):
        if offset + width > end:
            raise VerificationError('Truncated binary XML string length')
        value = int.from_bytes(data[offset:offset + width], 'little')
        offset += width
        high_bit = 1 << (width * 8 - 1)
        if value & high_bit:
            if offset + width > end:
                raise VerificationError('Truncated binary XML long string length')
            value = ((value & (high_bit - 1)) << (width * 8)) | int.from_bytes(data[offset:offset + width], 'little')
            offset += width
        return value, offset

    result = []
    for index in range(count):
        offset = start + struct.unpack_from('<I', data, header + index * 4)[0]
        if offset < start or offset >= end:
            raise VerificationError('Invalid binary XML string offset')
        if flags & 0x100:
            _, offset = length(offset, 1)  # UTF-16 character length.
            size, offset = length(offset, 1)  # UTF-8 byte length.
            width, encoding = 1, 'utf-8'
        else:
            size, offset = length(offset, 2)
            width, encoding = 2, 'utf-16le'
        finish = offset + size * width
        if finish + width > end or data[finish:finish + width] != bytes(width):
            raise VerificationError('Truncated binary XML string')
        try:
            result.append(data[offset:finish].decode(encoding))
        except UnicodeDecodeError as error:
            raise VerificationError('Invalid binary XML string encoding') from error
    return result


def _string(pool, index):
    if index >= len(pool):
        raise VerificationError('Invalid binary XML string reference')
    return pool[index]


@dataclass(frozen=True)
class ManifestInfo:
    package: str
    version_name: str
    version_code: int
    debuggable: bool


def read_manifest(data):
    """Read typed attributes: raw string spellings must not override typed data."""
    kind, header, size = _chunk(data, 0, len(data))
    if kind != 3 or size != len(data):
        raise VerificationError('AndroidManifest.xml must be complete binary XML')
    pool, stack, selected = None, [], {}
    offset = header
    while offset < size:
        kind, node_header, node_size = _chunk(data, offset, size)
        node_end = offset + node_size
        if kind == 1:
            if pool is not None or stack:
                raise VerificationError('Duplicate or misplaced binary XML string pool')
            pool = _strings(data[offset:node_end], node_header)
        elif kind in (0x102, 0x103):
            if pool is None or node_header < 16 or node_header + 8 > node_size:
                raise VerificationError('Invalid binary XML element')
            extension = offset + node_header
            namespace, name_index = struct.unpack_from('<II', data, extension)
            namespace = None if namespace == NO_STRING else _string(pool, namespace)
            name = _string(pool, name_index)
            if kind == 0x103:
                if not stack or stack.pop() != (namespace, name):
                    raise VerificationError('Unbalanced binary XML elements')
            else:
                if node_header + 20 > node_size:
                    raise VerificationError('Truncated binary XML attributes')
                start, width, count = struct.unpack_from('<HHH', data, extension + 8)
                if start < 20 or width < 20 or extension + start + count * width > node_end:
                    raise VerificationError('Invalid binary XML attribute bounds')
                attributes = {}
                for index in range(count):
                    attribute = extension + start + index * width
                    ns, attr_name = struct.unpack_from('<II', data, attribute)
                    key = (None if ns == NO_STRING else _string(pool, ns), _string(pool, attr_name))
                    value_size, _, value_type, value = struct.unpack_from('<HBBI', data, attribute + 12)
                    if value_size != 8 or key in attributes:
                        raise VerificationError('Invalid or duplicate binary XML attribute')
                    attributes[key] = (value_type, _string(pool, value) if value_type == 3 else value)
                if not stack and (namespace, name) != (None, 'manifest'):
                    raise VerificationError('Invalid Android manifest root')
                if (name == 'manifest' and not stack) or (name == 'application' and stack == [(None, 'manifest')]):
                    if name in selected or namespace is not None:
                        raise VerificationError('Duplicate or namespaced manifest/application element')
                    selected[name] = attributes
                stack.append((namespace, name))
        offset = node_end
    if stack or 'manifest' not in selected or 'application' not in selected:
        raise VerificationError('Incomplete Android manifest/application')

    def required(element, namespace, name, accepted_types):
        typed = selected[element].get((namespace, name))
        if typed is None or typed[0] not in accepted_types:
            raise VerificationError(f'Missing or unsupported typed {element}.{name}')
        return typed[1]

    package = required('manifest', None, 'package', (3,))
    version_name = required('manifest', ANDROID_NS, 'versionName', (3,))
    version_code = required('manifest', ANDROID_NS, 'versionCode', (0x10, 0x11))
    major = selected['manifest'].get((ANDROID_NS, 'versionCodeMajor'))
    if major is not None and (major[0] not in (0x10, 0x11) or major[1] != 0):
        raise VerificationError('Unexpected Android versionCodeMajor')
    debug = selected['application'].get((ANDROID_NS, 'debuggable'))
    if debug is not None and debug[0] != 0x12:
        raise VerificationError('Cannot verify non-boolean Android debuggable flag')
    return ManifestInfo(package, version_name, version_code, debug is not None and debug[1] != 0)


def pubspec_version(path):
    values = re.findall(r'^version:\s*([^\r\n#]+)', path.read_text(encoding='utf-8-sig'), re.MULTILINE)
    if len(values) != 1:
        raise VerificationError('pubspec.yaml must declare exactly one version')
    value = values[0].strip().strip('\'"')
    match = re.fullmatch(r'(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)\+(\d+)', value)
    if not match or not 1 <= int(match[2]) <= 2100000000:
        raise VerificationError('pubspec.yaml needs an Android-compatible version+build')
    return match[1], int(match[2])


def verify_apk(path, version_name, version_code, expected_abis):
    try:
        with zipfile.ZipFile(path) as archive:
            infos = [info for info in archive.infolist() if not info.is_dir()]
            names = [info.filename for info in infos]
            if any(count != 1 for count in Counter(names).values()):
                raise VerificationError('Duplicate ZIP entries')
            manifest = archive.getinfo('AndroidManifest.xml')
            if manifest.file_size > 16 * 1024 * 1024:
                raise VerificationError('Unexpected manifest size')
            actual = read_manifest(archive.read(manifest))
            if actual.package != PACKAGE:
                raise VerificationError('Unexpected application package')
            if actual.version_name != version_name or actual.version_code != version_code:
                raise VerificationError(f'Manifest version {actual.version_name}+{actual.version_code} != pubspec {version_name}+{version_code}')
            if actual.debuggable:
                raise VerificationError('Release APK is debuggable')
            if any(name.endswith('kernel_blob.bin') for name in names):
                raise VerificationError('Debug Dart kernel present in release APK')
            native = [info for info in infos if info.filename.startswith('lib/')]
            actual_abis = {info.filename.split('/')[1] for info in native if len(info.filename.split('/')) >= 3}
            if actual_abis != set(expected_abis):
                raise VerificationError(f'ABI contents {sorted(actual_abis)} != expected {sorted(expected_abis)}')
            for abi in expected_abis:
                for library in ('libapp.so', 'libflutter.so'):
                    name = f'lib/{abi}/{library}'
                    if name not in names:
                        raise VerificationError(f'Missing AOT library {name}')
            for info in native:
                parts = info.filename.split('/')
                if len(parts) != 3 or parts[1] not in ABI_ELF or not parts[2].endswith('.so'):
                    raise VerificationError('Unexpected native library layout')
                with archive.open(info) as stream:
                    elf = stream.read(20)
                expected_class, expected_machine = ABI_ELF[parts[1]]
                if len(elf) < 20 or elf[:4] != b'\x7fELF' or elf[4] != expected_class or elf[5] != 1 or struct.unpack_from('<H', elf, 18)[0] != expected_machine:
                    raise VerificationError(f'Native ELF architecture mismatch for {parts[1]}/{parts[2]}')
        return {'file': path.name, 'version': f'{actual.version_name}+{actual.version_code}', 'package': actual.package, 'debuggable': actual.debuggable, 'abis': sorted(actual_abis)}
    except VerificationError as error:
        raise VerificationError(f'{path.name}: {error}') from error
    except (OSError, KeyError, zipfile.BadZipFile, RuntimeError, struct.error) as error:
        raise VerificationError(f'{path.name}: unreadable or incomplete APK ({type(error).__name__})') from error


def verify_artifacts(project, artifacts):
    version_name, version_code = pubspec_version(project / 'pubspec.yaml')
    variants = {'universal': set(ABI_ELF), **{abi: {abi} for abi in ABI_ELF}}
    reports = []
    for variant, abis in variants.items():
        name = 'niosmess.apk' if variant == 'universal' else f'niosmess-{variant}.apk'
        reports.append(verify_apk(artifacts / name, version_name, version_code, abis))
    return reports


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--artifacts', type=Path, help='Directory with the four named release APKs (default: dist/android)')
    args = parser.parse_args(argv)
    try:
        reports = verify_artifacts(args.project, args.artifacts or args.project / 'dist/android')
    except (VerificationError, OSError) as error:
        detail = str(error) if isinstance(error, VerificationError) else type(error).__name__
        print(f'Android artifact verification failed: {detail}', file=sys.stderr)
        return 1
    print(json.dumps({'verified_android_artifacts': reports}, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
