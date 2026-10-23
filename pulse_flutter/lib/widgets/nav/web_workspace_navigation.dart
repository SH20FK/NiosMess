import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

/// Wide browser windows use a permanent navigation region beside the workspace.
/// The compact layout continues to use the shared bottom navigation.
class WebWorkspaceNavigation extends StatelessWidget {
  const WebWorkspaceNavigation({
    required this.index,
    required this.onSelect,
    super.key,
  });
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationRail(
      key: const ValueKey('web-workspace-navigation'),
      selectedIndex: index,
      onDestinationSelected: onSelect,
      backgroundColor: scheme.surfaceContainerLow,
      labelType: NavigationRailLabelType.none,
      minWidth: 88,
      groupAlignment: -0.65,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Tooltip(
          message: 'NiosMess',
          child: Material(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
            child: SizedBox.square(
              dimension: 48,
              child: Icon(
                Icons.forum_rounded,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          selectedIcon: const Icon(Icons.chat_bubble_rounded),
          label: Text(context.l10n.tabChats),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.grid_view_outlined),
          selectedIcon: const Icon(Icons.grid_view_rounded),
          label: Text(context.l10n.tabNiosgram),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings_rounded),
          label: Text(context.l10n.tabSettings),
        ),
      ],
    );
  }
}
