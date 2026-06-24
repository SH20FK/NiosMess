import 'package:flutter/material.dart';
import 'package:nios_admin_flutter/core/localization/l10n.dart';
import 'package:nios_admin_flutter/widgets/admin_panel.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({required this.onOpenSection, super.key});

  final ValueChanged<int> onOpenSection;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    Widget card({
      required IconData icon,
      required String title,
      required String body,
      required int section,
    }) {
      return AdminPanel(
        child: InkWell(
          onTap: () => onOpenSection(section),
          borderRadius: BorderRadius.circular(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 14),
              Text(title, style: textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                body,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Text(context.l10n.dashboardTitle, style: textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          context.l10n.dashboardSubtitle,
          style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool twoColumns = constraints.maxWidth >= 820;
            final List<Widget> tiles = <Widget>[
              card(
                icon: Icons.group_rounded,
                title: context.l10n.dashboardUsersTitle,
                body: context.l10n.dashboardUsersBody,
                section: 1,
              ),
              card(
                icon: Icons.forum_rounded,
                title: context.l10n.dashboardChatsTitle,
                body: context.l10n.dashboardChatsBody,
                section: 2,
              ),
              card(
                icon: Icons.workspace_premium_rounded,
                title: context.l10n.dashboardBadgesTitle,
                body: context.l10n.dashboardBadgesBody,
                section: 3,
              ),
            ];

            if (!twoColumns) {
              return Column(
                children:
                    tiles
                        .expand(
                          (Widget tile) => <Widget>[
                            tile,
                            const SizedBox(height: 12),
                          ],
                        )
                        .toList(growable: false)
                      ..removeLast(),
              );
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tiles
                  .map(
                    (Widget tile) => SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: tile,
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}
