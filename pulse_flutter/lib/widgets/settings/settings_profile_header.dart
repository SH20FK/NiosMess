import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// One avatar follows the scroll position into the pinned toolbar. There is no
/// scroll listener rebuilding the settings form, timer or duplicate image load.
class SettingsProfileHeader extends StatelessWidget {
  const SettingsProfileHeader({
    required this.displayName,
    required this.username,
    required this.onEdit,
    required this.onAvatar,
    required this.onQr,
    this.avatarUrl,
    this.busy = false,
    super.key,
  });

  final String displayName;
  final String username;
  final String? avatarUrl;
  final VoidCallback onEdit;
  final VoidCallback onAvatar;
  final VoidCallback onQr;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // A layout builder also receives scroll offsets. Cache the text measurement
    // by width within this build; inherited theme/text changes create a new cache.
    final extentByWidth = <double, double>{};
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final text = Theme.of(context).textTheme;
        double height(
          String value,
          TextStyle? style,
          int? lines, {
          double? width,
        }) {
          final painter = TextPainter(
            text: TextSpan(text: value, style: style),
            maxLines: lines,
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout(maxWidth: width ?? constraints.crossAxisExtent - 40);
          final result = painter.height;
          painter.dispose();
          return result;
        }

        final details = extentByWidth.putIfAbsent(
          constraints.crossAxisExtent,
          () =>
              height(
                displayName,
                text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                2,
              ) +
              (username.isEmpty
                  ? 0
                  : 4 + height('@$username', text.bodyMedium, 1)) +
              10 +
              (height(
                        context.l10n.profileEdit,
                        text.labelLarge,
                        null,
                        width: constraints.crossAxisExtent - 92,
                      ) +
                      20)
                  .clamp(48, double.infinity),
        );
        return SliverPersistentHeader(
          pinned: true,
          delegate: _ProfileHeaderDelegate(
            displayName: displayName,
            username: username,
            avatarUrl: avatarUrl,
            onEdit: onEdit,
            onAvatar: onAvatar,
            onQr: onQr,
            busy: busy,
            top: MediaQuery.paddingOf(context).top,
            expanded: 178 + details + 20,
            collapsed: (scaler.scale(20) + 24).clamp(64, 104),
          ),
        );
      },
    );
  }
}

class _ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileHeaderDelegate({
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.onEdit,
    required this.onAvatar,
    required this.onQr,
    required this.busy,
    required this.top,
    required this.expanded,
    required this.collapsed,
  });

  final String displayName;
  final String username;
  final String? avatarUrl;
  final VoidCallback onEdit;
  final VoidCallback onAvatar;
  final VoidCallback onQr;
  final bool busy;
  final double top;
  final double expanded;
  final double collapsed;

  @override
  double get minExtent => top + collapsed;
  @override
  double get maxExtent => top + expanded;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final reduced = MediaQuery.disableAnimationsOf(context);
    // Geometry tracks the gesture directly; effects use a bounded M3 curve.
    final t = reduced ? (progress > .6 ? 1.0 : 0.0) : progress;
    final detailsOpacity =
        1 -
        M3SpringCurves.expressiveStandard.transform(
          (progress / .62).clamp(0.0, 1.0),
        );
    final titleOpacity = M3SpringCurves.expressiveStandard.transform(
      ((progress - .68) / .32).clamp(0.0, 1.0),
    );
    final size = lerpDouble(104, 36, t)!;
    final hitSize = size.clamp(48.0, 104.0);
    return Material(
      key: const ValueKey('settings-profile-header'),
      color: scheme.surface,
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final left = lerpDouble((bounds.maxWidth - 104) / 2, 20, t)!;
          final avatarTop = lerpDouble(
            top + 62,
            top + (collapsed - 36) / 2,
            t,
          )!;
          return Stack(
            children: [
              Positioned(
                left: 20,
                top: top,
                right: 64,
                height: collapsed,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    excluding: titleOpacity > .5,
                    child: Opacity(
                      opacity:
                          1 -
                          M3SpringCurves.expressiveStandard.transform(
                            ((progress - .05) / .4).clamp(0.0, 1.0),
                          ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.l10n.tabSettings,
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: top + (collapsed - 48) / 2,
                child: IconButton(
                  tooltip: context.l10n.settingsV2Qr,
                  onPressed: onQr,
                  icon: const Icon(Icons.qr_code_rounded),
                ),
              ),
              Positioned(
                left: left + (size - hitSize) / 2,
                top: avatarTop + (size - hitSize) / 2,
                width: hitSize,
                height: hitSize,
                child: Semantics(
                  button: true,
                  label: context.l10n.settingsProfileChangePhoto,
                  child: InkWell(
                    onTap: busy ? null : onAvatar,
                    customBorder: const CircleBorder(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: SizedBox.square(
                            dimension: size,
                            child: FittedBox(
                              child: RepaintBoundary(
                                child: PulseAvatar(
                                  name: displayName,
                                  avatarUrl: avatarUrl,
                                  radius: 52,
                                  fallbackColor: scheme.primaryContainer,
                                  textColor: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (busy)
                          Center(child: AppLoadingIndicator(size: size * .4)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 70,
                right: 64,
                top: top,
                height: collapsed,
                child: IgnorePointer(
                  ignoring: titleOpacity < .9,
                  child: ExcludeSemantics(
                    excluding: titleOpacity < .9,
                    child: Opacity(
                      opacity: titleOpacity,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: top + 178 - shrinkOffset * .45,
                child: IgnorePointer(
                  ignoring: detailsOpacity < .9,
                  child: ExcludeSemantics(
                    excluding: detailsOpacity < .9,
                    child: Opacity(
                      opacity: detailsOpacity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (username.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '@$username',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: text.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(context.l10n.profileEdit),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(_ProfileHeaderDelegate old) =>
      displayName != old.displayName ||
      username != old.username ||
      avatarUrl != old.avatarUrl ||
      busy != old.busy ||
      top != old.top ||
      expanded != old.expanded ||
      collapsed != old.collapsed ||
      onEdit != old.onEdit ||
      onAvatar != old.onAvatar ||
      onQr != old.onQr;
}
