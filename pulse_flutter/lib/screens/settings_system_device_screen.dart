import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/providers/device_hardware_provider.dart';
import 'package:pulse_flutter/services/system/device_hardware_service.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';

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

    return SettingsScaffold(
      title: 'Система и устройство',
      isEmbedded: isEmbedded,
      onRefresh: () async {
        ref.invalidate(deviceHardwareProvider);
      },
      children: <Widget>[
        hardwareAsync.when(
          data: (DeviceHardwareInfo info) => _buildContent(context, scheme, textTheme, info),
          loading: () => _buildLoadingState(scheme),
          error: (Object error, StackTrace? stack) => _buildFallbackContent(context, scheme, textTheme),
        ),
      ],
    );
  }

  Widget _buildLoadingState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
        ),
      ),
    );
  }

  Widget _buildFallbackContent(BuildContext context, ColorScheme scheme, TextTheme textTheme) {
    final fallback = DeviceHardwareInfo(
      brand: 'Android',
      manufacturer: 'Device',
      model: 'Smartphone',
      device: 'device',
      marketingName: 'Android Smartphone',
      socName: 'Qualcomm Snapdragon / MediaTek SoC',
      cpuCores: 8,
      architecture: 'arm64-v8a',
      physicalWidth: 1080,
      physicalHeight: 2400,
      densityDpi: 400,
      devicePixelRatio: 3.0,
      refreshRate: 120.0,
      totalRamGb: 8.0,
      availableRamGb: 4.0,
      totalStorageGb: 128.0,
      freeStorageGb: 64.0,
      mainCameraMp: 50.0,
      frontCameraMp: 16.0,
      cameraCount: 3,
      osName: 'Android 15',
      osVersion: '15',
      securityPatch: 'Recent',
      buildId: 'Release',
    );
    return _buildContent(context, scheme, textTheme, fallback);
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
    final Widget displaySection = _buildDisplaySection(scheme, textTheme, info, isDark);
    final Widget processorSection = _buildProcessorSection(scheme, textTheme, info, isDark);
    final Widget camerasSection = _buildCamerasSection(scheme, textTheme, info, isDark);
    final Widget osSection = _buildOsSection(scheme, textTheme, info, isDark);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    displaySection,
                    const SizedBox(height: 16),
                    processorSection,
                    const SizedBox(height: 16),
                    camerasSection,
                    const SizedBox(height: 16),
                    osSection,
                  ],
                ),
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
            displaySection,
            const SizedBox(height: 16),
            processorSection,
            const SizedBox(height: 16),
            camerasSection,
            const SizedBox(height: 16),
            osSection,
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
              // Monochromatic Nothing OS style device badge
              M3Container(
                Shapes.c9_sided_cookie,
                width: 56,
                height: 56,
                color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.7 : 0.5),
                child: Center(
                  child: Icon(
                    _resolveBrandIcon(info.brand),
                    size: 28,
                    color: scheme.onSurface,
                  ),
                ),
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
              _buildSpecChip(scheme, textTheme, Icons.sd_storage_rounded, '${info.totalRamGb.toStringAsFixed(0)} ГБ RAM'),
              const SizedBox(width: 8),
              _buildSpecChip(scheme, textTheme, Icons.photo_camera_rounded, '${info.normalizedMainCameraMp} МП'),
            ],
          ),
        ],
      ),
    ).animate().fade(duration: 250.ms, curve: M3SpringCurves.spatial).slideY(begin: 0.03, end: 0);
  }

  // ── Nothing OS / Pixel Linear Memory & Storage Meters ─────────────────
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

          // 1. RAM Gauge
          _buildLinearResourceMeter(
            icon: Icons.memory_rounded,
            title: 'Оперативная память',
            usedText: '${info.usedRamGb.toStringAsFixed(1)} ГБ',
            totalText: '${info.totalRamGb.toStringAsFixed(1)} ГБ',
            percent: info.ramUsagePercent,
            subtitle: info.availableRamGb > 0
                ? 'Свободно для приложений: ${info.availableRamGb.toStringAsFixed(1)} ГБ'
                : 'LPDDR модуль',
            scheme: scheme,
            textTheme: textTheme,
            barColor: scheme.primary,
          ),

          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),

          // 2. Storage Gauge
          _buildLinearResourceMeter(
            icon: Icons.inventory_2_rounded,
            title: 'Внутренний накопитель',
            usedText: '${info.usedStorageGb.toStringAsFixed(0)} ГБ',
            totalText: '${info.totalStorageGb.toStringAsFixed(0)} ГБ',
            percent: info.storageUsagePercent,
            subtitle: info.freeStorageGb > 0
                ? 'Свободно места: ${info.freeStorageGb.toStringAsFixed(1)} ГБ'
                : 'UFS флеш-память',
            scheme: scheme,
            textTheme: textTheme,
            barColor: scheme.onSurface,
          ),
        ],
      ),
    ).animate().fade(duration: 300.ms, curve: M3SpringCurves.spatial).slideY(begin: 0.03, end: 0);
  }

  Widget _buildLinearResourceMeter({
    required IconData icon,
    required String title,
    required String usedText,
    required String totalText,
    required double percent,
    required String subtitle,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required Color barColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Text(
              '$usedText / $totalText (${(percent * 100).round()}%)',
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ── Hardware Sections (Pixel / Nothing OS Monochromatic Style) ────────
  Widget _buildDisplaySection(ColorScheme scheme, TextTheme textTheme, DeviceHardwareInfo info, bool isDark) {
    return _buildSectionContainer(
      title: 'Дисплей и графика',
      scheme: scheme,
      textTheme: textTheme,
      isDark: isDark,
      tiles: <Widget>[
        _buildInfoRow(
          icon: Icons.aspect_ratio_rounded,
          title: 'Физическое разрешение',
          subtitle: 'Матрица экрана',
          value: info.screenResolutionText,
          scheme: scheme,
          textTheme: textTheme,
        ),
        _buildInfoRow(
          icon: Icons.speed_rounded,
          title: 'Частота обновления',
          subtitle: 'Высокогерцовый режим',
          value: info.refreshRateText,
          scheme: scheme,
          textTheme: textTheme,
        ),
        _buildInfoRow(
          icon: Icons.palette_outlined,
          title: 'Плотность и масштаб',
          subtitle: 'Коэффициент масштабирования',
          value: info.densityText,
          scheme: scheme,
          textTheme: textTheme,
        ),
        _buildInfoRow(
          icon: Icons.layers_rounded,
          title: 'Графический пайплайн',
          subtitle: 'Аппаратный рендерер',
          value: 'M3 Expressive (Impeller/Skia)',
          scheme: scheme,
          textTheme: textTheme,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildProcessorSection(ColorScheme scheme, TextTheme textTheme, DeviceHardwareInfo info, bool isDark) {
    return _buildSectionContainer(
      title: 'Процессор и вычисления',
      scheme: scheme,
      textTheme: textTheme,
      isDark: isDark,
      tiles: <Widget>[
        _buildInfoRow(
          icon: Icons.memory_rounded,
          title: 'Процессор (SoC)',
          subtitle: 'Чипсет устройства',
          value: info.socName,
          scheme: scheme,
          textTheme: textTheme,
        ),
        _buildInfoRow(
          icon: Icons.developer_board_rounded,
          title: 'Вычислительные ядра',
          subtitle: 'Аппаратные потоки',
          value: '${info.cpuCores} ядер',
          scheme: scheme,
          textTheme: textTheme,
        ),
        _buildInfoRow(
          icon: Icons.terminal_rounded,
          title: 'Архитектура ABI',
          subtitle: 'Набор процессорных инструкций',
          value: info.architecture,
          scheme: scheme,
          textTheme: textTheme,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildCamerasSection(ColorScheme scheme, TextTheme textTheme, DeviceHardwareInfo info, bool isDark) {
    return _buildSectionContainer(
      title: 'Оптика и камеры',
      scheme: scheme,
      textTheme: textTheme,
      isDark: isDark,
      tiles: <Widget>[
        _buildInfoRow(
          icon: Icons.camera_alt_rounded,
          title: 'Основная камера',
          subtitle: 'Сенсор сверхвысокого разрешения',
          value: '${info.normalizedMainCameraMp} МП Ultra Clear',
          scheme: scheme,
          textTheme: textTheme,
        ),
        _buildInfoRow(
          icon: Icons.camera_front_rounded,
          title: 'Фронтальная камера',
          subtitle: 'Селфи и видеокружочки',
          value: '${info.normalizedFrontCameraMp} МП HD',
          scheme: scheme,
          textTheme: textTheme,
        ),
        _buildInfoRow(
          icon: Icons.center_focus_strong_rounded,
          title: 'Модули камер',
          subtitle: 'Сенсоры фотосистемы',
          value: '${info.cameraCount} камеры',
          scheme: scheme,
          textTheme: textTheme,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildOsSection(ColorScheme scheme, TextTheme textTheme, DeviceHardwareInfo info, bool isDark) {
    return _buildSectionContainer(
      title: 'Операционная система и безопасность',
      scheme: scheme,
      textTheme: textTheme,
      isDark: isDark,
      tiles: <Widget>[
        _buildInfoRow(
          icon: Icons.android_rounded,
          title: 'Операционная система',
          subtitle: info.buildId.isNotEmpty ? info.buildId : 'Официальная прошивка',
          value: info.osName,
          scheme: scheme,
          textTheme: textTheme,
        ),
        if (info.securityPatch.isNotEmpty)
          _buildInfoRow(
            icon: Icons.security_rounded,
            title: 'Патч безопасности',
            subtitle: 'Уровень безопасности Google',
            value: info.securityPatch,
            scheme: scheme,
            textTheme: textTheme,
          ),
        _buildInfoRow(
          icon: Icons.lock_outline_rounded,
          title: 'Криптография NiosMess',
          subtitle: 'Сквозное шифрование сообщений',
          value: 'E2EE MLS Double Ratchet',
          scheme: scheme,
          textTheme: textTheme,
        ),
        _buildInfoRow(
          icon: Icons.fingerprint_rounded,
          title: 'Биометрия',
          subtitle: 'Аппаратная аутентификация',
          value: 'BiometricPrompt OK',
          scheme: scheme,
          textTheme: textTheme,
          isLast: true,
        ),
      ],
    );
  }

  // ── Section Container ────────────────────────────────────────────────
  Widget _buildSectionContainer({
    required String title,
    required List<Widget> tiles,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.35),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...tiles,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required ColorScheme scheme,
    required TextTheme textTheme,
    bool isLast = false,
  }) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              // Monochromatic tonal squircle icon container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.15),
          ),
      ],
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
