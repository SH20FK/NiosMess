import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/alpha_test_dialog.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsAboutScreen extends StatefulWidget {
  const SettingsAboutScreen({super.key});

  @override
  State<SettingsAboutScreen> createState() => _SettingsAboutScreenState();
}

class _SettingsAboutScreenState extends State<SettingsAboutScreen>
    with TickerProviderStateMixin {
  late final AnimationController _heroController;
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
    _packageInfo = PackageInfo.fromPlatform();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              expandedHeight: 0,
              backgroundColor: scheme.surface,
              surfaceTintColor: Colors.transparent,
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              leadingWidth: 48,
              title: Text(context.l10n.settingsAboutTitle),
              centerTitle: true,
              titleSpacing: 0,
            ),
            SliverToBoxAdapter(child: _HeroBlock(animation: _heroController, packageInfo: _packageInfo)),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  isScrollable: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  unselectedLabelStyle:
                      Theme.of(context).textTheme.labelMedium,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerHeight: 0,
                  tabs: <Tab>[
                    Tab(icon: const Icon(Icons.code_rounded, size: 20), text: context.l10n.aboutTabDevelopers, iconMargin: EdgeInsets.zero),
                    Tab(icon: const Icon(Icons.help_outline_rounded, size: 20), text: context.l10n.aboutTabFaq, iconMargin: EdgeInsets.zero),
                    Tab(icon: const Icon(Icons.history_rounded, size: 20), text: context.l10n.aboutTabChangelog, iconMargin: EdgeInsets.zero),
                    Tab(icon: const Icon(Icons.gavel_rounded, size: 20), text: context.l10n.aboutTabLegal, iconMargin: EdgeInsets.zero),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: true,
              child: TabBarView(
                children: <Widget>[
                  _DevelopersTab(),
                  _FaqTab(),
                  _ChangelogTab(packageInfo: _packageInfo),
                  _LegalTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _HeroBlock extends StatelessWidget {
  const _HeroBlock({required this.animation, required this.packageInfo});
  final AnimationController animation;
  final Future<PackageInfo> packageInfo;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.4,
            colors: <Color>[
              scheme.primaryContainer.withValues(alpha: 0.4),
              scheme.surfaceContainerHigh,
              scheme.surfaceContainerLow,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative floating M3 shapes
            Positioned(
              top: -20,
              left: 20,
              child: M3Container.c9SidedCookie(
                width: 80,
                height: 80,
                color: scheme.primary.withValues(alpha: 0.1),
                child: const SizedBox(),
              ),
            ),
            Positioned(
              bottom: 10,
              right: -10,
              child: M3Container.c9SidedCookie(
                width: 120,
                height: 120,
                color: scheme.secondary.withValues(alpha: 0.08),
                child: const SizedBox(),
              ).animate(onPlay: (c) => c.repeat())
               .rotate(begin: 0, end: 1, duration: 20.seconds),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: M3Container.c9SidedCookie(
                width: 50,
                height: 50,
                color: scheme.tertiary.withValues(alpha: 0.15),
                child: const SizedBox(),
              ).animate(onPlay: (c) => c.repeat())
               .rotate(begin: 0, end: 1, duration: 12.seconds),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        M3Container.c9SidedCookie(
                          width: 88,
                          height: 88,
                          color: scheme.primary,
                          child: const SizedBox(),
                        ).animate(onPlay: (c) => c.repeat())
                         .rotate(duration: 10.seconds, curve: Curves.linear),
                        SvgPicture.asset(
                          'assets/svg/niosmess_logo_tintable.svg',
                          width: 88 * 0.6,
                          height: 88 * 0.6,
                          colorFilter: ColorFilter.mode(
                            scheme.onPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ],
                    ),
                  ).animate(controller: animation)
                    .scale(
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1.0, 1.0),
                      curve: Curves.easeOutBack,
                      duration: 600.ms,
                    )
                    .fade(duration: 400.ms),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.appName,
                    textAlign: TextAlign.center,
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.aboutTagline,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<PackageInfo>(
                    future: packageInfo,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Chip(
                          label: Text('...'),
                          avatar: Icon(Icons.new_releases_rounded, size: 16),
                          side: BorderSide.none,
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Chip(
                          label: Text(context.l10n.commonUnknown),
                          avatar: const Icon(Icons.error_outline_rounded, size: 16),
                          side: BorderSide.none,
                        );
                      }
                      return Chip(
                        label: Text('v${snapshot.data!.version}'),
                        avatar: const Icon(Icons.new_releases_rounded, size: 16),
                        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.5),
                        side: BorderSide.none,
                      );
                    },
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


class _DevelopersTab extends StatelessWidget {
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: developers.length,
      itemBuilder: (BuildContext context, int index) {
        return _DeveloperCard(developer: developers[index]);
      },
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

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({required this.developer});
  final _Developer developer;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color accent = developer.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 76,
                height: 76,
                color: accent.withValues(alpha: 0.08),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        developer.icon,
                        size: 48,
                        color: accent.withValues(alpha: 0.07),
                      ),
                    ),
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


class _FaqTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<(String, String)> faqs = <(String, String)>[
      (context.l10n.aboutFaqQ1, context.l10n.aboutFaqA1),
      (context.l10n.aboutFaqQ2, context.l10n.aboutFaqA2),
      (context.l10n.aboutFaqQ3, context.l10n.aboutFaqA3),
      (context.l10n.aboutFaqQ4, context.l10n.aboutFaqA4),
      (context.l10n.aboutFaqQ5, context.l10n.aboutFaqA5),
      (context.l10n.aboutFaqQ6, context.l10n.aboutFaqA6),
      (context.l10n.aboutFaqQ7, context.l10n.aboutFaqA7),
      (context.l10n.aboutFaqQ8, context.l10n.aboutFaqA8),
      (context.l10n.aboutFaqQ9, context.l10n.aboutFaqA9),
      (context.l10n.aboutFaqQ10, context.l10n.aboutFaqA10),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: faqs.length,
      itemBuilder: (BuildContext context, int index) {
        final (String q, String a) = faqs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              q,
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  a,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _ChangelogTab extends StatelessWidget {
  const _ChangelogTab({required this.packageInfo});
  final Future<PackageInfo> packageInfo;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<_Release> releases = <_Release>[
      _Release(
        version: 'v3.0.0',
        date: context.l10n.aboutChangelogDateJuly2026,
        changes: <String>[
          context.l10n.aboutChangelogV300C1,
          context.l10n.aboutChangelogV300C2,
          context.l10n.aboutChangelogV300C3,
          context.l10n.aboutChangelogV300C4,
          context.l10n.aboutChangelogV300C5,
          context.l10n.aboutChangelogV300C6,
        ],
      ),
      _Release(
        version: 'v2.1.0',
        date: context.l10n.aboutChangelogDateJune2026,
        changes: <String>[
          context.l10n.aboutChangelogV210C1,
          context.l10n.aboutChangelogV210C2,
          context.l10n.aboutChangelogV210C3,
          context.l10n.aboutChangelogV210C4,
          context.l10n.aboutChangelogV210C5,
        ],
      ),
      _Release(
        version: 'v2.0.5',
        date: context.l10n.aboutChangelogDateMarch2026,
        changes: <String>[
          context.l10n.aboutChangelogV205C1,
          context.l10n.aboutChangelogV205C2,
          context.l10n.aboutChangelogV205C3,
          context.l10n.aboutChangelogV205C4,
        ],
      ),
      _Release(
        version: 'v2.0.0',
        date: context.l10n.aboutChangelogDateJanuary2026,
        changes: <String>[
          context.l10n.aboutChangelogV200C1,
          context.l10n.aboutChangelogV200C2,
          context.l10n.aboutChangelogV200C3,
          context.l10n.aboutChangelogV200C4,
          context.l10n.aboutChangelogV200C5,
          context.l10n.aboutChangelogV200C6,
        ],
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        for (int i = 0; i < releases.length; i++)
          _ReleaseCard(release: releases[i], isFirst: i == 0),
        const SizedBox(height: 16),
        FutureBuilder<PackageInfo>(
          future: packageInfo,
          builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
            final String version = snapshot.data != null
                ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                : '...';
            return Text(
              context.l10n.aboutCurrentVersion(version),
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            );
          },
        ),
      ],
    );
  }
}

class _Release {
  const _Release({
    required this.version,
    required this.date,
    required this.changes,
  });
  final String version;
  final String date;
  final List<String> changes;
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release, this.isFirst = false});
  final _Release release;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isFirst ? scheme.primaryContainer.withValues(alpha: 0.3) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                release.version,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                release.date,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (isFirst) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.l10n.aboutLatest,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          for (final String change in release.changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '• ',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      change,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LegalTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        Text(
          context.l10n.legalSectionTitle,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.legalSectionSubtitle,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        _LegalCard(
          icon: Icons.privacy_tip_rounded,
          title: context.l10n.legalPrivacyTitle,
          subtitle: context.l10n.legalPrivacySubtitle,
          iconColor: scheme.primary,
          onTap: () => context.push('/legal/privacy'),
        ),
        const SizedBox(height: 10),
        _LegalCard(
          icon: Icons.description_rounded,
          title: context.l10n.legalToSTitle,
          subtitle: context.l10n.legalToSSubtitle,
          iconColor: scheme.tertiary,
          onTap: () => context.push('/legal/tos'),
        ),
        const SizedBox(height: 10),
        _LegalCard(
          icon: Icons.assignment_turned_in_rounded,
          title: context.l10n.legalConsentTitle,
          subtitle: context.l10n.legalConsentSubtitle,
          iconColor: scheme.secondary,
          onTap: () => context.push('/legal/consent'),
        ),
        const SizedBox(height: 28),
        Text(
          context.l10n.alphaSectionTitle,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.error.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.bug_report_rounded, color: scheme.error, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.alphaSectionBadge,
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.alphaSectionBody,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.alphaDialogReportTo,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  _TelegramLink(
                    handle: 'Door0S',
                    onTap: () => _launchTelegram('Door0S'),
                  ),
                  const SizedBox(width: 10),
                  _TelegramLink(
                    handle: 'sanlsan',
                    onTap: () => _launchTelegram('sanlsan'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => AlphaTestDialog.showIfFirstLaunch(context),
          icon: const Icon(Icons.replay_rounded, size: 18),
          label: Text(context.l10n.alphaShowAgain),
        ),
      ],
    );
  }

  Future<void> _launchTelegram(String handle) async {
    final uri = Uri.parse('https://t.me/$handle');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelegramLink extends StatelessWidget {
  const _TelegramLink({required this.handle, required this.onTap});

  final String handle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ActionChip(
      label: Text('@$handle'),
      avatar: Icon(Icons.send_rounded, size: 16, color: scheme.primary),
      onPressed: onTap,
    );
  }
}
