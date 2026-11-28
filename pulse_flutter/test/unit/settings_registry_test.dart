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
      // from search; the motion section was dissolved into its neighbours;
      // Nios+ rides the account page.
      expect(ids, <String>[
        'account',
        'devices',
        'appearance',
        'chats',
        'notifications',
        'privacy',
        'security',
        'storage',
        'language',
        'about',
      ]);
    });

    test('renamed and dissolved sections still resolve from old links', () {
      expect(
        SettingsSectionId.fromString('preferences'),
        SettingsSectionId.notifications,
      );
      // The delivery rules that did the energy saving live on Notifications.
      expect(
        SettingsSectionId.fromString('energySaving'),
        SettingsSectionId.notifications,
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
        '/main/settings?section=notifications',
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

    test('a row found by search is highlighted under its own id', () {
      final ids = SettingsRegistry.getAllNodes().map((n) => n.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'ids must be unique');

      var anchored = 0;
      for (final node in SettingsRegistry.getAllNodes()) {
        if (node.parentNavId == null || !node.isAvailable()) continue;
        final result = SettingsRegistry.search(
          node.title(l10nRu),
          l10nRu,
        ).firstWhere((r) => identical(r.node, node));
        // A row that opens a screen of its own has nothing to highlight.
        if (result.anchor == null) continue;
        anchored++;
        expect(result.anchor, node.id);
      }
      expect(anchored, greaterThanOrEqualTo(20));
    });

    test('search finds UI corner radius in Russian and English', () {
      // Search Russian "скругление"
      final ruResults = SettingsRegistry.search('скругление', l10nRu);
      expect(ruResults.isNotEmpty, isTrue);
      expect(ruResults.any((r) => r.node.id == 'ui_corner_radius'), isTrue);
      final cornerResult = ruResults.firstWhere(
        (r) => r.node.id == 'ui_corner_radius',
      );
      // The radii moved to their own sub-screen; the hub row on Appearance
      // only opens it.
      expect(cornerResult.targetRoute, equals('/settings/appearance/shape'));
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

    test('search does not advertise disabled navigation styles', () {
      final ids = SettingsRegistry.getAllNodes().map((node) => node.id);
      expect(ids, isNot(contains('true_black_oled')));
      expect(ids, isNot(contains('navbar_floating')));
      final ruResults = SettingsRegistry.search('обои', l10nRu);
      expect(
        ruResults.any((r) => r.node.id == 'appearance.wallpaper'),
        isFalse,
      );

      final enResults = SettingsRegistry.search('wallpaper', l10nEn);
      expect(
        enResults.any((r) => r.node.id == 'appearance.wallpaper'),
        isFalse,
      );
    });

    test('search finds privacy rules and blocked users', () {
      final results = SettingsRegistry.search('черный список', l10nRu);
      expect(results.isNotEmpty, isTrue);
      expect(results.any((r) => r.node.id == 'privacy.blockedUsers'), isTrue);
      final blocked = results.firstWhere((r) => r.node.id == 'privacy.blockedUsers');
      expect(blocked.targetRoute, equals('/settings/privacy/blocked-users'));
    });

    test('empty or whitespace query returns empty list', () {
      expect(SettingsRegistry.search('', l10nRu), isEmpty);
      expect(SettingsRegistry.search('   ', l10nRu), isEmpty);
    });
  });
}
