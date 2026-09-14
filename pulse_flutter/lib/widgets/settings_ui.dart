import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
import 'package:pulse_flutter/widgets/vector_illustrations.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/settings/settings_list_item.dart';

export 'package:pulse_flutter/widgets/vector_illustrations.dart';
export 'package:pulse_flutter/widgets/settings/pressable_surface.dart';
export 'package:pulse_flutter/widgets/settings/settings_list_item.dart';
export 'package:pulse_flutter/widgets/settings/settings_shell.dart';

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
    this.title,
    required this.subtitle,
    this.icon,
    this.illustrationCategory,
    this.iconColor,
    super.key,
  });

  final String? title;
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

    final bool hasTitle = title != null && title!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 16),
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
                if (hasTitle) ...[
                  Text(
                    title!,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
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
                final BorderRadius dynamicRadius = AppRadii.of(ctx).lgRadius;
                return Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: dynamicRadius,
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.20),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: dynamicRadius,
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
              indent: SettingsListItem.dividerIndent,
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

class SettingsTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsListItem.nav(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      onTap: onTap,
      trailing: trailing,
      iconColor: iconColor ?? foregroundColor,
      enabled: enabled,
      isSelected: isSelected,
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
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? iconColor;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsListItem.toggle(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
      iconColor: iconColor,
      enabled: enabled,
    );
  }
}

class SettingsInfoTile extends ConsumerWidget {
  const SettingsInfoTile({
    required this.icon,
    required this.title,
    this.value,
    this.subtitle,
    this.onTap,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsListItem.value(
      icon: icon,
      title: title,
      value: value,
      subtitle: subtitle,
      onTap: onTap,
      iconColor: iconColor,
    );
  }
}


