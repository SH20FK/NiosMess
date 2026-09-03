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
import 'package:pulse_flutter/widgets/vector_illustrations.dart';

export 'package:pulse_flutter/widgets/vector_illustrations.dart';

class SettingsScaffold extends ConsumerWidget {
  const SettingsScaffold({
    this.title,
    required this.children,
    this.onRefresh,
    this.isEmbedded = false,
    this.maxWidth = 720,
    super.key,
  });

  final String? title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final bool isEmbedded;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double topPadding = isEmbedded
        ? 24.0
        : (MediaQuery.paddingOf(context).top + kToolbarHeight + 8.0);
    final double horizontalPadding =
        isEmbedded ? 24.0 : AppConstants.screenHorizontalPadding;
    final bool hasNavBanner =
        children.isNotEmpty && children.first is SettingsNavBanner;
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final bool optimize = settings.optimizeForWeakDevices;

    final Widget listView = ListView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        32,
      ),
      children: <Widget>[
        if (!hasNavBanner && title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 4),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: scheme.onSurface,
                  ),
            ),
          ),
        ...children.asMap().entries.map((MapEntry<int, Widget> entry) {
          final Widget child = entry.value;
          if (optimize || isEmbedded) {
            return child;
          }
          final int index = entry.key;
          final int delayMs = (index < 6) ? index * 45 : 0;
          return child
              .animate()
              .fade(
                duration: const Duration(milliseconds: 260),
                delay: Duration(milliseconds: delayMs),
                curve: Curves.easeOut,
              )
              .slideY(
                begin: 0.04,
                end: 0,
                duration: const Duration(milliseconds: 260),
                delay: Duration(milliseconds: delayMs),
                curve: Curves.easeOutCubic,
              );
        }),
      ],
    );

    final Widget bodyContent = onRefresh != null
        ? RefreshIndicator(onRefresh: onRefresh!, child: listView)
        : listView;

    if (isEmbedded) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: bodyContent,
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
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
      body: PulseScaffoldBody(
        child: bodyContent,
      ),
    );
  }
}

class SettingsNavBanner extends StatelessWidget {
  const SettingsNavBanner({
    required this.title,
    required this.subtitle,
    this.icon,
    this.illustrationCategory,
    this.iconColor,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final SettingsIllustrationCategory? illustrationCategory;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color resolvedColor = iconColor ?? scheme.primary;

    final Widget leadingWidget = illustrationCategory != null
        ? SettingsHeaderIllustration(
            category: illustrationCategory!,
            size: 48,
            accentColor: iconColor,
          )
        : Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: resolvedColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(icon ?? Icons.settings_outlined, color: resolvedColor, size: 24),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          leadingWidget,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: textTheme.headlineSmall?.copyWith(
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
    this.isCard = true,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final bool isCard;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: isCard ? 18 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null)
            Semantics(
              header: true,
              label: title,
              child: Padding(
                padding: EdgeInsets.fromLTRB(isCard ? 4 : 8, 0, 4, isCard ? 10 : 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isCard ? title! : title!.toUpperCase(),
                      style: isCard
                          ? textTheme.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                            )
                          : textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
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
            ),
          if (isCard)
            Builder(
              builder: (BuildContext ctx) {
                final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? scheme.surfaceContainerLow : scheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.40),
                      width: 1,
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _buildSeparatedChildren(scheme, children),
                      ),
                    ),
                  ),
                );
              },
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSeparatedChildren(ColorScheme scheme, List<Widget> items) {
    if (items.isEmpty) return items;
    final List<Widget> result = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(
          Divider(
            height: 1,
            indent: 68,
            endIndent: 16,
            color: scheme.outlineVariant.withValues(alpha: 0.15),
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
    this.enabled = true,
    this.isSelected = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? foregroundColor;
  final Color? iconColor;
  final bool enabled;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color resolvedIconColor = isSelected
        ? scheme.onSecondaryContainer
        : (iconColor ?? foregroundColor ?? scheme.onSurfaceVariant);
    final Color resolvedTextColor = isSelected
        ? scheme.onSecondaryContainer
        : (foregroundColor ?? scheme.onSurface);
    final Color iconBgColor = isSelected
        ? scheme.primary.withValues(alpha: 0.18)
        : (iconColor ?? foregroundColor ?? scheme.onSurfaceVariant)
            .withValues(alpha: 0.12);

    return Semantics(
      label: '$title${subtitle != null ? ', $subtitle' : ''}',
      button: true,
      enabled: enabled,
      selected: isSelected,
      child: Material(
        color: isSelected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          dense: true,
          minVerticalPadding: subtitle != null ? 12 : 6,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: subtitle != null ? 3 : 1,
          ),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: resolvedIconColor, size: 20),
          ),
          title: Text(
            title,
            style: textTheme.bodyMedium?.copyWith(
              color: enabled
                  ? resolvedTextColor
                  : resolvedTextColor.withValues(alpha: 0.38),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14,
              height: 1.15,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? scheme.onSecondaryContainer.withValues(alpha: 0.8)
                        : scheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                )
              : null,
          trailing: trailing ??
              Icon(
                Icons.chevron_right_rounded,
                color: isSelected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                size: 18,
              ),
          onTap: enabled
              ? () {
                  ref.read(appSoundProvider).playUiTick();
                  if (ref.read(uiSettingsProvider).haptics) {
                    HapticService.tap();
                  }
                  onTap();
                }
              : null,
        ),
      ),
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
      label:
          '$title, ${value ? context.l10n.semanticsOn : context.l10n.semanticsOff}',
      toggled: true,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          titleAlignment: ListTileTitleAlignment.center,
          minVerticalPadding: 14,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: resolvedIconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
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
          trailing: Switch.adaptive(
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

    return Semantics(
      label:
          '$title${value != null ? ', $value' : ''}${subtitle != null ? ', $subtitle' : ''}',
      readOnly: true,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          titleAlignment: ListTileTitleAlignment.threeLine,
          minVerticalPadding: 14,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: resolvedIconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
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
        ),
      ),
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


