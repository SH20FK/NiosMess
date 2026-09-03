import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/alpha_test_dialog.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsAboutScreen extends StatefulWidget {
  const SettingsAboutScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  @override
  State<SettingsAboutScreen> createState() => _SettingsAboutScreenState();
}

class _SettingsAboutScreenState extends State<SettingsAboutScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heroController;
  late final Future<PackageInfo> _packageInfo;
  int _selectedTabIndex = 0;

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

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyVersion(String version) {
    Clipboard.setData(ClipboardData(text: version));
    AppToast.showSuccess(context, 'Версия $version скопирована');
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SettingsScaffold(
      title: context.l10n.settingsAboutTitle,
      isEmbedded: widget.isEmbedded,
      children: <Widget>[
        // 1. Compact Hero Header
        _buildHeroCard(context, scheme, textTheme),
        const SizedBox(height: 12),

        // 2. Material 3 Expressive Pill Tab Selector
        _buildPillTabSelector(context, scheme, textTheme),
        const SizedBox(height: 16),

        // 3. Tab Content View (Smooth Transition)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedTabIndex),
            child: _buildCurrentTabContent(context, scheme, textTheme),
          ),
        ),

        const SizedBox(height: 12),

        // 4. Proprietary Closed-Source Footer
        _buildFooter(context, scheme, textTheme),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Hero Header
  // ---------------------------------------------------------------------------
  Widget _buildHeroCard(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
          width: 1,
        ),
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.25,
          colors: <Color>[
            scheme.primary.withValues(alpha: isDark ? 0.16 : 0.08),
            isDark ? scheme.surfaceContainerLow : scheme.surface,
          ],
        ),
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          children: <Widget>[
            // Rotating Animated M3 Cookie Badge with Logo
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  M3Container.c9SidedCookie(
                    width: 72,
                    height: 72,
                    color: scheme.primary,
                    child: const SizedBox(),
                  )
                      .animate(onPlay: (AnimationController c) => c.repeat())
                      .rotate(duration: 14.seconds, curve: Curves.linear),
                  SvgPicture.asset(
                    'assets/svg/niosmess_logo_tintable.svg',
                    width: 42,
                    height: 42,
                    colorFilter: ColorFilter.mode(
                      scheme.onPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
            )
                .animate(controller: _heroController)
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
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 3),

            // Tagline
            Text(
              context.l10n.aboutTagline,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),

            // Version Pill (Tappable to copy)
            FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
                final String ver = snapshot.data != null
                    ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                    : 'v3.10.2+19';
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _copyVersion(ver),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ver,
                            style: textTheme.labelMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Quick Actions Bar (Closed-source links only: Alpha-test, Telegram, ni-os.ru)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                _QuickHeroButton(
                  icon: Icons.science_rounded,
                  label: 'Альфа-тест',
                  color: const Color(0xFFFF9800),
                  onTap: () => AlphaTestDialog.showIfFirstLaunch(context),
                ),
                _QuickHeroButton(
                  svgAsset: 'assets/svg/telegram_logo.svg',
                  label: 'Telegram',
                  color: const Color(0xFF03A9F4),
                  onTap: () => _openUrl('https://t.me/niosmess'),
                ),
                _QuickHeroButton(
                  svgAsset: 'assets/svg/globe.svg',
                  label: 'ni-os.ru',
                  color: const Color(0xFF00BCD4),
                  onTap: () => _openUrl('https://ni-os.ru'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Material 3 Expressive Pill Tab Selector
  // ---------------------------------------------------------------------------
  Widget _buildPillTabSelector(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final List<_AboutTabItem> tabs = <_AboutTabItem>[
      _AboutTabItem(
        icon: Icons.people_alt_rounded,
        label: context.l10n.aboutTabDevelopers,
      ),
      _AboutTabItem(
        icon: Icons.gavel_rounded,
        label: context.l10n.aboutTabLegal,
      ),
      _AboutTabItem(
        icon: Icons.help_outline_rounded,
        label: context.l10n.aboutTabFaq,
      ),
      _AboutTabItem(
        icon: Icons.history_rounded,
        label: context.l10n.aboutTabChangelog,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLowest : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: tabs.asMap().entries.map((MapEntry<int, _AboutTabItem> entry) {
          final int index = entry.key;
          final _AboutTabItem tab = entry.value;
          final bool isSelected = _selectedTabIndex == index;

          return Expanded(
            child: Material(
              color: isSelected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => setState(() => _selectedTabIndex = index),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        tab.icon,
                        size: 18,
                        color: isSelected
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 11,
                          color: isSelected
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Current Tab Content Switcher
  // ---------------------------------------------------------------------------
  Widget _buildCurrentTabContent(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildDevelopersTab(context, scheme, textTheme);
      case 1:
        return _buildLegalTab(context, scheme, textTheme);
      case 2:
        return _buildFaqTab(context, scheme, textTheme);
      case 3:
      default:
        return _buildChangelogTab(context, scheme, textTheme);
    }
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Developers (High-Contrast Full-Color Avatars)
  // ---------------------------------------------------------------------------
  Widget _buildDevelopersTab(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return SettingsSection(
      title: context.l10n.aboutTabDevelopers,
      subtitle: 'Архитекторы и создатели экосистемы защищённого мессенджера NiosMess',
      isCard: false,
      children: <Widget>[
        _DeveloperTile(
          name: 'Sanlsan',
          role: 'Основатель & Главный Архитектор',
          assetPath: 'assets/developers/Sanlsan_clean.png',
          svgAssetPath: 'assets/svg/developer_sanlsan.svg',
          fallbackIcon: Icons.dns_rounded,
          accentColor: const Color(0xFF2196F3),
          telegramHandle: 'hello_sanlsan',
          onOpenTelegram: () => _openUrl('https://t.me/hello_sanlsan'),
        ),
        const SizedBox(height: 14),
        _DeveloperTile(
          name: 'SH20FK',
          role: 'Руководитель разработки клиента & UX',
          assetPath: 'assets/developers/SH20FK_clean.png',
          svgAssetPath: 'assets/svg/developer_sh20fk.svg',
          fallbackIcon: Icons.phone_iphone_rounded,
          accentColor: const Color(0xFF7C4DFF),
          telegramHandle: 'Door0S',
          onOpenTelegram: () => _openUrl('https://t.me/Door0S'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Legal Documents (All 4 Official Documents Included)
  // ---------------------------------------------------------------------------
  Widget _buildLegalTab(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return SettingsSection(
      title: context.l10n.aboutTabLegal,
      subtitle: 'Правовые документы, условия сервиса и лицензии',
      children: <Widget>[
        _ActionRow(
          icon: Icons.shield_outlined,
          iconColor: const Color(0xFF4CAF50),
          title: context.l10n.settingsPrivacyPolicy,
          subtitle: 'Политика конфиденциальности: обработка данных и криптография',
          trailing: const Icon(Icons.chevron_right_rounded, size: 18),
          onTap: () => context.push('/legal/privacy'),
        ),
        _ActionRow(
          icon: Icons.gavel_rounded,
          iconColor: const Color(0xFF3F51B5),
          title: context.l10n.settingsTermsOfService,
          subtitle: 'Пользовательское соглашение и правила платформы Nios',
          trailing: const Icon(Icons.chevron_right_rounded, size: 18),
          onTap: () => context.push('/legal/terms'),
        ),
        _ActionRow(
          icon: Icons.assignment_turned_in_outlined,
          iconColor: const Color(0xFF009688),
          title: 'Согласие на обработку данных',
          subtitle: 'Согласие субъекта на сбор и хранение учетных данных',
          trailing: const Icon(Icons.chevron_right_rounded, size: 18),
          onTap: () => context.push('/legal/consent'),
        ),
        _ActionRow(
          icon: Icons.receipt_long_rounded,
          iconColor: const Color(0xFFFF5722),
          title: 'Сторонние лицензии и библиотеки',
          subtitle: 'Информация об открытых библиотеках, используемых в клиенте',
          trailing: const Icon(Icons.chevron_right_rounded, size: 18),
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: 'NiosMess',
              applicationVersion: '3.10.2',
              applicationIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: SvgPicture.asset('assets/svg/niosmess_logo_tintable.svg'),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: FAQ (All 10 Questions)
  // ---------------------------------------------------------------------------
  Widget _buildFaqTab(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final List<(String, String)> allFaqs = <(String, String)>[
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

    return SettingsSection(
      title: context.l10n.aboutTabFaq,
      subtitle: 'Ответы на популярные вопросы о безопасности и возможностях',
      children: allFaqs.map((faq) {
        final (String q, String a) = faq;
        return _ExpandableFaqTile(
          question: q,
          answer: a,
          iconColor: const Color(0xFFFFB300),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Changelog
  // ---------------------------------------------------------------------------
  Widget _buildChangelogTab(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final List<_ReleaseInfo> pastReleases = <_ReleaseInfo>[
      _ReleaseInfo(
        version: 'v2.1.0',
        date: context.l10n.aboutChangelogDateJune2026,
        accentColor: const Color(0xFF26A69A),
        changes: <String>[
          context.l10n.aboutChangelogV210C1,
          context.l10n.aboutChangelogV210C2,
          context.l10n.aboutChangelogV210C3,
          context.l10n.aboutChangelogV210C4,
          context.l10n.aboutChangelogV210C5,
        ],
      ),
      _ReleaseInfo(
        version: 'v2.0.5',
        date: context.l10n.aboutChangelogDateMarch2026,
        accentColor: const Color(0xFF5C6BC0),
        changes: <String>[
          context.l10n.aboutChangelogV205C1,
          context.l10n.aboutChangelogV205C2,
          context.l10n.aboutChangelogV205C3,
          context.l10n.aboutChangelogV205C4,
        ],
      ),
      _ReleaseInfo(
        version: 'v2.0.0',
        date: context.l10n.aboutChangelogDateJanuary2026,
        accentColor: const Color(0xFF7E57C2),
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

    return SettingsSection(
      title: context.l10n.aboutTabChangelog,
      subtitle: 'История релизов и обновлений платформы NiosMess',
      children: <Widget>[
        // Current Major Release Highlight
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _SquircleIcon(
                    icon: Icons.auto_awesome_rounded,
                    color: const Color(0xFF9C27B0),
                    size: 40,
                    iconSize: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              'v3.10.2 (Expressive)',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Текущая',
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.aboutChangelogDateJuly2026,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildChangeItem(scheme, textTheme, context.l10n.aboutChangelogV300C1),
              _buildChangeItem(scheme, textTheme, 'Двухпанельный Master-Detail режим настроек для ПК и планшетов'),
              _buildChangeItem(scheme, textTheme, 'Единая авторизация Nios ID по протоколу OAuth 2.0 PKCE'),
              _buildChangeItem(scheme, textTheme, 'Адаптивная лента NiosGram с быстрыми реакциями и красивыми карточками'),
              _buildChangeItem(scheme, textTheme, 'Глобальная плавная инерционная прокрутка на Web-платформе'),
              _buildChangeItem(scheme, textTheme, context.l10n.aboutChangelogV300C4),
              _buildChangeItem(scheme, textTheme, context.l10n.aboutChangelogV300C6),
            ],
          ),
        ),

        // Past Releases
        ...pastReleases.map(
          (release) => _PreviousReleaseTile(release: release),
        ),
      ],
    );
  }

  Widget _buildChangeItem(
    ColorScheme scheme,
    TextTheme textTheme,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Closed-Source Footer
  // ---------------------------------------------------------------------------
  Widget _buildFooter(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.shield_rounded,
                  size: 13,
                  color: scheme.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  'Безопасность и сквозное шифрование по умолчанию',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'NiosMess © 2026 • Все права защищены',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Helper Widgets & Data Structures
// =============================================================================

class _AboutTabItem {
  const _AboutTabItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class _SquircleIcon extends StatelessWidget {
  const _SquircleIcon({
    required this.icon,
    required this.color,
    this.size = 38,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class _QuickHeroButton extends StatelessWidget {
  const _QuickHeroButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.svgAsset,
  });

  final IconData? icon;
  final String? svgAsset;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (svgAsset != null)
                SvgPicture.asset(
                  svgAsset!,
                  width: 15,
                  height: 15,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                )
              else if (icon != null)
                Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeveloperTile extends StatelessWidget {
  const _DeveloperTile({
    required this.name,
    required this.role,
    required this.assetPath,
    required this.fallbackIcon,
    required this.accentColor,
    required this.onOpenTelegram,
    this.svgAssetPath,
    this.telegramHandle,
  });

  final String name;
  final String role;
  final String assetPath;
  final String? svgAssetPath;
  final IconData fallbackIcon;
  final Color accentColor;
  final String? telegramHandle;
  final VoidCallback onOpenTelegram;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth > 500;

        final Color avatarBg = isDark
            ? Color.alphaBlend(
                accentColor.withValues(alpha: 0.16),
                scheme.surfaceContainerHighest,
              )
            : Color.alphaBlend(
                accentColor.withValues(alpha: 0.08),
                scheme.surfaceContainerHighest,
              );

        final Widget avatarWidget = Container(
          width: isWide ? 160 : 140,
          height: isWide ? 160 : 140,
          decoration: BoxDecoration(
            color: avatarBg,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.40 : 0.25),
              width: 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accentColor.withValues(alpha: isDark ? 0.20 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: svgAssetPath != null
              ? SvgPicture.asset(
                  svgAssetPath!,
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(accentColor, BlendMode.srcIn),
                  placeholderBuilder: (BuildContext context) => Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    color: accentColor,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (_, _, _) =>
                        Center(child: Icon(fallbackIcon, size: 56, color: accentColor)),
                  ),
                )
              : Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  color: accentColor,
                  colorBlendMode: BlendMode.srcIn,
                  errorBuilder: (BuildContext context, Object error, StackTrace? trace) =>
                      Center(child: Icon(fallbackIcon, size: 56, color: accentColor)),
                ),
        );

        final Widget infoAndButtonWidget = Column(
          crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Name + Verified Badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    name,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: -0.4,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.verified_rounded,
                  size: 20,
                  color: accentColor,
                ),
              ],
            ),
            if (telegramHandle != null) ...<Widget>[
              const SizedBox(height: 3),
              Text(
                '@$telegramHandle',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 8),

            // Role pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
                ),
              ),
              child: Text(
                role,
                style: textTheme.labelMedium?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Official Telegram SVG Contact Button
            FilledButton.tonal(
              onPressed: onOpenTelegram,
              style: FilledButton.styleFrom(
                backgroundColor: accentColor.withValues(alpha: isDark ? 0.20 : 0.12),
                foregroundColor: accentColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: accentColor.withValues(alpha: isDark ? 0.35 : 0.28),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SvgPicture.asset(
                    'assets/svg/telegram_logo.svg',
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(accentColor, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    telegramHandle != null
                        ? 'Связаться (@$telegramHandle)'
                        : 'Связаться в Telegram',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        return Container(
          decoration: BoxDecoration(
            color: isDark ? scheme.surfaceContainerLow : scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.35 : 0.22),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    avatarWidget,
                    const SizedBox(width: 24),
                    Expanded(child: infoAndButtonWidget),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    avatarWidget,
                    const SizedBox(height: 16),
                    infoAndButtonWidget,
                  ],
                ),
        );
      },
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _SquircleIcon(icon: icon, color: iconColor),
        title: Text(
          title,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.25,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}

class _ExpandableFaqTile extends StatelessWidget {
  const _ExpandableFaqTile({
    required this.question,
    required this.answer,
    required this.iconColor,
  });

  final String question;
  final String answer;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _SquircleIcon(
        icon: Icons.help_outline_rounded,
        color: iconColor,
        size: 34,
        iconSize: 18,
      ),
      title: Text(
        question,
        style: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          color: scheme.onSurface,
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(64, 0, 18, 14),
      children: <Widget>[
        Text(
          answer,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _ReleaseInfo {
  const _ReleaseInfo({
    required this.version,
    required this.date,
    required this.changes,
    required this.accentColor,
  });

  final String version;
  final String date;
  final List<String> changes;
  final Color accentColor;
}

class _PreviousReleaseTile extends StatelessWidget {
  const _PreviousReleaseTile({required this.release});
  final _ReleaseInfo release;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: _SquircleIcon(
        icon: Icons.history_rounded,
        color: release.accentColor,
        size: 34,
        iconSize: 18,
      ),
      title: Text(
        release.version,
        style: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        release.date,
        style: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(64, 0, 18, 14),
      children: release.changes
          .map(
            (String change) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: release.accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      change,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
