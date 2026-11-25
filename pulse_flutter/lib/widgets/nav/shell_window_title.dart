import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/core/services/desktop_window_service.dart';
import 'package:pulse_flutter/models/settings/settings_node.dart';
import 'package:pulse_flutter/providers/settings_navigation_provider.dart';
import 'package:pulse_flutter/services/settings/settings_registry.dart';

/// Names the open settings section in the title bar of a desktop window and
/// in the browser tab. On a phone it adds nothing.
class ShellWindowTitle extends ConsumerStatefulWidget {
  const ShellWindowTitle({
    required this.settingsOpen,
    required this.sectionVisible,
    required this.child,
    this.webSection,
    super.key,
  });

  /// Whether the settings tab is the one on screen.
  final bool settingsOpen;

  /// Whether a section is on screen, beside the list or instead of it.
  final bool sectionVisible;

  /// The section from the address bar. A desktop window reads its own.
  final SettingsSectionId? webSection;

  final Widget child;

  static String compose(
    AppLocalizations l10n, {
    required bool settingsOpen,
    SettingsSectionId? section,
  }) {
    if (!settingsOpen) return DesktopWindowService.appTitle;
    final String? name = section == null
        ? null
        : SettingsRegistry.getAllNodes()
              .whereType<SettingsNavNode>()
              .where((SettingsNavNode node) => node.sectionId == section)
              .firstOrNull
              ?.title(l10n);
    final String place = <String>[l10n.tabSettings, ?name].join(' · ');
    return '$place — ${DesktopWindowService.appTitle}';
  }

  @override
  ConsumerState<ShellWindowTitle> createState() => _ShellWindowTitleState();
}

class _ShellWindowTitleState extends ConsumerState<ShellWindowTitle> {
  bool _browser = false;
  int _themeColor = 0xFF000000;

  @override
  void dispose() {
    // The screen that comes next has no title of its own to put back.
    if (_browser) {
      SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(
          label: DesktopWindowService.appTitle,
          primaryColor: _themeColor,
        ),
      );
    } else {
      DesktopWindowService.instance.setTitle(DesktopWindowService.appTitle);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ClientCapabilities capabilities = ref.watch(
      clientCapabilitiesProvider,
    );
    if (!capabilities.browserWorkspace && !capabilities.desktopFiles) {
      return widget.child;
    }
    _browser = capabilities.browserWorkspace;
    final SettingsSectionId? shown =
        !widget.settingsOpen || !widget.sectionVisible
        ? null
        : _browser
        ? widget.webSection
        : ref.watch(desktopSelectedSettingsSectionProvider);
    // The browser has no device diagnostics: that link opens About.
    final SettingsSectionId? section =
        _browser && shown == SettingsSectionId.systemDevice
        ? SettingsSectionId.about
        : shown;
    final String title = ShellWindowTitle.compose(
      context.l10n,
      settingsOpen: widget.settingsOpen,
      section: section,
    );
    if (!_browser) {
      // Like Title below, the name is handed to the platform while building.
      // The service drops a title that is already shown.
      DesktopWindowService.instance.setTitle(title);
      return widget.child;
    }
    final Color color = Theme.of(context).primaryColor.withAlpha(0xFF);
    _themeColor = color.toARGB32();
    return Title(title: title, color: color, child: widget.child);
  }
}
