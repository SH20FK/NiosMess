import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

void main() {
  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer();
    container
        .read(sessionAccessTokenProvider.notifier)
        .setToken('test-only-token');
  });
  tearDown(() {
    container.read(sessionAccessTokenProvider.notifier).clear();
    container.dispose();
  });

  test('only the exact HTTPS media origin receives session authorization', () {
    for (final url in [
      '/static/avatar.png',
      'static/avatar.png',
      'https://ni-os.ru/static/avatar.png',
      'https://NI-OS.RU:443/static/avatar.png?version=2#image',
    ]) {
      expect(cachedAuthHeaders(url), {
        'Authorization': 'Bearer test-only-token',
      }, reason: url);
    }
    for (final url in [
      null,
      '',
      'https://cdn.example.test/avatar.png',
      'https://ni-os.ru.evil.test/avatar.png',
      'https://ni-os.ru@evil.test/avatar.png',
      'https://evil.test@ni-os.ru/avatar.png',
      'https://ni-os.ru:444/avatar.png',
      'https://ni-os.ru./avatar.png',
      'http://ni-os.ru/avatar.png',
      '//ni-os.ru/avatar.png',
      'file://ni-os.ru/avatar.png',
      'javascript:alert(1)',
      'https:missing-host',
    ]) {
      expect(cachedAuthHeaders(url), isEmpty, reason: '$url');
    }
    container.read(sessionAccessTokenProvider.notifier).clear();
    expect(cachedAuthHeaders('/static/avatar.png'), isEmpty);
  });

  test('external media stays usable without rewriting spoofed hosts', () {
    for (final url in [
      'https://cdn.example.test/image.webp',
      'https://ni-os.ru.evil.test/image.webp',
      'http://ni-os.ru/image.webp',
      'https://ni-os.ru:444/image.webp',
    ]) {
      expect(ApiConstants.resolve(url), url);
    }
    for (final url in [
      'https://user:password@ni-os.ru/image.webp',
      'file:///tmp/image.webp',
      'data:image/png;base64,AA==',
      'https:missing-host',
    ]) {
      expect(ApiConstants.resolve(url), isEmpty);
    }
    expect(
      ApiConstants.resolve('/static/image.webp'),
      '${ApiConstants.devProxyOrigin}/static/image.webp',
    );
  });

  test('same host at another effective port is a different origin', () {
    final localOrigin = Uri.parse('http://127.0.0.1:12345');
    expect(
      ApiConstants.sameOrigin(
        Uri.parse('http://127.0.0.1:12345/a'),
        localOrigin,
      ),
      isTrue,
    );
    expect(
      ApiConstants.sameOrigin(
        Uri.parse('http://127.0.0.1:12346/a'),
        localOrigin,
      ),
      isFalse,
    );
    expect(
      ApiConstants.sameOrigin(
        Uri.parse('https://127.0.0.1:12345/a'),
        localOrigin,
      ),
      isFalse,
    );
    expect(
      ApiConstants.sameOrigin(
        Uri.parse('http://user@127.0.0.1:12345/a'),
        localOrigin,
      ),
      isFalse,
    );
  });

  testWidgets(
    'avatar ImageProvider never carries a token to a foreign origin',
    (tester) async {
      for (final url in [
        'https://ni-os.ru/static/test-origin.png',
        'https://cdn.example.test/test-origin.png',
        'https://ni-os.ru.evil.test/test-origin.png',
        'https://ni-os.ru:444/test-origin.png',
        'http://ni-os.ru/test-origin.png',
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: PulseAvatar(key: ValueKey(url), name: 'Test', avatarUrl: url),
          ),
        );
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byType(PulseAvatar),
            matching: find.byType(Image),
          ),
        );
        var provider = image.image;
        if (provider is ResizeImage) provider = provider.imageProvider;
        final Map<String, String>? headers;
        final String actualUrl;
        if (kIsWeb) {
          final network = provider as NetworkImage;
          headers = network.headers;
          actualUrl = network.url;
        } else {
          final network = provider as CachedNetworkImageProvider;
          headers = network.headers;
          actualUrl = network.url;
        }
        expect(actualUrl, ApiConstants.resolve(url));
        expect(
          headers ?? const {},
          ApiConstants.isAuthenticatedMediaUrl(url)
              ? {'Authorization': 'Bearer test-only-token'}
              : isEmpty,
          reason: url,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
