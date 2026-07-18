import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';

class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.hapticsEnabled,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool hapticsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int totalUnread = ref.watch(
      totalUnreadCountProvider.select((int c) => c > 99 ? 99 : c),
    );
    final bool isFloating = ref.watch(uiSettingsProvider.select((s) => s.navBarFloating));

    final List<_NavItem> items = <_NavItem>[
      _NavItem(
        context.l10n.tabChats,
        Icons.chat_bubble_outline_rounded,
        Icons.chat_bubble_rounded,
        badge: totalUnread,
      ),
      _NavItem(
        context.l10n.tabContacts,
        Icons.group_outlined,
        Icons.group_rounded,
      ),
      _NavItem(
        context.l10n.tabNiosgram,
        Icons.grid_view_rounded,
        Icons.grid_view_rounded,
      ),
      _NavItem(
        context.l10n.tabProfile,
        Icons.person_outline_rounded,
        Icons.person_rounded,
      ),
    ];

    final scheme = Theme.of(context).colorScheme;

    Widget navBar = NavigationBar(
      selectedIndex: currentIndex,
      elevation: 0,
      backgroundColor: isFloating ? scheme.surfaceContainerHighest.withOpacity(0.9) : scheme.surfaceContainerLow,
      indicatorColor: scheme.secondaryContainer,
      onDestinationSelected: (int index) {
            ref.read(appSoundProvider).playUiTick();
            if (hapticsEnabled && index != currentIndex) {
              HapticService.tap();
            }
            onTap(index);
          },
          destinations: items
              .asMap()
          .entries
          .map(
            (MapEntry<int, _NavItem> entry) {
              final _NavItem item = entry.value;
              final int index = entry.key;
              return Semantics(
                label: item.label,
                selected: index == currentIndex,
                button: true,
                child: NavigationDestination(
                  icon: item.badge > 0
                      ? Badge(
                          label: item.badge < 100
                              ? AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  transitionBuilder:
                                      (Widget child, Animation<double> anim) =>
                                          ScaleTransition(
                                            scale: anim,
                                            child: child,
                                          ),
                                  child: Text(
                                    '${item.badge}',
                                    key: ValueKey<int>(item.badge),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                )
                              : const Text(
                                  '99+',
                                  style: TextStyle(fontSize: 10),
                                ),
                          child: Icon(item.icon),
                        )
                      : Icon(item.icon),
                  selectedIcon: item.badge > 0
                      ? Badge(
                          label: item.badge < 100
                              ? Text(
                                  '${item.badge}',
                                  style: const TextStyle(fontSize: 10),
                                )
                              : const Text(
                                  '99+',
                                  style: TextStyle(fontSize: 10),
                                ),
                          child: Icon(item.selectedIcon),
                        )
                      : Icon(item.selectedIcon),
                  label: item.label,
                  tooltip: item.label,
                ),
              );
            },
          )
          .toList(growable: false),
    );

    if (isFloating) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: navBar,
        ),
      );
    } else {
      return navBar;
    }
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon, {this.badge = 0});

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badge;
}
