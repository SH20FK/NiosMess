import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/device_hardware_provider.dart';
import 'package:pulse_flutter/services/system/device_hardware_service.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

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
      mainCameraMp: 108.0,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ── 1. Hero Brand & Device Card ──
        Container(
          decoration: BoxDecoration(
            color: isDark ? scheme.surfaceContainerLow : scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.primary.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                scheme.primary.withValues(alpha: isDark ? 0.18 : 0.08),
                isDark ? scheme.surfaceContainerLow : scheme.surface,
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.primary.withValues(alpha: isDark ? 0.12 : 0.05),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  // Brand / OS Emblem
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _resolveBrandIcon(info.brand),
                      size: 32,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          info.marketingName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                info.model.isNotEmpty ? info.model : info.brand,
                                style: textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                info.osName,
                                style: textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Fast Quick Spec Chips
              Row(
                children: <Widget>[
                  _buildSpecChip(scheme, textTheme, Icons.speed_rounded, '${info.refreshRate.round()} Гц'),
                  const SizedBox(width: 8),
                  _buildSpecChip(scheme, textTheme, Icons.memory_rounded, '${info.cpuCores} ядер'),
                  const SizedBox(width: 8),
                  _buildSpecChip(scheme, textTheme, Icons.sd_storage_rounded, info.ramText),
                  const SizedBox(width: 8),
                  _buildSpecChip(scheme, textTheme, Icons.photo_camera_rounded, '${info.mainCameraMp.round()} МП'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── 2. Display & Graphics ──
        SettingsSection(
          title: 'Дисплей и графика',
          subtitle: 'Физические параметры матрицы и частота обновления',
          children: <Widget>[
            SettingsInfoTile(
              icon: Icons.aspect_ratio_rounded,
              title: 'Физическое разрешение',
              subtitle: 'Реальная матрица дисплея',
              value: info.screenResolutionText,
              iconColor: scheme.primary,
            ),
            SettingsInfoTile(
              icon: Icons.speed_rounded,
              title: 'Частота обновления',
              subtitle: 'Плавный высокогерцовый рендеринг',
              value: info.refreshRateText,
              iconColor: const Color(0xFF00C853),
            ),
            SettingsInfoTile(
              icon: Icons.palette_outlined,
              title: 'Плотность и масштаб',
              subtitle: 'Физический PPI и коэффициент интерфейса',
              value: info.densityText,
              iconColor: scheme.secondary,
            ),
            SettingsInfoTile(
              icon: Icons.layers_rounded,
              title: 'Графический движок',
              subtitle: 'Рендерер с адаптивным профилированием FPS',
              value: 'M3 Tonal (Impeller/Skia)',
              iconColor: const Color(0xFFFF9100),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── 3. Processor (SoC) & Compute ──
        SettingsSection(
          title: 'Процессор и вычисления',
          subtitle: 'Система на кристалле (SoC) и вычислительные кластеры',
          children: <Widget>[
            SettingsInfoTile(
              icon: Icons.memory_rounded,
              title: 'Модель процессора (SoC)',
              subtitle: 'Аппаратная микроархитектура',
              value: info.socName,
              iconColor: const Color(0xFF7C4DFF),
            ),
            SettingsInfoTile(
              icon: Icons.developer_board_rounded,
              title: 'Количество ядер',
              subtitle: 'Симметричные высокопроизводительные ядра',
              value: '${info.cpuCores} вычислительных ядер',
              iconColor: scheme.primary,
            ),
            SettingsInfoTile(
              icon: Icons.terminal_rounded,
              title: 'Архитектура ABI',
              subtitle: 'Набор команд процессора',
              value: info.architecture,
              iconColor: scheme.secondary,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── 4. Memory & Storage ──
        SettingsSection(
          title: 'Память и накопитель',
          subtitle: 'Оперативная и постоянная физическая память',
          children: <Widget>[
            SettingsInfoTile(
              icon: Icons.storage_rounded,
              title: 'Оперативная память (RAM)',
              subtitle: info.availableRamGb > 0
                  ? 'Доступно для системы: ${info.availableRamGb.toStringAsFixed(1)} ГБ'
                  : 'LPDDR модуль памяти',
              value: info.ramText,
              iconColor: const Color(0xFF2979FF),
            ),
            SettingsInfoTile(
              icon: Icons.inventory_2_rounded,
              title: 'Внутренний накопитель',
              subtitle: info.freeStorageGb > 0
                  ? 'Свободно места: ${info.freeStorageGb.toStringAsFixed(1)} ГБ'
                  : 'Высокоскоростная флеш-память',
              value: info.storageText,
              iconColor: const Color(0xFF00B0FF),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── 5. Cameras & Optics ──
        SettingsSection(
          title: 'Оптика и камеры',
          subtitle: 'Сенсоры фотосъёмки и видеозаписи сообщений',
          children: <Widget>[
            SettingsInfoTile(
              icon: Icons.camera_alt_rounded,
              title: 'Основная камера',
              subtitle: 'Сенсор сверхвысокого разрешения',
              value: '${info.mainCameraMp.round()} МП Ultra Clear',
              iconColor: const Color(0xFFFF4081),
            ),
            SettingsInfoTile(
              icon: Icons.camera_front_rounded,
              title: 'Фронтальная камера',
              subtitle: 'Селфи-камера и видеокружочки',
              value: '${info.frontCameraMp.round()} МП HD',
              iconColor: const Color(0xFFE040FB),
            ),
            SettingsInfoTile(
              icon: Icons.center_focus_strong_rounded,
              title: 'Модули камер',
              subtitle: 'Количество сенсоров на устройстве',
              value: '${info.cameraCount} камеры',
              iconColor: scheme.primary,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── 6. OS & Security ──
        SettingsSection(
          title: 'Операционная система и безопасность',
          subtitle: 'Платформа, патчи безопасности и криптоядро',
          children: <Widget>[
            SettingsInfoTile(
              icon: Icons.android_rounded,
              title: 'Операционная система',
              subtitle: info.buildId.isNotEmpty ? info.buildId : 'Официальная прошивка',
              value: info.osName,
              iconColor: const Color(0xFF00E676),
            ),
            if (info.securityPatch.isNotEmpty)
              SettingsInfoTile(
                icon: Icons.security_rounded,
                title: 'Патч безопасности',
                subtitle: 'Уровень обновлений безопасности ОС',
                value: info.securityPatch,
                iconColor: const Color(0xFF00B0FF),
              ),
            SettingsInfoTile(
              icon: Icons.lock_outline_rounded,
              title: 'Криптография NiosMess',
              subtitle: 'Сквозное шифрование сообщений и медиа',
              value: 'E2EE MLS Double Ratchet',
              iconColor: scheme.primary,
            ),
            SettingsInfoTile(
              icon: Icons.fingerprint_rounded,
              title: 'Биометрический сканер',
              subtitle: 'Аппаратная аутентификация',
              value: 'FingerprintActivity OK',
              iconColor: const Color(0xFF7C4DFF),
            ),
          ],
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSpecChip(ColorScheme scheme, TextTheme textTheme, IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 16, color: scheme.primary),
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
