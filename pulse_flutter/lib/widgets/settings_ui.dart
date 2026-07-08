import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';

class SettingsScaffold extends ConsumerWidget {
  const SettingsScaffold({
    required this.title,
    required this.children,
    this.onRefresh,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;
    final bool hasNavBanner = children.isNotEmpty && children.first is SettingsNavBanner;
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final bool optimize = settings.optimizeForWeakDevices;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: Material(
                  color: scheme.surface.withValues(alpha: 0.78),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              )
            : null,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.035),
                scheme.surface,
              ),
              scheme.surface,
            ],
          ),
        ),
        child: PulseScaffoldBody(
          maxWidth: 920,
          child: () {
            final Widget listView = ListView(
              padding: EdgeInsets.fromLTRB(
                AppConstants.screenHorizontalPadding,
                topPadding,
                AppConstants.screenHorizontalPadding,
                28,
              ),
              children: <Widget>[
              if (!hasNavBanner)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 4),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: scheme.onSurface,
                        ),
                  ),
                ),
              ...children.asMap().entries.map((MapEntry<int, Widget> entry) {
                final Widget child = entry.value;
                if (optimize) {
                  return child;
                }
                final int index = entry.key;
                final int delayMs = (index < 6) ? index * 45 : 0;
                return child
                    .animate()
                    .fade(
                      duration: const Duration(milliseconds: 260),
                      delay: Duration(milliseconds: delayMs),
                      curve: Curves.easeOutCubic,
                    )
                    .slideY(
                      begin: 0.05,
                      end: 0,
                      duration: const Duration(milliseconds: 260),
                      delay: Duration(milliseconds: delayMs),
                      curve: Curves.easeOutCubic,
                    );
              }),
            ],
          );
          return onRefresh != null
              ? RefreshIndicator(onRefresh: onRefresh!, child: listView)
              : listView;
          }(),
        ),
      ),
    );
  }
}

class SettingsNavBanner extends StatelessWidget {
  const SettingsNavBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color resolvedColor = iconColor ?? scheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 20, top: 8),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: resolvedColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: resolvedColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
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

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.children,
    this.title,
    this.subtitle,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title!,
                    style: textTheme.titleSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Material(
                color: scheme.surfaceContainer.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildSeparatedChildren(scheme, children),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSeparatedChildren(ColorScheme scheme, List<Widget> items) {
    if (items.isEmpty) return items;
    final List<Widget> result = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      Widget item = items[i];
      if (i == 0 && items.length == 1) {
        item = ClipRRect(borderRadius: BorderRadius.circular(28), child: item);
      } else if (i == 0) {
        item = ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: item,
        );
      } else if (i == items.length - 1) {
        item = ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          child: item,
        );
      }
      result.add(item);
      if (i < items.length - 1) {
        result.add(
          Divider(
            height: 1,
            indent: 68,
            endIndent: 16,
            color: scheme.outlineVariant.withValues(alpha: 0.16),
          ),
        );
      }
    }
    return result;
  }
}

class SettingsTile extends ConsumerWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
    this.foregroundColor,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? foregroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color resolvedIconColor = iconColor ?? foregroundColor ?? scheme.onSurfaceVariant;
    final Color resolvedTextColor = foregroundColor ?? scheme.onSurface;

    return Semantics(
      label: '$title${subtitle != null ? ', $subtitle' : ''}',
      button: true,
      child: ListTile(
        titleAlignment: ListTileTitleAlignment.threeLine,
        minVerticalPadding: 14,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: resolvedIconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: resolvedIconColor, size: 20),
        ),
        title: Text(
          title,
          style: textTheme.bodyLarge?.copyWith(
            color: resolvedTextColor,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              )
            : null,
        trailing: trailing ??
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
              size: 20,
            ),
        onTap: () {
          ref.read(appSoundProvider).playUiTick();
          if (ref.read(uiSettingsProvider).haptics) {
            HapticService.tap();
          }
          onTap();
        },
      ),
    );
  }
}

class SettingsDangerTile extends ConsumerWidget {
  const SettingsDangerTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      foregroundColor: scheme.error,
      trailing: const SizedBox.shrink(),
    );
  }
}

class SettingsSwitchTile extends ConsumerWidget {
  const SettingsSwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color resolvedIconColor = iconColor ?? scheme.onSurfaceVariant;

    return Semantics(
      label: '$title, ${value ? context.l10n.semanticsOn : context.l10n.semanticsOff}',
      toggled: true,
      child: ListTile(
        titleAlignment: ListTileTitleAlignment.center,
        minVerticalPadding: 14,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: resolvedIconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: resolvedIconColor, size: 20),
        ),
        title: Text(
          title,
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              )
            : null,
        trailing: Switch(
          value: value,
          onChanged: onChanged == null
              ? null
              : (bool next) {
                  ref.read(appSoundProvider).playUiTick();
                  if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
                  onChanged!(next);
                },
        ),
        onTap: onChanged == null ? null : () => onChanged!(!value),
      ),
    );
  }
}

class SettingsInfoTile extends ConsumerWidget {
  const SettingsInfoTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onLongPress,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onLongPress;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color resolvedIconColor = iconColor ?? scheme.onSurfaceVariant;

    return ListTile(
      titleAlignment: ListTileTitleAlignment.threeLine,
      minVerticalPadding: 14,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: resolvedIconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: resolvedIconColor, size: 20),
      ),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.3,
              ),
            )
          : null,
      trailing: value == null
          ? null
          : Text(
              value!,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
      onLongPress: onLongPress == null
          ? null
          : () {
              ref.read(appSoundProvider).playUiTick(volume: 0.65);
              if (ref.read(uiSettingsProvider).haptics) {
                HapticService.confirm();
              }
              onLongPress!();
            },
    );
  }
}

class SettingsConfirmDialog extends StatelessWidget {
  const SettingsConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.cancelLabel,
    this.destructive = false,
    super.key,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String? cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: title,
      actions: <AppDialogAction>[
        AppDialogAction(
          label: cancelLabel ?? context.l10n.dialogCancel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppDialogAction(
          label: confirmLabel,
          isPrimary: !destructive,
          destructive: destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      child: Text(body),
    );
  }
}

class SettingsSessionTile extends ConsumerWidget {
  const SettingsSessionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ip,
    required this.onRevoke,
    required this.currentLabel,
    this.isCurrent = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String ip;
  final VoidCallback onRevoke;
  final String currentLabel;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return ListTile(
      titleAlignment: ListTileTitleAlignment.threeLine,
      minVerticalPadding: 14,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isCurrent
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: isCurrent ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                currentLabel,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '$subtitle · $ip',
        style: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.3,
        ),
      ),
      trailing: IconButton(
        onPressed: onRevoke,
        icon: const Icon(Icons.logout_rounded),
        tooltip: context.l10n.settingsRevokeSession,
      ),
    );
  }
}
