import 'package:flutter/material.dart';
import 'package:nios_admin_flutter/core/localization/l10n.dart';
import 'package:nios_admin_flutter/widgets/admin_panel.dart';
import 'package:nios_admin_flutter/widgets/admin_scaffold_body.dart';

class AdminShellScaffold extends StatelessWidget {
  const AdminShellScaffold({
    required this.currentIndex,
    required this.onSelectIndex,
    required this.onLogout,
    required this.child,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback onLogout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final List<_AdminDestination> destinations = <_AdminDestination>[
      _AdminDestination(context.l10n.dashboard, Icons.space_dashboard_rounded),
      _AdminDestination(context.l10n.users, Icons.group_rounded),
      _AdminDestination(context.l10n.chats, Icons.forum_rounded),
      _AdminDestination(context.l10n.badges, Icons.workspace_premium_rounded),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 960;
        final Widget content = Scaffold(
          backgroundColor: Colors.transparent,
          body: AdminScaffoldBody(
            padding: EdgeInsets.only(bottom: wide ? 0 : 90),
            child: wide
                ? Row(
                    children: <Widget>[
                      SizedBox(
                        width: 280,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                          child: AdminPanel(
                            child: Column(
                              children: <Widget>[
                                const SizedBox(height: 8),
                                const _BrandBlock(),
                                const SizedBox(height: 18),
                                Expanded(
                                  child: NavigationRail(
                                    selectedIndex: currentIndex,
                                    labelType: NavigationRailLabelType.all,
                                    onDestinationSelected: onSelectIndex,
                                    leading: const SizedBox.shrink(),
                                    destinations: destinations
                                        .map(
                                          (_AdminDestination destination) =>
                                              NavigationRailDestination(
                                                icon: Icon(destination.icon),
                                                label: Text(destination.label),
                                              ),
                                        )
                                        .toList(growable: false),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.tonalIcon(
                                  onPressed: onLogout,
                                  icon: const Icon(Icons.logout_rounded),
                                  label: Text(context.l10n.logout),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                          child: child,
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: child,
                  ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: currentIndex,
                  onDestinationSelected: onSelectIndex,
                  destinations: destinations
                      .map(
                        (_AdminDestination destination) =>
                            NavigationDestination(
                              icon: Icon(destination.icon),
                              label: destination.label,
                            ),
                      )
                      .toList(growable: false),
                ),
        );

        return content;
      },
    );
  }
}

class _AdminDestination {
  const _AdminDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.admin_panel_settings_rounded,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('NiosMess Admin', style: textTheme.titleLarge),
              Text(
                'Web + Android moderation',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
