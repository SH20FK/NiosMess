import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';

void main() {
  test('activation bearer code stays in fragment for native app navigation', () {
    final uri = Uri.parse(
      'https://ni-os.ru/plus/activate#abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG',
    );
    final resolved = AppUrlLauncher.resolveInternalAppRoute(uri);
    expect(
      resolved,
      '/plus/activate#abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG',
    );
    expect(Uri.parse(resolved!).query, isEmpty);
    expect(
      AppUrlLauncher.resolveInternalAppRoute(
        Uri.parse('niosmess://plus/activate#abc'),
      ),
      '/plus/activate#abc',
    );
  });
  group('untrusted links', () {
    test(
      'dangerous schemes and credential-bearing URLs never launch',
      () async {
        for (final raw in [
          'javascript:alert(1)',
          'data:text/html,<script>1</script>',
          'file:///etc/passwd',
          'intent://scan/#Intent;scheme=zxing;end',
          'ms-settings:privacy',
          'https://user:password@ni-os.ru/settings',
        ]) {
          expect(
            await AppUrlLauncher.openUrl(null, raw, enableHaptics: false),
            isFalse,
            reason: raw,
          );
        }
        expect(
          AppUrlLauncher.isInternalNiosLink(
            Uri.parse('file://ni-os.ru/settings'),
          ),
          isFalse,
        );
        expect(
          AppUrlLauncher.isTelegramLink(Uri.parse('file://t.me/hello')),
          isFalse,
        );
      },
    );
    test('supported web, contact and app schemes remain available', () {
      for (final raw in [
        'https://example.com/path',
        'http://example.com/',
        'mailto:user@example.com?subject=Hello',
        'tel:+1234567',
        'sms:+1234567?body=Hello',
        'niosmess://chat/1',
        'nios://post/1',
        'tg://resolve?domain=fixture',
      ]) {
        expect(
          AppUrlLauncher.isSupportedLink(Uri.parse(raw)),
          isTrue,
          reason: raw,
        );
      }
      expect(
        AppUrlLauncher.isSupportedLink(Uri.parse('mailto://evil.test/user')),
        isFalse,
      );
      expect(
        AppUrlLauncher.isSupportedLink(Uri.parse('https:missing-host')),
        isFalse,
      );
      expect(
        AppUrlLauncher.isSupportedLink(Uri.parse('tel:%0D%0A123')),
        isFalse,
      );
    });
    test(
      'Telegram decoded path values cannot inject extra query parameters',
      () {
        final uri = AppUrlLauncher.convertTelegramToNativeScheme(
          Uri.parse('https://t.me/name%26post%3D999/123%26domain%3Devil'),
        )!;
        expect(uri.queryParameters, {
          'domain': 'name&post=999',
          'post': '123&domain=evil',
        });
        final invite = AppUrlLauncher.convertTelegramToNativeScheme(
          Uri.parse('https://t.me/+abc%26invite%3Devil'),
        )!;
        expect(invite.queryParameters, {'invite': 'abc&invite=evil'});
        final route = AppUrlLauncher.resolveInternalAppRoute(
          Uri.parse('https://ni-os.ru/join?slug=abc%26admin%3D1'),
        )!;
        expect(Uri.parse(route).queryParameters, {'slug': 'abc&admin=1'});
      },
    );
  });
  group('AppUrlLauncher Internal Link Resolution', () {
    test('Identifies NiosMess ecosystem domains correctly', () {
      expect(
        AppUrlLauncher.isInternalNiosLink(
          Uri.parse('https://ni-os.ru/u/alice'),
        ),
        isTrue,
      );
      expect(
        AppUrlLauncher.isInternalNiosLink(
          Uri.parse('https://www.ni-os.ru/g/bob'),
        ),
        isTrue,
      );
      expect(
        AppUrlLauncher.isInternalNiosLink(Uri.parse('niosmess://u/token')),
        isTrue,
      );
      expect(
        AppUrlLauncher.isInternalNiosLink(Uri.parse('https://t.me/niosmess')),
        isFalse,
      );
      expect(
        AppUrlLauncher.isInternalNiosLink(Uri.parse('https://google.com')),
        isFalse,
      );
    });

    test('Resolves user and channel vanity URLs /u/:slug', () {
      final Uri uri1 = Uri.parse('https://ni-os.ru/u/alice');
      expect(AppUrlLauncher.resolveInternalAppRoute(uri1), equals('/u/alice'));

      final Uri uri2 = Uri.parse('https://ni-os.ru/u/+PRIVATE_INVITE_TOKEN');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(uri2),
        equals('/u/+PRIVATE_INVITE_TOKEN'),
      );

      final Uri customScheme = Uri.parse('niosmess://u/durov');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(customScheme),
        equals('/u/durov'),
      );
    });

    test('Resolves NiosGram profile and direct chat /g/:username', () {
      final Uri uri = Uri.parse('https://ni-os.ru/g/creator');
      expect(AppUrlLauncher.resolveInternalAppRoute(uri), equals('/g/creator'));

      final Uri customScheme = Uri.parse('niosmess://g/creator');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(customScheme),
        equals('/g/creator'),
      );
    });

    test('Resolves sticker set deep links /stickers/:setId', () {
      final Uri uri = Uri.parse('https://ni-os.ru/stickers/902');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(uri),
        equals('/stickers/902'),
      );

      final Uri customScheme = Uri.parse('niosmess://stickers/902');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(customScheme),
        equals('/stickers/902'),
      );
    });

    test(
      'Resolves Nios Weave procedural wallpaper links /w/:code and niosmess:// variants',
      () {
        final Uri uri = Uri.parse('https://ni-os.ru/w/0104e4b500094b23023000');
        expect(
          AppUrlLauncher.resolveInternalAppRoute(uri),
          equals('/settings/wallpaper?code=0104e4b500094b23023000'),
        );

        final Uri customScheme = Uri.parse(
          'niosmess://w/0104e4b500094b23023000',
        );
        expect(
          AppUrlLauncher.resolveInternalAppRoute(customScheme),
          equals('/settings/wallpaper?code=0104e4b500094b23023000'),
        );

        final Uri customSchemeWithDomain = Uri.parse(
          'niosmess://ni-os.ru/w/0104e4b500094b23023000',
        );
        expect(
          AppUrlLauncher.resolveInternalAppRoute(customSchemeWithDomain),
          equals('/settings/wallpaper?code=0104e4b500094b23023000'),
        );

        final Uri customSchemeUserWithDomain = Uri.parse(
          'niosmess://ni-os.ru/u/alice',
        );
        expect(
          AppUrlLauncher.resolveInternalAppRoute(customSchemeUserWithDomain),
          equals('/u/alice'),
        );
      },
    );

    test('Resolves chat and group routes', () {
      final Uri uri = Uri.parse('https://ni-os.ru/chat/1024?highlight=55');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(uri),
        equals('/chat/1024?highlight=55'),
      );

      final Uri customScheme = Uri.parse('niosmess://chat/42');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(customScheme),
        equals('/chat/42'),
      );
    });

    test('Resolves join links with query parameters or path slugs', () {
      final Uri queryJoin = Uri.parse(
        'https://ni-os.ru/join?slug=alpha_testers',
      );
      expect(
        AppUrlLauncher.resolveInternalAppRoute(queryJoin),
        equals('/join?slug=alpha_testers'),
      );

      final Uri pathJoin = Uri.parse('https://ni-os.ru/join/beta_testers');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(pathJoin),
        equals('/join?slug=beta_testers'),
      );
    });

    test('Resolves settings and legal screens internally', () {
      final Uri settingsUri = Uri.parse('https://ni-os.ru/settings/appearance');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(settingsUri),
        equals('/settings/appearance'),
      );

      final Uri legalUri = Uri.parse('https://ni-os.ru/legal/privacy');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(legalUri),
        equals('/legal/privacy'),
      );
    });

    test('Strips /web prefix from links copied from web client', () {
      final Uri webLink = Uri.parse('https://ni-os.ru/web/u/sanlsan');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(webLink),
        equals('/u/sanlsan'),
      );

      final Uri webChat = Uri.parse('https://ni-os.ru/web/chat/99');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(webChat),
        equals('/chat/99'),
      );
    });

    test('Parses web hash fragment URLs (e.g. ni-os.ru/web#/u/alice)', () {
      final Uri hashLink = Uri.parse('https://ni-os.ru/web#/u/alice');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(hashLink),
        equals('/u/alice'),
      );

      final Uri rootHashLink = Uri.parse('https://ni-os.ru/#/chat/dm/bob');
      expect(
        AppUrlLauncher.resolveInternalAppRoute(rootHashLink),
        equals('/chat/dm/bob'),
      );
    });

    test(
      'Treats bare landing domain (https://ni-os.ru/) as external portal',
      () {
        final Uri bareRoot = Uri.parse('https://ni-os.ru');
        expect(AppUrlLauncher.resolveInternalAppRoute(bareRoot), isNull);

        final Uri bareSlash = Uri.parse('https://ni-os.ru/');
        expect(AppUrlLauncher.resolveInternalAppRoute(bareSlash), isNull);
      },
    );
  });

  group('AppUrlLauncher Telegram Native Scheme Conversion', () {
    test('Identifies Telegram domains correctly', () {
      expect(
        AppUrlLauncher.isTelegramLink(Uri.parse('https://t.me/niosmess')),
        isTrue,
      );
      expect(
        AppUrlLauncher.isTelegramLink(Uri.parse('https://telegram.me/hello')),
        isTrue,
      );
      expect(
        AppUrlLauncher.isTelegramLink(Uri.parse('tg://resolve?domain=test')),
        isTrue,
      );
      expect(
        AppUrlLauncher.isTelegramLink(Uri.parse('https://ni-os.ru')),
        isFalse,
      );
    });

    test('Converts standard username to tg://resolve?domain=username', () {
      final Uri tgUri = Uri.parse('https://t.me/hello_sanlsan');
      final Uri? converted = AppUrlLauncher.convertTelegramToNativeScheme(
        tgUri,
      );
      expect(converted, isNotNull);
      expect(converted.toString(), equals('tg://resolve?domain=hello_sanlsan'));
    });

    test('Converts channel post to tg://resolve?domain=channel&post=id', () {
      final Uri postUri = Uri.parse('https://t.me/niosmess/128');
      final Uri? converted = AppUrlLauncher.convertTelegramToNativeScheme(
        postUri,
      );
      expect(converted, isNotNull);
      expect(
        converted.toString(),
        equals('tg://resolve?domain=niosmess&post=128'),
      );
    });

    test('Converts +invite and joinchat links to tg://join?invite=...', () {
      final Uri invite1 = Uri.parse('https://t.me/+AbCdEfGh123');
      final Uri? converted1 = AppUrlLauncher.convertTelegramToNativeScheme(
        invite1,
      );
      expect(converted1, isNotNull);
      expect(converted1.toString(), equals('tg://join?invite=AbCdEfGh123'));

      final Uri invite2 = Uri.parse('https://t.me/joinchat/XyZ789');
      final Uri? converted2 = AppUrlLauncher.convertTelegramToNativeScheme(
        invite2,
      );
      expect(converted2, isNotNull);
      expect(converted2.toString(), equals('tg://join?invite=XyZ789'));
    });

    test('Preserves pre-existing tg:// URIs unchanged', () {
      final Uri rawTg = Uri.parse('tg://resolve?domain=Door0S');
      final Uri? converted = AppUrlLauncher.convertTelegramToNativeScheme(
        rawTg,
      );
      expect(converted, equals(rawTg));
    });

    test(
      'formatCanonicalInviteUrl formats all links into https://ni-os.ru/u/...',
      () {
        expect(
          AppUrlLauncher.formatCanonicalInviteUrl('+token123'),
          equals('https://ni-os.ru/u/+token123'),
        );
        expect(
          AppUrlLauncher.formatCanonicalInviteUrl('/join/work_chat'),
          equals('https://ni-os.ru/u/work_chat'),
        );
        expect(
          AppUrlLauncher.formatCanonicalInviteUrl(
            'https://ni-os.ru/join/public_channel',
          ),
          equals('https://ni-os.ru/u/public_channel'),
        );
        expect(
          AppUrlLauncher.formatCanonicalInviteUrl('/u/+secret456'),
          equals('https://ni-os.ru/u/+secret456'),
        );
        expect(
          AppUrlLauncher.formatCanonicalInviteUrl(
            'https://ni-os.ru/u/existing',
          ),
          equals('https://ni-os.ru/u/existing'),
        );
      },
    );
  });
  test('post evidence links copied from slash web base retain hash route', () {
    expect(
      AppUrlLauncher.resolveInternalAppRoute(
        Uri.parse('https://ni-os.ru/web/#/niosgram/post/60'),
      ),
      '/niosgram/post/60',
    );
  });
}
