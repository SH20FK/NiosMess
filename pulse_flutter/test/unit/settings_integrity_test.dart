import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/features/settings/domain/settings_issue.dart';
import 'package:pulse_flutter/l10n/app_localizations_ru.dart';
import 'package:pulse_flutter/models/settings/settings_node.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/router/web_settings_location.dart';
import 'package:pulse_flutter/services/settings/settings_registry.dart';
import 'package:universal_io/io.dart';

/// Source files that build the screen behind each settings route. An anchor
/// only works when one of these files declares it.
const Map<String, List<String>> _screenSources = <String, List<String>>{
  '/settings/account': <String>['lib/screens/settings_account_screen.dart'],
  '/settings/appearance': <String>[
    'lib/screens/settings_appearance_screen.dart',
  ],
  '/settings/chats': <String>['lib/screens/settings_chats_screen.dart'],
  '/settings/preferences': <String>[
    'lib/screens/settings_preferences_screen.dart',
    'lib/widgets/notifications/notification_settings_section.dart',
  ],
  '/settings/privacy': <String>[
    'lib/screens/settings_privacy_screen.dart',
    'lib/widgets/settings/account_security_section.dart',
  ],
  '/settings/privacy/blocked-users': <String>[
    'lib/screens/blocked_users_screen.dart',
  ],
  '/settings/storage': <String>['lib/screens/settings_storage_screen.dart'],
  '/settings/language-region': <String>[
    'lib/screens/settings_language_region_screen.dart',
  ],
  '/settings/energy-saving': <String>[
    'lib/screens/settings_energy_saving_screen.dart',
  ],
  '/settings/system-device': <String>[
    'lib/screens/settings_system_device_screen.dart',
  ],
  '/settings/plus': <String>['lib/screens/settings_plus_screen.dart'],
  '/settings/about': <String>[
    'lib/screens/settings_about_screen.dart',
    'lib/widgets/settings/about_update_tile.dart',
  ],
  '/settings/e2ee': <String>[
    'lib/screens/e2ee_settings_screen.dart',
    'lib/widgets/settings/ordinary_e2ee_settings.dart',
  ],
  '/settings/sessions': <String>[
    'lib/features/sessions/presentation/sessions_screen.dart',
  ],
};

/// Links that point at an anchor the target screen does not declare.
/// The list must shrink, never grow: fixing a link means deleting its entry.
const Set<String> _knownDanglingAnchors = <String>{
  'registry:blocked_users -> /settings/privacy/blocked-users#privacy.blockedUsers',
  'registry:e2ee_security -> /settings/e2ee#e2ee_security',
  'registry:sessions_management -> /settings/sessions#security.sessions.active',
  'issue:notifications_denied -> /settings/notifications#notifications-permission',
  'issue:reauthentication_required -> /settings/account#account-security',
  'issue:storage_low -> /settings/storage#storage-cache-clear',
  'issue:update_integrity_failure -> /settings/about#app-update',
};

/// Links that point at a route the router does not declare.
const Set<String> _knownMissingRoutes = <String>{
  'issue:notifications_denied -> /settings/notifications',
};

Map<String, String> _settingIdValues() {
  final String src = File(
    'lib/features/settings/domain/setting_id.dart',
  ).readAsStringSync();
  return <String, String>{
    for (final RegExpMatch m in RegExp(
      r"static const (\w+) = SettingId\('([^']+)'\)",
    ).allMatches(src))
      m.group(1)!: m.group(2)!,
  };
}

/// `'notifications.$key'` in source matches any `notifications.<name>` anchor.
RegExp _anchorPattern(String literal) {
  final String body = literal
      .split(RegExp(r'\$\{?\w+\}?'))
      .map(RegExp.escape)
      .join(r'[\w.]+');
  return RegExp('^$body\$');
}

List<RegExp> _declaredAnchors(String route, Map<String, String> settingIds) {
  final List<RegExp> patterns = <RegExp>[];
  for (final String path in _screenSources[route] ?? const <String>[]) {
    final String src = File(path).readAsStringSync();
    for (final RegExpMatch m in RegExp(
      r"(?:SettingsAnchor\(\s*id|anchor):\s*'([^']+)'",
    ).allMatches(src)) {
      patterns.add(_anchorPattern(m.group(1)!));
    }
    for (final RegExpMatch m in RegExp(
      r'anchor:\s*SettingId\.(\w+)\.value',
    ).allMatches(src)) {
      final String? value = settingIds[m.group(1)];
      if (value != null) patterns.add(_anchorPattern(value));
    }
  }
  return patterns;
}

Set<String> _routerPaths() => RegExp(r"path:\s*'([^']+)'")
    .allMatches(File('lib/router/app_router.dart').readAsStringSync())
    .map((RegExpMatch m) => m.group(1)!)
    .toSet();

List<SettingsHealthIssue> _allIssues() => <SettingsHealthIssue>[
  SettingsHealthIssue.notificationsDenied(),
  SettingsHealthIssue.reauthenticationRequired(),
  SettingsHealthIssue.storageLow(0),
  SettingsHealthIssue.updateIntegrityFailure(),
];

void main() {
  final AppLocalizationsRu l10n = AppLocalizationsRu();
  final Map<String, String> settingIds = _settingIdValues();

  bool declares(String route, String anchor) => _declaredAnchors(
    route,
    settingIds,
  ).any((RegExp pattern) => pattern.hasMatch(anchor));

  group('Settings integrity', () {
    test('every screen source in the route map exists', () {
      for (final MapEntry<String, List<String>> entry
          in _screenSources.entries) {
        for (final String path in entry.value) {
          expect(
            File(path).existsSync(),
            isTrue,
            reason: '${entry.key}: $path',
          );
        }
      }
    });

    test('search and issue anchors exist on the screen they open', () {
      final Set<String> dangling = <String>{};
      int checked = 0;

      for (final SettingsNode node in SettingsRegistry.getAllNodes()) {
        if (node.parentNavId == null || !node.isAvailable()) continue;
        final SettingsSearchResult result = SettingsRegistry.search(
          node.title(l10n),
          l10n,
        ).firstWhere((SettingsSearchResult r) => identical(r.node, node));
        final String? anchor = result.anchor;
        if (anchor == null || anchor.isEmpty) continue;
        checked++;
        if (!declares(result.targetRoute, anchor)) {
          dangling.add(
            'registry:${node.id} -> ${result.targetRoute}#$anchor',
          );
        }
      }

      for (final SettingsHealthIssue issue in _allIssues()) {
        checked++;
        if (!declares(issue.route, issue.anchor)) {
          dangling.add('issue:${issue.id} -> ${issue.route}#${issue.anchor}');
        }
      }

      expect(checked, greaterThanOrEqualTo(20));
      expect(
        dangling,
        _knownDanglingAnchors,
        reason:
            'A new dangling anchor must be fixed; a fixed one must be '
            'removed from _knownDanglingAnchors.',
      );
    });

    test('registry and issue routes exist in the router', () {
      final Set<String> paths = _routerPaths();
      final Set<String> missing = <String>{};

      for (final SettingsNode node in SettingsRegistry.getAllNodes()) {
        if (node is! SettingsNavNode) continue;
        if (!paths.contains(node.route)) {
          missing.add('registry:${node.id} -> ${node.route}');
        }
      }
      for (final SettingsHealthIssue issue in _allIssues()) {
        if (!paths.contains(issue.route)) {
          missing.add('issue:${issue.id} -> ${issue.route}');
        }
      }

      expect(
        missing,
        _knownMissingRoutes,
        reason:
            'A new missing route must be fixed; a fixed one must be '
            'removed from _knownMissingRoutes.',
      );
    });

    test('web redirect maps every top-level route to a real section', () {
      final Set<String> names = SettingsSectionId.values
          .map((SettingsSectionId id) => id.name)
          .toSet();
      for (final SettingsNavNode node
          in SettingsRegistry.getAllNodes().whereType<SettingsNavNode>()) {
        if (node.parentNavId != null) continue;
        final String? target = webSettingsRedirect(Uri.parse(node.route));
        expect(target, isNotNull, reason: node.route);
        expect(
          names,
          contains(Uri.parse(target!).queryParameters['section']),
          reason: node.route,
        );
      }
    });
  });
}
