import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/services/update/app_update_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ota_update_provider.dart';
import 'package:pulse_flutter/widgets/alpha_test_dialog.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/update/app_update_dialog.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';

class SettingsAboutScreen extends ConsumerStatefulWidget {
  const SettingsAboutScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  @override
  ConsumerState<SettingsAboutScreen> createState() => _SettingsAboutScreenState();
}

class _SettingsAboutScreenState extends ConsumerState<SettingsAboutScreen> {
  late final Future<PackageInfo> _packageInfo;
  int _selectedTabIndex = 0;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  Future<void> _openUrl(String url) async {
    await AppUrlLauncher.openUrl(context, url);
  }

  void _copyVersion(String version) {
    Clipboard.setData(ClipboardData(text: version));
    HapticService.tap();
    AppToast.showSuccess(context, 'Версия $version скопирована');
  }

  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);
    HapticService.tap();

    try {
      final AppUpdateService updateService = const AppUpdateService();
      final AppUpdateInfo updateInfo = await updateService.checkForUpdate();

      if (!mounted) return;

      if (updateInfo.hasUpdate) {
        await AppUpdateDialog.show(context, updateInfo);
      } else {
        AppToast.showSuccess(
          context,
          'У вас установлена последняя версия (v${updateInfo.currentVersion})',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Не удалось проверить обновления: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SettingsScaffold(
      title: context.l10n.settingsAboutTitle,
      isEmbedded: widget.isEmbedded,
      children: <Widget>[
        // 1. Google Material 3 Expressive Hero Card
        _buildHeroCard(context, scheme, textTheme, isDark),
        const SizedBox(height: 14),

        // 2. Android System Update Style Card
        _buildOtaUpdateCard(context, scheme, textTheme, isDark),
        const SizedBox(height: 16),

        // 3. Native Material 3 SegmentedButton Tab Selector
        _buildSegmentedTabSelector(context, scheme, textTheme),
        const SizedBox(height: 16),

        // 4. Tab Content View with M3 Spring Transition
        _buildCurrentTabContent(context, scheme, textTheme, isDark),
        const SizedBox(height: 14),

        // 5. Authentic M3 Minimalist Footer
        _buildFooter(context, scheme, textTheme),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Material 3 Expressive Hero Card
  // ---------------------------------------------------------------------------
  Widget _buildHeroCard(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    return Material(
      color: isDark ? scheme.surfaceContainerLow : scheme.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.35),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: <Widget>[
          // Interactive spring scale hero logo (no infinite rotation)
          _InteractiveHeroLogo(scheme: scheme),
          const SizedBox(height: 14),

          // App Name
          Text(
            context.l10n.appName,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontSize: 22,
              color: scheme.onSurface,
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
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),

          // Copyable Version Badge
          FutureBuilder<PackageInfo>(
            future: _packageInfo,
            builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
              final String ver = snapshot.data != null
                  ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                  : AppConstants.appFullVersion;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _copyVersion(ver),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.6 : 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
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
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Quick Action M3 Tonal Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: <Widget>[
              if (!kIsWeb)
                _M3ActionChip(
                  icon: Icons.smartphone_rounded,
                  label: 'Устройство',
                  onTap: () => context.push('/settings/system-device'),
                ),
              _M3ActionChip(
                icon: Icons.science_rounded,
                label: 'Альфа-тест',
                onTap: () => AlphaTestDialog.show(context),
              ),
              _M3ActionChip(
                svgAsset: 'assets/svg/telegram_logo.svg',
                label: 'Telegram',
                onTap: () => _openUrl('https://t.me/niosmess'),
              ),
              _M3ActionChip(
                svgAsset: 'assets/svg/globe.svg',
                label: 'ni-os.ru',
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
  // 2. Android System Update Style Card
  // ---------------------------------------------------------------------------
  Widget _buildOtaUpdateCard(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    final OtaUpdateState otaState = ref.watch(otaUpdateProvider);
    final bool isDownloading = otaState.status == OtaStatus.downloading;
    final bool isReady = otaState.status == OtaStatus.readyToInstall;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isReady
                      ? scheme.primaryContainer
                      : (isDownloading
                          ? scheme.secondaryContainer
                          : scheme.primaryContainer))
                  .withValues(alpha: isDark ? 0.45 : 0.65),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isReady
                  ? Icons.check_circle_rounded
                  : (isDownloading
                      ? Icons.cloud_download_rounded
                      : Icons.system_update_rounded),
              size: 22,
              color: isReady
                  ? scheme.primary
                  : (isDownloading ? scheme.secondary : scheme.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Обновление системы',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isReady
                      ? 'Готово к установке (v${otaState.updateInfo?.latestVersion})'
                      : (isDownloading
                          ? 'Загрузка: ${(otaState.progress * 100).toInt()}% • в фоне'
                          : 'OTA-обновления NiosMess'),
                  style: textTheme.bodySmall?.copyWith(
                    color: isReady
                        ? scheme.primary
                        : (isDownloading ? scheme.secondary : scheme.onSurfaceVariant),
                    fontWeight: isReady ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: _isCheckingUpdate
                ? null
                : () {
                    if (isReady) {
                      HapticService.confirm();
                      ref.read(otaUpdateProvider.notifier).installApk(context: context);
                    } else if (isDownloading && otaState.updateInfo != null) {
                      HapticService.tap();
                      AppUpdateDialog.show(context, otaState.updateInfo!);
                    } else {
                      _checkForUpdate();
                    }
                  },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 38),
            ),
            child: _isCheckingUpdate
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        isReady
                            ? Icons.system_update_rounded
                            : (isDownloading
                                ? Icons.open_in_new_rounded
                                : Icons.refresh_rounded),
                        size: 16,
                        color: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isReady
                            ? 'Установить'
                            : (isDownloading ? 'Прогресс' : 'Проверить'),
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Material 3 SegmentedButton Tab Selector
  // ---------------------------------------------------------------------------
  Widget _buildSegmentedTabSelector(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: <ButtonSegment<int>>[
              ButtonSegment<int>(
                value: 0,
                icon: const Icon(Icons.people_alt_rounded, size: 18),
                label: Text(
                  context.l10n.aboutTabDevelopers,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
              ButtonSegment<int>(
                value: 1,
                icon: const Icon(Icons.gavel_rounded, size: 18),
                label: Text(
                  context.l10n.aboutTabLegal,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
              ButtonSegment<int>(
                value: 2,
                icon: const Icon(Icons.help_outline_rounded, size: 18),
                label: Text(
                  context.l10n.aboutTabFaq,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
              ButtonSegment<int>(
                value: 3,
                icon: const Icon(Icons.history_rounded, size: 18),
                label: Text(
                  context.l10n.aboutTabChangelog,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
            selected: <int>{_selectedTabIndex},
            onSelectionChanged: (Set<int> newSelection) {
              HapticService.selection();
              setState(() {
                _selectedTabIndex = newSelection.first;
              });
            },
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? scheme.surfaceContainerLowest
                  : scheme.surfaceContainerLow,
              selectedBackgroundColor: scheme.secondaryContainer,
              selectedForegroundColor: scheme.onSecondaryContainer,
              foregroundColor: scheme.onSurfaceVariant,
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Current Tab Content with M3 Spring Transitions
  // ---------------------------------------------------------------------------
  Widget _buildCurrentTabContent(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: M3SpringCurves.spatial,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.9, curve: Curves.easeOut),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: M3SpringCurves.spatial,
              )),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedTabIndex),
          child: _tabWidgetForIndex(_selectedTabIndex, context, scheme, textTheme, isDark),
        ),
      ),
    );
  }

  Widget _tabWidgetForIndex(
    int index,
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    switch (index) {
      case 0:
        return _buildDevelopersTab(context, scheme, textTheme, isDark);
      case 1:
        return _buildLegalTab(context, scheme, textTheme, isDark);
      case 2:
        return _buildFaqTab(context, scheme, textTheme, isDark);
      case 3:
      default:
        return _buildChangelogTab(context, scheme, textTheme, isDark);
    }
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Developers (Google Contacts Style Tiles)
  // ---------------------------------------------------------------------------
  Widget _buildDevelopersTab(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    final Widget sanlsanTile = _GoogleContactsDeveloperTile(
      name: 'Sanlsan',
      role: 'Основатель & Главный Архитектор',
      telegramHandle: 'hello_sanlsan',
      assetPath: 'assets/developers/Sanlsan_clean.png',
      svgAssetPath: 'assets/svg/developer_sanlsan.svg',
      fallbackIcon: Icons.dns_rounded,
      onOpenTelegram: () => _openUrl('https://t.me/hello_sanlsan'),
    );

    final Widget sh20fkTile = _GoogleContactsDeveloperTile(
      name: 'SH20FK',
      role: 'Руководитель разработки клиента & UX',
      telegramHandle: 'Door0S',
      assetPath: 'assets/developers/SH20FK_clean.png',
      svgAssetPath: 'assets/svg/developer_sh20fk.svg',
      fallbackIcon: Icons.phone_iphone_rounded,
      onOpenTelegram: () => _openUrl('https://t.me/Door0S'),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: sanlsanTile),
              const SizedBox(width: 12),
              Expanded(child: sh20fkTile),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            sanlsanTile,
            const SizedBox(height: 12),
            sh20fkTile,
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Legal Documents (Grouped M3 Surface with Subtle Dividers)
  // ---------------------------------------------------------------------------
  Widget _buildLegalTab(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.35),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          _ActionRow(
            icon: Icons.shield_outlined,
            iconColor: scheme.primary,
            title: context.l10n.settingsPrivacyPolicy,
            subtitle: 'Обработка данных, сквозное шифрование и безопасность',
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => context.push('/legal/privacy'),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.15)),
          _ActionRow(
            icon: Icons.gavel_rounded,
            iconColor: scheme.secondary,
            title: context.l10n.settingsTermsOfService,
            subtitle: 'Пользовательское соглашение и правила сервиса',
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => context.push('/legal/terms'),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.15)),
          _ActionRow(
            icon: Icons.assignment_turned_in_outlined,
            iconColor: scheme.tertiary,
            title: 'Согласие на обработку данных',
            subtitle: 'Согласие субъекта на сбор и хранение данных',
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => context.push('/legal/consent'),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.15)),
          _ActionRow(
            icon: Icons.receipt_long_rounded,
            iconColor: scheme.onSurfaceVariant,
            title: 'Сторонние лицензии и библиотеки',
            subtitle: 'Информация об открытых компонентах клиента',
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'NiosMess',
                applicationVersion: AppConstants.appVersion,
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: FAQ (Material 3 Grouped Accordion)
  // ---------------------------------------------------------------------------
  Widget _buildFaqTab(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    bool isDark,
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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.35),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: allFaqs.asMap().entries.map((MapEntry<int, (String, String)> entry) {
          final int index = entry.key;
          final (String q, String a) = entry.value;
          final bool isLast = index == allFaqs.length - 1;

          return Column(
            children: <Widget>[
              _ExpandableFaqTile(
                question: q,
                answer: a,
              ),
              if (!isLast)
                Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.12)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Changelog
  // ---------------------------------------------------------------------------
  Widget _buildChangelogTab(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    final List<_ReleaseInfo> pastReleases = <_ReleaseInfo>[
      _ReleaseInfo(
        version: 'v2.1.0',
        date: context.l10n.aboutChangelogDateJune2026,
        accentColor: scheme.primary,
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
        accentColor: scheme.secondary,
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
        accentColor: scheme.tertiary,
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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.35),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Current Major Release Highlight
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: isDark ? 0.45 : 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: <Widget>[
                        Text(
                          '${AppConstants.appVersionWithPrefix} (Expressive)',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
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
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildChangeItem(scheme, textTheme, 'Ультра-плавный движок анимаций (120 FPS без рывков и дерганий списков)'),
          _buildChangeItem(scheme, textTheme, 'Комплексная оптимизация рендеринга для Web и Android APK'),
          _buildChangeItem(scheme, textTheme, 'Исключение аппаратной диагностики в веб-клиенте для чистоты интерфейса'),
          _buildChangeItem(scheme, textTheme, 'Адаптивные и безопасные переходы экранов Material 3 Expressive'),
          _buildChangeItem(scheme, textTheme, 'Мгновенный отклик переключателей с тактильной индикацией thumbIcon'),
          _buildChangeItem(scheme, textTheme, 'Информативные статусные бейджи в Master-Detail режиме настроек'),
          _buildChangeItem(scheme, textTheme, context.l10n.aboutChangelogV300C6),

          const SizedBox(height: 14),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.15)),
          const SizedBox(height: 10),

          // Past Releases
          ...pastReleases.map(
            (release) => _PreviousReleaseTile(release: release),
          ),
        ],
      ),
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
  // 5. Minimalist M3 Footer
  // ---------------------------------------------------------------------------
  Widget _buildFooter(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.shield_rounded,
                  size: 13,
                  color: scheme.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Безопасность и сквозное шифрование по умолчанию',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
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

class _InteractiveHeroLogo extends StatefulWidget {
  const _InteractiveHeroLogo({
    required this.scheme,
  });

  final ColorScheme scheme;

  @override
  State<_InteractiveHeroLogo> createState() => _InteractiveHeroLogoState();
}

class _InteractiveHeroLogoState extends State<_InteractiveHeroLogo> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticService.tap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: M3SpringCurves.bouncy,
        child: M3Container(
          Shapes.c9_sided_cookie,
          width: 76,
          height: 76,
          color: widget.scheme.primary,
          child: Center(
            child: SvgPicture.asset(
              'assets/svg/niosmess_logo_tintable.svg',
              width: 44,
              height: 44,
              colorFilter: ColorFilter.mode(
                widget.scheme.onPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    ).animate().scale(duration: 400.ms, curve: M3SpringCurves.spatial).fade(duration: 300.ms);
  }
}

class _M3ActionChip extends StatelessWidget {
  const _M3ActionChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.svgAsset,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final String? svgAsset;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      type: MaterialType.transparency,
      child: ActionChip(
        avatar: svgAsset != null
            ? SvgPicture.asset(
                svgAsset!,
                width: 15,
                height: 15,
                colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
              )
            : (icon != null ? Icon(icon, size: 15, color: scheme.primary) : null),
        label: Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
            fontSize: 12,
          ),
        ),
        onPressed: () {
          HapticService.tap();
          onTap();
        },
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
    );
  }
}

class _GoogleContactsDeveloperTile extends StatelessWidget {
  const _GoogleContactsDeveloperTile({
    required this.name,
    required this.role,
    required this.telegramHandle,
    required this.assetPath,
    required this.fallbackIcon,
    required this.onOpenTelegram,
    this.svgAssetPath,
  });

  final String name;
  final String role;
  final String telegramHandle;
  final String assetPath;
  final String? svgAssetPath;
  final IconData fallbackIcon;
  final VoidCallback onOpenTelegram;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget avatar = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.6 : 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.4),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: svgAssetPath != null
          ? SvgPicture.asset(
              svgAssetPath!,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
              placeholderBuilder: (_) => Image.asset(
                assetPath,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Center(
                  child: Icon(fallbackIcon, size: 26, color: scheme.primary),
                ),
              ),
            )
          : Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Center(
                child: Icon(fallbackIcon, size: 26, color: scheme.primary),
              ),
            ),
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.35),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          avatar,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.2,
                          color: scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@$telegramHandle',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    role,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Написать @$telegramHandle в Telegram',
            child: IconButton.filledTonal(
              onPressed: () {
                HapticService.tap();
                onOpenTelegram();
              },
              icon: SvgPicture.asset(
                'assets/svg/telegram_logo.svg',
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(
                  scheme.primary,
                  BlendMode.srcIn,
                ),
              ),
              style: IconButton.styleFrom(
                backgroundColor: scheme.primaryContainer.withValues(alpha: isDark ? 0.45 : 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: () {
          HapticService.tap();
          onTap();
        },
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.7 : 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(
          title,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: scheme.onSurface,
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
  });

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.7 : 0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.help_outline_rounded, color: scheme.primary, size: 18),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.7 : 0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.history_rounded, color: release.accentColor, size: 18),
      ),
      title: Text(
        release.version,
        style: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      subtitle: Text(
        release.date,
        style: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(58, 0, 18, 14),
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
