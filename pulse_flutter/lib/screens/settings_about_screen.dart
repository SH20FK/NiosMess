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
        appBar: AppBar(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: Text(
            context.l10n.settingsAboutTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: NestedScrollView(
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                return <Widget>[
                  SliverToBoxAdapter(
                    child: _HeroBlock(
                      animation: _heroController,
                      packageInfo: _packageInfo,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.center,
                          dividerHeight: 0,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          labelColor: scheme.onPrimary,
                          unselectedLabelColor: scheme.onSurfaceVariant,
                          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                          unselectedLabelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          tabs: <Tab>[
                            Tab(
                              icon: const Icon(Icons.code_rounded, size: 18),
                              text: context.l10n.aboutTabDevelopers,
                              iconMargin: const EdgeInsets.only(bottom: 2),
                            ),
                            Tab(
                              icon: const Icon(Icons.help_outline_rounded, size: 18),
                              text: context.l10n.aboutTabFaq,
                              iconMargin: const EdgeInsets.only(bottom: 2),
                            ),
                            Tab(
                              icon: const Icon(Icons.history_rounded, size: 18),
                              text: context.l10n.aboutTabChangelog,
                              iconMargin: const EdgeInsets.only(bottom: 2),
                            ),
                            Tab(
                              icon: const Icon(Icons.gavel_rounded, size: 18),
                              text: context.l10n.aboutTabLegal,
                              iconMargin: const EdgeInsets.only(bottom: 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: <Widget>[
                  _DevelopersTab(),
                  _FaqTab(),
                  _ChangelogTab(packageInfo: _packageInfo),
                  _LegalTab(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({required this.animation, required this.packageInfo});
  final AnimationController animation;
  final Future<PackageInfo> packageInfo;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: <Color>[
            scheme.primaryContainer.withValues(alpha: 0.35),
            scheme.surfaceContainerHigh.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Rotating M3 Logo Badge
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  M3Container.c9SidedCookie(
                    width: 76,
                    height: 76,
                    color: scheme.primary,
                    child: const SizedBox(),
                  ).animate(onPlay: (c) => c.repeat())
                   .rotate(duration: 12.seconds, curve: Curves.linear),
                  SvgPicture.asset(
                    'assets/svg/niosmess_logo_tintable.svg',
                    width: 44,
                    height: 44,
                    colorFilter: ColorFilter.mode(
                      scheme.onPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
            ).animate(controller: animation)
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1.0, 1.0),
                curve: Curves.easeOutBack,
                duration: 500.ms,
              )
              .fade(duration: 350.ms),
            const SizedBox(height: 14),

            // App Name
            Text(
              context.l10n.appName,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 4),

            // Tagline
            Text(
              context.l10n.aboutTagline,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),

            // Version Pill
            FutureBuilder<PackageInfo>(
              future: packageInfo,
              builder: (context, snapshot) {
                final String ver = snapshot.data != null
                    ? 'v${snapshot.data!.version}'
                    : 'v3.0.0';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 14, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        ver,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Quick Actions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.bug_report_rounded, size: 16),
                  label: const Text('Альфа-тест'),
                  onPressed: () => AlphaTestDialog.showIfFirstLaunch(context),
                ),
                ActionChip(
                  avatar: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Telegram'),
                  onPressed: () => _openUrl('https://t.me/niosmess'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.code_rounded, size: 16),
                  label: const Text('GitHub'),
                  onPressed: () => _openUrl('https://github.com'),
                ),
              ],
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
        accentColor: Colors.blueAccent,
        tags: <String>[
          context.l10n.developersTagBackend,
          context.l10n.developersTagApi,
          context.l10n.developersTagAuth,
        ],
        telegram: 'sanlsan',
      ),
      _Developer(
        name: 'SH20FK',
        role: context.l10n.developersSh20fkRole,
        description: context.l10n.developersSh20fkDescription,
        assetPath: 'assets/developers/SH20FK_clean.png',
        icon: Icons.phone_iphone_rounded,
        accentColor: Colors.deepPurpleAccent,
        tags: <String>[
          context.l10n.developersTagFlutter,
          context.l10n.developersTagUx,
          context.l10n.developersTagClient,
        ],
        telegram: 'Door0S',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
    this.telegram,
  });
  final String name;
  final String role;
  final String description;
  final String assetPath;
  final IconData icon;
  final Color accentColor;
  final List<String> tags;
  final String? telegram;
}

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({required this.developer});
  final _Developer developer;

  Future<void> _openTelegram(String handle) async {
    final uri = Uri.parse('https://t.me/$handle');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color accent = developer.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Avatar frame
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accent.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    developer.assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, trace) => Center(
                      child: Icon(developer.icon, size: 32, color: accent),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Content
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
                      if (developer.telegram != null)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.send_rounded, size: 16, color: accent),
                          tooltip: '@${developer.telegram}',
                          onPressed: () => _openTelegram(developer.telegram!),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      developer.role,
                      style: textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    developer.description,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: developer.tags
                        .map(
                          (String tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              tag,
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: faqs.length,
      itemBuilder: (BuildContext context, int index) {
        final (String q, String a) = faqs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            title: Text(
              q,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isFirst
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFirst
              ? scheme.primary.withValues(alpha: 0.3)
              : scheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(18),
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
          const SizedBox(height: 12),
          for (final String change in release.changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '• ',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      change,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        height: 1.35,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        Text(
          context.l10n.legalSectionTitle,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.legalSectionSubtitle,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 24),
        Text(
          context.l10n.alphaSectionTitle,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
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
              const SizedBox(height: 8),
              Text(
                context.l10n.alphaSectionBody,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.alphaDialogReportTo,
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: <Widget>[
                  _TelegramLink(
                    handle: 'Door0S',
                    onTap: () => _launchTelegram('Door0S'),
                  ),
                  _TelegramLink(
                    handle: 'sanlsan',
                    onTap: () => _launchTelegram('sanlsan'),
                  ),
                ],
              ),
            ],
          ),
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
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
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
