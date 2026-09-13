import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
import 'package:pulse_flutter/widgets/vector_illustrations.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

export 'package:pulse_flutter/widgets/vector_illustrations.dart';

class SettingsScaffold extends ConsumerWidget {
  const SettingsScaffold({
    this.title,
    required this.children,
    this.onRefresh,
    this.isEmbedded = false,
    this.maxWidth = 860,
    this.adaptiveColumns = false,
    super.key,
  });

  final String? title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final bool isEmbedded;
  final double maxWidth;
  final bool adaptiveColumns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double topPadding = isEmbedded
        ? 24.0
        : (MediaQuery.paddingOf(context).top + kToolbarHeight + 8.0);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 840;
        final double horizontalPadding = isEmbedded
            ? (isWide ? 36.0 : 20.0)
            : (isWide ? 36.0 : AppConstants.screenHorizontalPadding);

        final bool hasNavBanner =
            children.isNotEmpty && children.first is SettingsNavBanner;

        Widget? header;
        List<Widget> contentChildren;

        if (hasNavBanner) {
          header = children.first;
          contentChildren = children.sublist(1);
        } else {
          header = null;
          contentChildren = children;
        }

        final bool canSplit = isWide &&
            adaptiveColumns &&
            contentChildren.length >= 2 &&
            !contentChildren.any((Widget w) => w is Row);

        final List<Widget> listItems = <Widget>[];

        if (!hasNavBanner && title != null) {
          listItems.add(
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
          );
        }

        if (header != null) {
          listItems.add(header);
          listItems.add(const SizedBox(height: 16));
        }

        if (canSplit) {
          final int half = (contentChildren.length + 1) ~/ 2;
          final List<Widget> leftCol = contentChildren.sublist(0, half);
          final List<Widget> rightCol = contentChildren.sublist(half);

          listItems.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: leftCol,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: rightCol,
                  ),
                ),
              ],
            ),
          );
        } else {
          listItems.addAll(contentChildren);
        }

        final Widget rawScrollView = CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topPadding,
                horizontalPadding,
                32,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed(listItems),
              ),
            ),
          ],
        );

        final Widget bodyContent = onRefresh != null
            ? RefreshIndicator(onRefresh: onRefresh!, child: rawScrollView)
            : rawScrollView;

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
                      color: scheme.surface.withValues(alpha: 0.85),
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.of(context).pop();
                          } else {
                            try {
                              context.go('/main/profile');
                            } catch (_) {}
                          }
                        },
                      ),
                    ),
                  )
                : null,
          ),
          body: PulseScaffoldBody(
            animatedBackdrop: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: bodyContent,
              ),
            ),
          ),
        );
      },
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
                padding: EdgeInsets.fromLTRB(isCard ? 12 : 8, isCard ? 8 : 0, 4, isCard ? 8 : 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 3.5,
                      height: 14,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title!,
                            style: isCard
                                ? textTheme.labelLarge?.copyWith(
                                    color: scheme.onSurfaceVariant.withValues(alpha: 0.90),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                  )
                                : textTheme.labelSmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                          ),
                          if (subtitle != null) ...<Widget>[
                            const SizedBox(height: 2),
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
                    color: scheme.surfaceContainer,
                    borderRadius: AppRadii.mdRadius,
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.20),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadii.mdRadius,
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
        if (items[i] is! Divider && items[i + 1] is! Divider) {
          result.add(
            Divider(
              height: 1,
              indent: 58,
              endIndent: 16,
              color: scheme.outlineVariant.withValues(alpha: 0.10),
            ),
          );
        }
      }
    }
    return result;
  }
}

class SettingsTile extends ConsumerStatefulWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
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
  final String? value;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? foregroundColor;
  final Color? iconColor;
  final bool enabled;
  final bool isSelected;

  @override
  ConsumerState<SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends ConsumerState<SettingsTile> {
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color resolvedIconColor = widget.isSelected
        ? scheme.onSecondaryContainer
        : (widget.iconColor ?? widget.foregroundColor ?? scheme.primary);
    final Color resolvedTextColor = widget.isSelected
        ? scheme.onSecondaryContainer
        : (widget.foregroundColor ?? scheme.onSurface);
    final Color iconBgColor = widget.isSelected
        ? scheme.primary.withValues(alpha: 0.18)
        : (widget.iconColor ?? scheme.primary).withValues(alpha: 0.12);

    return RepaintBoundary(
      child: Semantics(
        label: '${widget.title}${widget.subtitle != null ? ', ${widget.subtitle}' : ''}',
        button: true,
        enabled: widget.enabled,
        selected: widget.isSelected,
        child: TouchContainer(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.enabled
              ? () {
                  ref.read(appSoundProvider).playUiTick();
                  if (ref.read(uiSettingsProvider).haptics) {
                    HapticService.tap();
                  }
                  widget.onTap();
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? scheme.secondaryContainer.withValues(alpha: 0.8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: <Widget>[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(widget.icon, color: resolvedIconColor, size: 20),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            widget.title,
                            style: textTheme.bodyMedium?.copyWith(
                              color: widget.enabled
                                  ? resolvedTextColor
                                  : resolvedTextColor.withValues(alpha: 0.38),
                              fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 14,
                              height: 1.15,
                            ),
                          ),
                          if (widget.subtitle != null) ...<Widget>[
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle!,
                              style: textTheme.bodySmall?.copyWith(
                                color: widget.isSelected
                                    ? scheme.onSecondaryContainer.withValues(alpha: 0.85)
                                    : scheme.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    widget.trailing ??
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (widget.value != null && widget.value!.isNotEmpty) ...<Widget>[
                              Text(
                                widget.value!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: widget.isSelected
                                      ? scheme.onSecondaryContainer.withValues(alpha: 0.85)
                                      : scheme.onSurfaceVariant.withValues(alpha: 0.75),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Icon(
                              Icons.chevron_right_rounded,
                              color: widget.isSelected
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant.withValues(alpha: 0.38),
                              size: 18,
                            ),
                          ],
                        ),
                  ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsSwitchTile extends ConsumerStatefulWidget {
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
  ConsumerState<SettingsSwitchTile> createState() => _SettingsSwitchTileState();
}

class _SettingsSwitchTileState extends ConsumerState<SettingsSwitchTile> {
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color resolvedIconColor = widget.iconColor ?? scheme.onSurfaceVariant;

    return RepaintBoundary(
      child: Semantics(
        label:
            '${widget.title}, ${widget.value ? context.l10n.semanticsOn : context.l10n.semanticsOff}',
        toggled: true,
        child: TouchContainer(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onChanged == null
              ? null
              : () {
                  ref.read(appSoundProvider).playUiTick();
                  if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
                  widget.onChanged!(!widget.value);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: resolvedIconColor.withValues(alpha: widget.value ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Icon(widget.icon, color: resolvedIconColor, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      if (widget.subtitle != null) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: widget.value,
                  thumbIcon: WidgetStateProperty.resolveWith<Icon?>((Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return Icon(Icons.check_rounded, size: 14, color: scheme.primary);
                    }
                    return null;
                  }),
                  onChanged: widget.onChanged == null
                      ? null
                      : (bool next) {
                          ref.read(appSoundProvider).playUiTick();
                          if (ref.read(uiSettingsProvider).haptics) HapticService.tap();
                          widget.onChanged!(next);
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsInfoTile extends ConsumerStatefulWidget {
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
  ConsumerState<SettingsInfoTile> createState() => _SettingsInfoTileState();
}

class _SettingsInfoTileState extends ConsumerState<SettingsInfoTile> {
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color resolvedIconColor = widget.iconColor ?? scheme.onSurfaceVariant;

    return RepaintBoundary(
      child: Semantics(
        label:
            '${widget.title}${widget.value != null ? ', ${widget.value}' : ''}${widget.subtitle != null ? ', ${widget.subtitle}' : ''}',
        readOnly: true,
        child: TouchContainer(
          borderRadius: BorderRadius.circular(16),
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  ref.read(appSoundProvider).playUiTick(volume: 0.65);
                  if (ref.read(uiSettingsProvider).haptics) {
                    HapticService.confirm();
                  }
                  widget.onLongPress!();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: resolvedIconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Icon(widget.icon, color: resolvedIconColor, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: widget.value != null ? 3 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      if (widget.subtitle != null) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.value != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: Text(
                      widget.value!,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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


