import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations_ru.dart';
import 'package:pulse_flutter/l10n/app_localizations_en.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/services/settings/settings_registry.dart';

void main() {
  group('SettingsRegistry Tests', () {
    final l10nRu = AppLocalizationsRu();
    final l10nEn = AppLocalizationsEn();

    test('getTopLevelSections returns all main sections', () {
      final sections = SettingsRegistry.getTopLevelSections();
      expect(sections.isNotEmpty, isTrue);

      final ids = sections.map((s) => s.id).toList();
      expect(ids, contains('account'));
      expect(ids, contains('appearance'));
      expect(ids, contains('chats'));
      expect(ids, contains('notifications'));
      expect(ids, contains('privacy'));
      expect(ids, contains('storage'));
      expect(ids, contains('language'));
      expect(ids, contains('about'));
    });

    test('search finds UI corner radius in Russian and English', () {
      // Search Russian "скругление"
      final ruResults = SettingsRegistry.search('скругление', l10nRu);
      expect(ruResults.isNotEmpty, isTrue);
      expect(ruResults.any((r) => r.node.id == 'ui_corner_radius'), isTrue);
      final cornerResult = ruResults.firstWhere((r) => r.node.id == 'ui_corner_radius');
      expect(cornerResult.targetRoute, equals('/settings/appearance'));
      expect(cornerResult.targetSectionId, equals(SettingsSectionId.appearance));
      expect(cornerResult.breadcrumb, contains('Внешний вид'));

      // Search English "corner"
      final enResults = SettingsRegistry.search('corner', l10nEn);
      expect(enResults.isNotEmpty, isTrue);
      expect(enResults.any((r) => r.node.id == 'ui_corner_radius'), isTrue);
    });

    test('search finds wallpaper generator in Russian and English', () {
      final ruResults = SettingsRegistry.search('обои', l10nRu);
      expect(ruResults.isNotEmpty, isTrue);
      expect(ruResults.any((r) => r.node.id == 'wallpaper_generator'), isTrue);

      final enResults = SettingsRegistry.search('wallpaper', l10nEn);
      expect(enResults.isNotEmpty, isTrue);
      expect(enResults.any((r) => r.node.id == 'wallpaper_generator'), isTrue);
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
