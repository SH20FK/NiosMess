import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';

class SettingsScaffold extends ConsumerWidget {
  const SettingsScaffold({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;
    final bool hasNavBanner = children.isNotEmpty && children.first is SettingsNavBanner;
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final bool optimize = settings.optimizeForWeakDevices;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: Material(
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.72),
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
      body: PulseScaffoldBody(
        maxWidth: 920,
        child: ListView(
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
        ),
      ),
    );
  }
}

/// Маленький заголовок-описание страницы настроек.
/// Заменяет громоздкий SettingsHeroCard.
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: resolvedColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
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
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.3,
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title!,
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildSeparatedChildren(scheme, children),
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
      // Clip first and last items to match card corners
      Widget item = items[i];
      if (i == 0 && items.length == 1) {
        item = ClipRRect(borderRadius: BorderRadius.circular(20), child: item);
      } else if (i == 0) {
        item = ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: item,
        );
      } else if (i == items.length - 1) {
        item = ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          child: item,
        );
      }
      result.add(item);
      if (i < items.length - 1) {
        result.add(
          Divider(
            height: 1,
            indent: 56,
            endIndent: 0,
            color: scheme.outlineVariant.withValues(alpha: 0.18),
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
  /// Цвет иконки и её фона (отдельный от foregroundColor для текста).
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color resolvedIconColor = iconColor ?? foregroundColor ?? scheme.onSurfaceVariant;
    final Color resolvedTextColor = foregroundColor ?? scheme.onSurface;

    return ListTile(
      minVerticalPadding: 12,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: resolvedIconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: resolvedIconColor, size: 20),
      ),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(
          color: resolvedTextColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
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
          HapticFeedback.selectionClick();
        }
        onTap();
      },
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
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final Color resolvedIconColor = iconColor ?? scheme.onSurfaceVariant;

    return ListTile(
      minVerticalPadding: 12,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: resolvedIconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: resolvedIconColor, size: 20),
      ),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            )
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged == null
            ? null
            : (bool next) {
                ref.read(appSoundProvider).playUiTick();
                if (settings.haptics) HapticFeedback.selectionClick();
                onChanged!(next);
              },
      ),
      onTap: onChanged == null ? null : () => onChanged!(!value),
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
      minVerticalPadding: 12,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: resolvedIconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: resolvedIconColor, size: 20),
      ),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
                HapticFeedback.mediumImpact();
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
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    super.key,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
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
      minVerticalPadding: 12,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isCurrent
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
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
              ),
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 3),
          Text(subtitle),
          const SizedBox(height: 1),
          Text(
            ip,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      trailing: isCurrent
          ? null
          : IconButton(
              icon: Icon(Icons.logout_rounded, color: scheme.error),
              onPressed: onRevoke,
            ),
    );
  }
}
