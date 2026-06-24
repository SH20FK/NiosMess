import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class DevelopersScreen extends StatelessWidget {
  const DevelopersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_Developer> developers = <_Developer>[
      _Developer(
        name: 'Sanlsan',
        role: context.l10n.developersSanlsanRole,
        description: context.l10n.developersSanlsanDescription,
        assetPath: 'assets/developers/Sanlsan_clean.png',
        icon: Icons.dns_rounded,
        accentColor: Colors.blue,
        tags: <String>[
          context.l10n.developersTagBackend,
          context.l10n.developersTagApi,
          context.l10n.developersTagAuth,
        ],
      ),
      _Developer(
        name: 'SH20FK',
        role: context.l10n.developersSh20fkRole,
        description: context.l10n.developersSh20fkDescription,
        assetPath: 'assets/developers/SH20FK_clean.png',
        icon: Icons.phone_iphone_rounded,
        accentColor: Colors.purple,
        tags: <String>[
          context.l10n.developersTagFlutter,
          context.l10n.developersTagUx,
          context.l10n.developersTagClient,
        ],
      ),
    ];

    return SettingsScaffold(
      title: context.l10n.settingsDevelopers,
      children: <Widget>[
        // Баннер команды
        _TeamBanner(count: developers.length),
        const SizedBox(height: 8),
        // Карточки разработчиков
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 720;
            if (!wide) {
              return Column(
                children: <Widget>[
                  for (int i = 0; i < developers.length; i++) ...<Widget>[
                    _DeveloperCard(developer: developers[i]),
                    if (i != developers.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < developers.length; i++) ...<Widget>[
                  Expanded(
                    child: _DeveloperCard(developer: developers[i]),
                  ),
                  if (i != developers.length - 1) const SizedBox(width: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TeamBanner extends StatelessWidget {
  const _TeamBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.groups_rounded, color: Colors.purple, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.developersTeamTitle,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.developersHeroSubtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: textTheme.titleSmall?.copyWith(
                  color: Colors.purple,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({required this.developer});
  final _Developer developer;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color accent = developer.accentColor;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Аватар разработчика
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 76,
                height: 76,
                color: accent.withValues(alpha: 0.08),
                child: Stack(
                  children: <Widget>[
                    // Фоновая иконка
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        developer.icon,
                        size: 48,
                        color: accent.withValues(alpha: 0.07),
                      ),
                    ),
                    // Фото
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        developer.assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? trace,
                        ) {
                          return Center(
                            child: Icon(
                              Icons.person_rounded,
                              size: 32,
                              color: accent.withValues(alpha: 0.5),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Информация о разработчике
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          developer.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(developer.icon, color: accent, size: 16),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    developer.role,
                    style: textTheme.labelMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    developer.description,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: developer.tags
                        .map(
                          (String tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tag,
                              style: textTheme.labelSmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Developer {
  const _Developer({
    required this.name,
    required this.role,
    required this.description,
    required this.assetPath,
    required this.icon,
    required this.accentColor,
    required this.tags,
  });

  final String name;
  final String role;
  final String description;
  final String assetPath;
  final IconData icon;
  final Color accentColor;
  final List<String> tags;
}
