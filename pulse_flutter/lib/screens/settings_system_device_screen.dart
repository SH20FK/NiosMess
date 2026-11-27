import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/device_hardware_provider.dart';
import 'package:pulse_flutter/screens/settings_about_screen.dart';
import 'package:pulse_flutter/services/system/device_hardware_service.dart';
import 'package:pulse_flutter/widgets/settings/settings_async_switcher.dart';
import 'package:pulse_flutter/widgets/settings/system_resource_meter.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

/// Reading hardware is owned by the provider; scrolling never starts a probe.
class SettingsSystemDeviceScreen extends ConsumerWidget {
  const SettingsSystemDeviceScreen({this.isEmbedded = false, super.key});
  final bool isEmbedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return SettingsAboutScreen(isEmbedded: isEmbedded);
    final hardware = ref.watch(deviceHardwareProvider);
    return SettingsShell(
      title: context.l10n.settingsDeviceTitle,
      isEmbedded: isEmbedded,
      onRefresh: () async {
        ref.invalidate(deviceHardwareProvider);
        await ref.read(deviceHardwareProvider.future);
      },
      children: <Widget>[
        SettingsAsyncSwitcher(
          value: hardware,
          data: (info) => _DeviceDetails(info: info),
          // Rows in the shape of the ones that are coming: the page does not
          // open with a spinner and then rebuild itself around the values.
          loading: () => const SettingsSection(
            children: <Widget>[SettingsSkeleton(rows: 4)],
          ),
          error: (_, _) => SettingsErrorSection(
            title: context.l10n.settingsDeviceError,
            message: context.l10n.settingsDeviceErrorHint,
            onRetry: () => ref.invalidate(deviceHardwareProvider),
          ),
        ),
      ],
    );
  }
}

class _DeviceDetails extends StatelessWidget {
  const _DeviceDetails({required this.info});
  final DeviceHardwareInfo info;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final gb = l.settingsDeviceGb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DeviceHero(info: info),
        SettingsSection(
          title: l.settingsDeviceMemory,
          accentIcon: Icons.memory_rounded,
          children: <Widget>[
            SystemResourceMeter(
              icon: Icons.memory_rounded,
              title: l.settingsDeviceRam,
              used: info.ramAvailabilityKnown ? info.usedRamGb : null,
              total: info.totalRamGb,
              unit: gb,
              unavailableLabel: l.settingsDeviceUnknown,
              subtitle: info.totalRamGb > 0 && info.ramAvailabilityKnown
                  ? '${l.settingsDeviceAvailable}: ${info.availableRamGb.toStringAsFixed(1)} $gb'
                  : l.settingsDeviceUnknown,
            ),
            SystemResourceMeter(
              icon: Icons.storage_rounded,
              title: l.settingsDeviceStorage,
              used: info.storageAvailabilityKnown ? info.usedStorageGb : null,
              total: info.totalStorageGb,
              unit: gb,
              unavailableLabel: l.settingsDeviceUnknown,
              subtitle: info.totalStorageGb > 0 && info.storageAvailabilityKnown
                  ? '${l.settingsDeviceAvailable}: ${info.freeStorageGb.toStringAsFixed(1)} $gb'
                  : l.settingsDeviceUnknown,
            ),
          ],
        ),
        SettingsSection(
          title: l.settingsDeviceSpecs,
          subtitle: l.settingsDeviceCopyHint,
          accentIcon: Icons.tune_rounded,
          children: <Widget>[
            _CopyableSpec(
              icon: Icons.memory_rounded,
              title: l.settingsDeviceProcessor,
              value: info.socName.isEmpty
                  ? l.settingsDeviceUnknown
                  : info.socName,
              subtitle: [
                if (info.cpuCores > 0)
                  '${info.cpuCores} ${l.settingsDeviceCores}',
                if (info.architecture.isNotEmpty) info.architecture,
              ].join(' · '),
            ),
            _CopyableSpec(
              icon: Icons.aspect_ratio_rounded,
              title: l.settingsDeviceDisplay,
              value: [
                if (info.physicalWidth > 0 && info.physicalHeight > 0)
                  info.screenResolutionText,
                if (info.refreshRate > 0)
                  '${info.refreshRate.round()} ${l.settingsDeviceHz}',
              ].join(' · '),
              subtitle: info.densityDpi > 0 ? info.densityText : null,
            ),
            _CopyableSpec(
              icon: Icons.camera_alt_outlined,
              title: l.settingsDeviceCameras,
              value: info.mainCameraMp > 0
                  ? '${info.normalizedMainCameraMp} ${l.settingsDeviceMp}'
                  : l.settingsDeviceUnknown,
              subtitle: info.frontCameraMp > 0
                  ? '${info.normalizedFrontCameraMp} ${l.settingsDeviceMp} ${l.settingsDeviceFrontCamera}'
                  : null,
            ),
            _CopyableSpec(
              icon: Icons.android_rounded,
              title: l.settingsDeviceOs,
              value: info.osName,
              subtitle: info.osVersion != info.osName ? info.osVersion : null,
            ),
            if (info.securityPatch.isNotEmpty)
              _CopyableSpec(
                icon: Icons.security_rounded,
                title: l.settingsDeviceSecurityPatch,
                value: info.securityPatch,
              ),
            if (info.model.isNotEmpty)
              _CopyableSpec(
                icon: Icons.smartphone_rounded,
                title: l.settingsDeviceModel,
                value: info.model,
              ),
            if (info.buildId.isNotEmpty)
              _CopyableSpec(
                icon: Icons.code_rounded,
                title: l.settingsDeviceBuild,
                value: info.buildId,
              ),
          ],
        ),
      ],
    );
  }
}

/// The opening panel: the model in display type with the operating system
/// under it, and the brand mark on the tonal step of the same card.
class _DeviceHero extends StatelessWidget {
  const _DeviceHero({required this.info});
  final DeviceHardwareInfo info;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String fingerprint = <String>[
      info.brand,
      info.osName,
    ].where((String value) => value.trim().isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: SettingsHeroCard(
        label: context.l10n.settingsDeviceModel,
        leadingIcon: Icons.smartphone_rounded,
        trailing: _DeviceBrandBadge(brand: info.brand),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              info.marketingName,
              // Two lines: at 180 % text a marketing name wraps rather than
              // pushing the panel past the pane.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.headlineMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            if (fingerprint.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                fingerprint,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The brand mark on the tonal step of the hero: a 40 dp squircle in
/// [ColorScheme.secondaryContainer], the pair the glyph already inks against.
class _DeviceBrandBadge extends StatelessWidget {
  const _DeviceBrandBadge({required this.brand});
  final String brand;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.secondaryContainer,
        shape: AppRadii.superellipse(AppRadii.of(context).md),
      ),
      child: SizedBox.square(
        dimension: AppHeights.sm,
        child: Center(child: _DeviceBrand(brand: brand)),
      ),
    );
  }
}

class _CopyableSpec extends StatelessWidget {
  const _CopyableSpec({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => SettingsListItem(
    icon: icon,
    title: title,
    value: value.isEmpty ? context.l10n.settingsDeviceUnknown : value,
    subtitle: subtitle,
    type: SettingsListItemType.value,
    trailing: Icon(
      Icons.copy_rounded,
      size: 18,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    onTap: () async {
      await Clipboard.setData(ClipboardData(text: '$title: $value'));
      if (context.mounted) {
        AppToast.showSuccess(context, context.l10n.noticeCopied);
      }
    },
  );
}

class _DeviceBrand extends StatelessWidget {
  const _DeviceBrand({required this.brand});
  final String brand;

  @override
  Widget build(BuildContext context) {
    final lower = brand.toLowerCase();
    final String? asset = switch (lower) {
      _ when lower.contains('oneplus') => 'oneplus',
      _ when lower.contains('apple') => 'apple',
      _ when lower.contains('google') || lower.contains('pixel') => 'google',
      _ when lower.contains('samsung') => 'samsung',
      _ when lower.contains('poco') => 'poco',
      _ when lower.contains('xiaomi') || lower.contains('redmi') => 'xiaomi',
      _ when lower.contains('nothing') || lower.contains('cmf') => 'nothing',
      _ when lower.contains('huawei') => 'huawei',
      _ when lower.contains('honor') => 'honor',
      _ when lower.contains('realme') => 'realme',
      _ when lower.contains('motorola') || lower.contains('moto') => 'motorola',
      _ when lower.contains('sony') => 'sony',
      _ when lower.contains('oppo') => 'oppo',
      _ when lower.contains('vivo') || lower.contains('iqoo') => 'vivo',
      _ when lower.contains('android') => 'android',
      _ => null,
    };
    final color = Theme.of(context).colorScheme.onSecondaryContainer;
    return asset == null
        ? Icon(Icons.devices_rounded, size: 20, color: color)
        : SvgPicture.asset(
            'assets/svg/brands/$asset.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          );
  }
}
