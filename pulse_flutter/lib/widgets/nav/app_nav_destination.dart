import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

/// Top-level destinations of the shell.
///
/// The one list behind the bottom bar, the side rail, the `/main/:tab` route
/// segment and the tab shortcuts. The order is the tab order.
enum AppNavDestination {
  chats(
    'chats',
    Icons.chat_bubble_outline_rounded,
    Icons.chat_bubble_rounded,
    showsUnread: true,
  ),
  niosgram('niosgram', Icons.grid_view_outlined, Icons.grid_view_rounded),
  settings('settings', Icons.settings_outlined, Icons.settings_rounded);

  const AppNavDestination(
    this.route,
    this.icon,
    this.selectedIcon, {
    this.showsUnread = false,
  });

  /// Segment of `/main/<route>`.
  final String route;
  final IconData icon;
  final IconData selectedIcon;

  /// Whether the destination carries the total unread counter.
  final bool showsUnread;

  String label(BuildContext context) => switch (this) {
    AppNavDestination.chats => context.l10n.tabChats,
    AppNavDestination.niosgram => context.l10n.tabNiosgram,
    AppNavDestination.settings => context.l10n.tabSettings,
  };

  /// Destination of a route segment. `profile` is the old name of settings;
  /// anything unknown falls back to chats.
  static AppNavDestination fromRoute(String tab) => switch (tab) {
    'settings' || 'profile' => AppNavDestination.settings,
    'niosgram' => AppNavDestination.niosgram,
    _ => AppNavDestination.chats,
  };
}
