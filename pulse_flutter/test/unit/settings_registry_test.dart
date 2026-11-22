import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations_ru.dart';
import 'package:pulse_flutter/l10n/app_localizations_en.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/router/web_settings_location.dart';
import 'package:pulse_flutter/services/settings/settings_registry.dart';

void main() {
  group('SettingsRegistry Tests', () {
    final l10nRu = AppLocalizationsRu();
    final l10nEn = AppLocalizationsEn();

    test('getTopLevelSections returns all main sections', () {
      final sections = SettingsRegistry.getTopLevelSections();
      expect(sections.isNotEmpty, isTrue);

      final ids = sections.map((s) => s.id).toList();
      // The hub is one flat list in this order. Device diagnostics is reached
      // from Help; the motion section was dissolved into its neighbours.
      expect(ids, <String>[
        'account',
        'devices',
        'notifications',
        'privacy',
        'chats',
        'appearance',
        'storage',
        'language',
        'plus',
        'about',
      ]);
    });

    test('renamed and dissolved sections still resolve from old links', () {
      expect(
        SettingsSectionId.fromString('preferences'),
        SettingsSectionId.notifications,
      );
      expect(
        SettingsSectionId.fromString('energySaving'),
        SettingsSectionId.chats,
      );
      expect(
        SettingsSectionId.fromString('nonsense'),
        SettingsSectionId.account,
      );
      expect(
        webSettingsRedirect(Uri.parse('/settings/preferences')),
        '/main/settings?section=notifications',
      );
      expect(
        webSettingsRedirect(Uri.parse('/settings/energy-saving')),
        '/main/settings?section=chats',
      );
    });

    test('search opens moved toggles on the screens that took them', () {
      final stickers = SettingsRegistry.search(
        'стикеры',
        l10nRu,
      ).firstWhere((r) => r.node.id == 'motion.stickers');
      expect(stickers.targetRoute, '/settings/chats');
      expect(stickers.targetSectionId, SettingsSectionId.chats);
      expect(stickers.anchor, 'motion.stickers');

      final optimize = SettingsRegistry.search(
        'optimize',
        l10nEn,
      ).firstWhere((r) => r.node.id == 'motion.optimization');
      expect(optimize.targetRoute, '/settings/storage');
      expect(optimize.targetSectionId, SettingsSectionId.storage);

      final devices = SettingsRegistry.search(
        'сеансы',
        l10nRu,
      ).firstWhere((r) => r.node.id == 'devices');
      expect(devices.targetRoute, '/settings/sessions');
    });

    test('search finds the reset row on the storage screen', () {
      final reset = SettingsRegistry.search(
        'сброс',
        l10nRu,
      ).firstWhere((r) => r.node.id == 'storage.reset');
      expect(reset.targetRoute, '/settings/storage');
      expect(reset.targetSectionId, SettingsSectionId.storage);
      expect(reset.anchor, 'storage.reset');
    });

    test('search finds UI corner radius in Russian and English', () {
      // Search Russian "скругление"
      final ruResults = SettingsRegistry.search('скругление', l10nRu);
      expect(ruResults.isNotEmpty, isTrue);
      expect(ruResults.any((r) => r.node.id == 'ui_corner_radius'), isTrue);
      final cornerResult = ruResults.firstWhere(
        (r) => r.node.id == 'ui_corner_radius',
      );
      expect(cornerResult.targetRoute, equals('/settings/appearance'));
      expect(
        cornerResult.targetSectionId,
        equals(SettingsSectionId.appearance),
      );
      expect(cornerResult.breadcrumb, contains('Оформление'));

      // Search English "corner"
      final enResults = SettingsRegistry.search('corner', l10nEn);
      expect(enResults.isNotEmpty, isTrue);
      expect(enResults.any((r) => r.node.id == 'ui_corner_radius'), isTrue);
    });

    test(
      'search does not advertise disabled backgrounds and navigation styles',
      () {
        final ids = SettingsRegistry.getAllNodes().map((node) => node.id);
        expect(ids, isNot(contains('true_black_oled')));
        expect(ids, isNot(contains('navbar_floating')));
        final ruResults = SettingsRegistry.search('обои', l10nRu);
        expect(
          ruResults.every((r) => r.node.id != 'wallpaper_generator'),
          isTrue,
        );

        final enResults = SettingsRegistry.search('wallpaper', l10nEn);
        expect(
          enResults.every((r) => r.node.id != 'wallpaper_generator'),
          isTrue,
        );
      },
    );

    test('search leads to the wallpaper entry in Appearance', () {
      final results = SettingsRegistry.search('обои', l10nRu);
      final wallpaper = results.firstWhere(
        (r) => r.node.id == 'appearance.wallpaper',
      );
      expect(wallpaper.targetRoute, equals('/settings/appearance'));
      expect(wallpaper.anchor, equals('appearance.wallpaper'));
      expect(
        SettingsRegistry.search('wallpaper', l10nEn).any(
          (r) => r.node.id == 'appearance.wallpaper',
        ),
        isTrue,
      );
    });

    test('search finds privacy rules and blocked users', () {
      final results = SettingsRegistry.search('черный список', l10nRu);
      expect(results.isNotEmpty, isTrue);
      expect(results.any((r) => r.node.id == 'blocked_users'), isTrue);
      final blocked = results.firstWhere((r) => r.node.id == 'blocked_users');
      expect(blocked.targetRoute, equals('/settings/privacy/blocked-users'));
    });

    test('empty or whitespace query returns empty list', () {
      expect(SettingsRegistry.search('', l10nRu), isEmpty);
      expect(SettingsRegistry.search('   ', l10nRu), isEmpty);
    });
  });
}
