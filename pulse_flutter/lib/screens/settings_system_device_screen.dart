import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/device_hardware_provider.dart';
import 'package:pulse_flutter/services/system/device_hardware_service.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class SettingsSystemDeviceScreen extends ConsumerWidget {
  const SettingsSystemDeviceScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    if (kIsWeb) {
      return SettingsAboutScreen(isEmbedded: isEmbedded);
    }

    final AsyncValue<DeviceHardwareInfo> hardwareAsync = ref.watch(deviceHardwareProvider);

    return SettingsShell(
      title: 'Система и устройство',
      isEmbedded: isEmbedded,
      onRefresh: () async {
        ref.invalidate(deviceHardwareProvider);
      },
      children: <Widget>[
        hardwareAsync.when(
          data: (DeviceHardwareInfo info) => _buildContent(context, scheme, textTheme, info),
          loading: () => _buildLoadingState(scheme),
          error: (Object error, StackTrace? stack) =>
              _buildErrorContent(context, ref, scheme, textTheme, error),
        ),
      ],
    );
  }

  Widget _buildLoadingState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: AppLoadingIndicator(
          color: scheme.primary,
        ),
      ),
    );
  }

  Widget _buildErrorContent(
    BuildContext context,
    WidgetRef ref,
    ColorScheme scheme,
    TextTheme textTheme,
    Object error,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.phonelink_erase_rounded,
                color: scheme.onErrorContainer,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Не удалось получить параметры устройства',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Системная информация недоступна или произошла ошибка чтения датчиков оборудования.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: () {
                HapticService.lightImpact();
                ref.invalidate(deviceHardwareProvider);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Повторить опрос'),
              style: FilledButton.styleFrom(
                elevation: 0,
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    DeviceHardwareInfo info,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget heroCard = _buildHeroCard(context, scheme, textTheme, info, isDark);
    final Widget memoryGaugeCard = _buildMemoryGaugeCard(context, scheme, textTheme, info, isDark);
    final Widget coreSpecsCard = _buildCoreSpecsCard(context, scheme, textTheme, info, isDark);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 840;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    heroCard,
                    const SizedBox(height: 16),
                    memoryGaugeCard,
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 6,
                child: coreSpecsCard,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            heroCard,
            const SizedBox(height: 16),
            memoryGaugeCard,
            const SizedBox(height: 16),
            coreSpecsCard,
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  // ── Pixel / Nothing OS Minimalist Hero Card ───────────────────────────
  Widget _buildHeroCard(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    DeviceHardwareInfo info,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.35),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Interactive spring-scale brand logo badge
              _InteractiveBrandBadge(
                brand: info.brand,
                scheme: scheme,
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      info.marketingName,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontSize: 20,
                        color: scheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        _buildTonalBadge(
                          text: info.brand,
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                        if (info.model.isNotEmpty && info.model != info.brand)
                          _buildTonalBadge(
                            text: info.model,
                            scheme: scheme,
                            textTheme: textTheme,
                          ),
                        _buildTonalBadge(
                          text: info.osName,
                          scheme: scheme,
                          textTheme: textTheme,
                          isAccent: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Minimal Quick Spec Metrics Pill Dock
          Row(
            children: <Widget>[
              _buildSpecChip(scheme, textTheme, Icons.speed_rounded, '${info.refreshRate.round()} Гц'),
              const SizedBox(width: 8),
              _buildSpecChip(scheme, textTheme, Icons.memory_rounded, '${info.cpuCores} ядер'),
              const SizedBox(width: 8),
              _buildSpecChip(scheme, textTheme, Icons.sd_storage_rounded, info.commercialRamText),
              const SizedBox(width: 8),
              _buildSpecChip(scheme, textTheme, Icons.photo_camera_rounded, '${info.normalizedMainCameraMp} МП'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Nothing OS / Pixel Animated Memory & Storage Meters ──────────────
  Widget _buildMemoryGaugeCard(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    DeviceHardwareInfo info,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.35),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Память и накопитель',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // 1. RAM Gauge with animated spring filling & rolling number
          _AnimatedResourceMeter(
            icon: Icons.memory_rounded,
            title: 'Оперативная память',
            usedAmount: info.usedRamGb,
            totalAmount: info.totalRamGb,
            unit: 'ГБ',
            percent: info.ramUsagePercent,
            subtitle: info.commercialRamGb > 0
                ? '${info.commercialRamGb} ГБ LPDDR • ${info.availableRamGb.toStringAsFixed(1)} ГБ доступно'
                : (info.availableRamGb > 0
                    ? 'Свободно для приложений: ${info.availableRamGb.toStringAsFixed(1)} ГБ'
                    : 'LPDDR модуль'),
            scheme: scheme,
            textTheme: textTheme,
            barColor: scheme.primary,
            isInteger: false,
          ),

          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),

          // 2. Storage Gauge with animated spring filling & rolling number
          _AnimatedResourceMeter(
            icon: Icons.inventory_2_rounded,
            title: 'Внутренний накопитель',
            usedAmount: info.usedStorageGb,
            totalAmount: info.totalStorageGb,
            unit: 'ГБ',
            percent: info.storageUsagePercent,
            subtitle: info.commercialStorageGb > 0
                ? '${info.commercialStorageText} Flash • ${info.freeStorageGb.toStringAsFixed(1)} ГБ свободно'
                : (info.freeStorageGb > 0
                    ? 'Свободно места: ${info.freeStorageGb.toStringAsFixed(1)} ГБ'
                    : 'UFS флеш-память'),
            scheme: scheme,
            textTheme: textTheme,
            barColor: scheme.onSurface,
            isInteger: true,
          ),
        ],
      ),
    );
  }

  // ── Unified Material 3 Expressive Core Specs Card ─────────────────────
  Widget _buildCoreSpecsCard(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    DeviceHardwareInfo info,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.35),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Характеристики',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: scheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Нажмите для копирования',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Processor (SoC)
          _InteractiveSpecTile(
            icon: Icons.memory_rounded,
            badgeColor: scheme.primaryContainer.withValues(alpha: isDark ? 0.4 : 0.6),
            iconColor: scheme.primary,
            title: 'Процессор',
            value: info.socName,
            subtitle: '${info.cpuCores} вычислительных ядер • ${info.architecture}',
            scheme: scheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.15)),
          const SizedBox(height: 12),

          // 2. Display
          _InteractiveSpecTile(
            icon: Icons.aspect_ratio_rounded,
            badgeColor: scheme.secondaryContainer.withValues(alpha: isDark ? 0.4 : 0.6),
            iconColor: scheme.secondary,
            title: 'Дисплей и графика',
            value: '${info.screenResolutionText} • ${info.refreshRateText}',
            subtitle: '${info.densityDpi} ppi матрица экрана',
            scheme: scheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.15)),
          const SizedBox(height: 12),

          // 3. Cameras
          _InteractiveSpecTile(
            icon: Icons.camera_alt_rounded,
            badgeColor: scheme.tertiaryContainer.withValues(alpha: isDark ? 0.4 : 0.6),
            iconColor: scheme.tertiary,
            title: 'Оптика и камеры',
            value: '${info.normalizedMainCameraMp} МП • ${info.normalizedFrontCameraMp} МП фронтальная',
            subtitle: 'Фотосистема (${info.cameraCount} модуля)',
            scheme: scheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.15)),
          const SizedBox(height: 12),

          // 4. Operating System & Security
          _InteractiveSpecTile(
            icon: Icons.android_rounded,
            badgeColor: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.7 : 0.8),
            iconColor: scheme.onSurface,
            title: 'Операционная система',
            value: info.osName,
            subtitle: info.securityPatch.isNotEmpty
                ? 'Патч безопасности Google: ${info.securityPatch}'
                : (info.buildId.isNotEmpty ? info.buildId : 'Официальная прошивка'),
            scheme: scheme,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }

  Widget _buildTonalBadge({
    required String text,
    required ColorScheme scheme,
    required TextTheme textTheme,
    bool isAccent = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAccent
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: isAccent
            ? Border.all(color: scheme.primary.withValues(alpha: 0.25))
            : null,
      ),
      child: Text(
        text,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: isAccent ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSpecChip(ColorScheme scheme, TextTheme textTheme, IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildBrandLogo(String brand, ColorScheme scheme) {
    final String lower = brand.toLowerCase();
    String? svgAsset;

    if (lower.contains('oneplus')) {
      svgAsset = 'assets/svg/brands/oneplus.svg';
    } else if (lower.contains('apple')) {
      svgAsset = 'assets/svg/brands/apple.svg';
    } else if (lower.contains('google') || lower.contains('pixel')) {
      svgAsset = 'assets/svg/brands/google.svg';
    } else if (lower.contains('samsung')) {
      svgAsset = 'assets/svg/brands/samsung.svg';
    } else if (lower.contains('xiaomi') || lower.contains('redmi') || lower.contains('mi ')) {
      svgAsset = 'assets/svg/brands/xiaomi.svg';
    } else if (lower.contains('poco')) {
      svgAsset = 'assets/svg/brands/poco.svg';
    } else if (lower.contains('nothing') || lower.contains('cmf')) {
      svgAsset = 'assets/svg/brands/nothing.svg';
    } else if (lower.contains('huawei')) {
      svgAsset = 'assets/svg/brands/huawei.svg';
    } else if (lower.contains('honor')) {
      svgAsset = 'assets/svg/brands/honor.svg';
    } else if (lower.contains('realme')) {
      svgAsset = 'assets/svg/brands/realme.svg';
    } else if (lower.contains('motorola') || lower.contains('moto')) {
      svgAsset = 'assets/svg/brands/motorola.svg';
    } else if (lower.contains('sony')) {
      svgAsset = 'assets/svg/brands/sony.svg';
    } else if (lower.contains('oppo')) {
      svgAsset = 'assets/svg/brands/oppo.svg';
    } else if (lower.contains('vivo') || lower.contains('iqoo')) {
      svgAsset = 'assets/svg/brands/vivo.svg';
    } else if (lower.contains('android')) {
      svgAsset = 'assets/svg/brands/android.svg';
    }

    if (svgAsset != null) {
      return SvgPicture.asset(
        svgAsset,
        width: 28,
        height: 28,
        colorFilter: ColorFilter.mode(scheme.onSurface, BlendMode.srcIn),
      );
    }

    return Icon(
      _resolveBrandIcon(brand),
      size: 28,
      color: scheme.onSurface,
    );
  }

  static IconData _resolveBrandIcon(String brand) {
    final lower = brand.toLowerCase();
    if (lower.contains('apple')) return Icons.apple_rounded;
    if (lower.contains('google')) return Icons.android_rounded;
    if (lower.contains('oneplus')) return Icons.offline_bolt_rounded;
    if (lower.contains('samsung')) return Icons.phone_android_rounded;
    if (lower.contains('xiaomi') || lower.contains('poco') || lower.contains('redmi')) {
      return Icons.bolt_rounded;
    }
    return Icons.smartphone_rounded;
  }
}

// ── Interactive Spring Scale Brand Badge ──────────────────────────────
class _InteractiveBrandBadge extends StatefulWidget {
  const _InteractiveBrandBadge({
    required this.brand,
    required this.scheme,
    required this.isDark,
  });

  final String brand;
  final ColorScheme scheme;
  final bool isDark;

  @override
  State<_InteractiveBrandBadge> createState() => _InteractiveBrandBadgeState();
}

class _InteractiveBrandBadgeState extends State<_InteractiveBrandBadge> {
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
        scale: _isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: M3SpringCurves.bouncy,
        child: M3Container(
          Shapes.c9_sided_cookie,
          width: 58,
          height: 58,
          color: widget.scheme.surfaceContainerHighest
              .withValues(alpha: widget.isDark ? 0.7 : 0.5),
          child: Center(
            child: SettingsSystemDeviceScreen._buildBrandLogo(
              widget.brand,
              widget.scheme,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated Resource Meter with Spring Filling & Rolling Numbers ──────
class _AnimatedResourceMeter extends StatefulWidget {
  const _AnimatedResourceMeter({
    required this.icon,
    required this.title,
    required this.usedAmount,
    required this.totalAmount,
    required this.unit,
    required this.percent,
    required this.subtitle,
    required this.scheme,
    required this.textTheme,
    required this.barColor,
    this.isInteger = false,
  });

  final IconData icon;
  final String title;
  final double usedAmount;
  final double totalAmount;
  final String unit;
  final double percent;
  final String subtitle;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final Color barColor;
  final bool isInteger;

  @override
  State<_AnimatedResourceMeter> createState() => _AnimatedResourceMeterState();
}

class _AnimatedResourceMeterState extends State<_AnimatedResourceMeter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnim = CurvedAnimation(
      parent: _controller,
      curve: M3SpringCurves.spatial,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String totalText = widget.isInteger
        ? '${widget.totalAmount.round()} ${widget.unit}'
        : '${widget.totalAmount.toStringAsFixed(1)} ${widget.unit}';

    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (BuildContext context, Widget? child) {
        final double currentProgress = _progressAnim.value * widget.percent;
        final double currentUsed = _progressAnim.value * widget.usedAmount;
        final String usedText = widget.isInteger
            ? '${currentUsed.round()} ${widget.unit}'
            : '${currentUsed.toStringAsFixed(1)} ${widget.unit}';
        final int percentText = (currentProgress * 100).round();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(widget.icon, size: 18, color: widget.scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: widget.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: widget.scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '$usedText / $totalText ($percentText%)',
                  style: widget.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: widget.scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 8,
                width: double.infinity,
                color: widget.scheme.surfaceContainerHighest,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: currentProgress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.barColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              style: widget.textTheme.labelSmall?.copyWith(
                color: widget.scheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Interactive Spec Row with Spring Bounce & Copy to Clipboard ────────
class _InteractiveSpecTile extends StatefulWidget {
  const _InteractiveSpecTile({
    required this.icon,
    required this.badgeColor,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.scheme,
    required this.textTheme,
  });

  final IconData icon;
  final Color badgeColor;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  State<_InteractiveSpecTile> createState() => _InteractiveSpecTileState();
}

class _InteractiveSpecTileState extends State<_InteractiveSpecTile> {
  bool _isPressed = false;

  void _onTap() {
    HapticService.tap();
    Clipboard.setData(ClipboardData(text: '${widget.title}: ${widget.value}'));
    AppToast.showSuccess(context, 'Скопировано: ${widget.value}');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: M3SpringCurves.bouncy,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: <Widget>[
              M3Container(
                Shapes.c9_sided_cookie,
                width: 44,
                height: 44,
                color: widget.badgeColor,
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: 22,
                    color: widget.iconColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.title,
                      style: widget.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: widget.scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.value,
                      style: widget.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: widget.scheme.onSurface,
                        letterSpacing: -0.2,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: widget.textTheme.labelSmall?.copyWith(
                        color: widget.scheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.copy_rounded,
                size: 16,
                color: widget.scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
