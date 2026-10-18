import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/services/plus_activation_link.dart';

void main() {
  const code = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG';
  test('accepts canonical HTTPS and native links', () {
    expect(
      PlusActivationLink.codeFrom('https://ni-os.ru/plus/activate#$code'),
      code,
    );
    expect(PlusActivationLink.codeFrom('niosmess://plus/activate#$code'), code);
  });
  test('rejects foreign hosts, wrong paths and malformed codes', () {
    for (final link in [
      'https://evil.example/plus/activate#$code',
      'https://ni-os.ru.evil.example/plus/activate#$code',
      'http://ni-os.ru/plus/activate#$code',
      'https://ni-os.ru/u/user#$code',
      'https://ni-os.ru/plus/activate?code=$code',
      'https://user@ni-os.ru/plus/activate#$code',
      'https://ni-os.ru:4443/plus/activate#$code',
      'https://ni-os.ru/plus/activate#short',
      'niosmess://plus/activate#<script>',
    ]) {
      expect(PlusActivationLink.codeFrom(link), isNull, reason: link);
    }
  });
}
