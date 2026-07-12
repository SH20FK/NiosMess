import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class _ProfileHeaderFadeTransition extends StatelessWidget {
  const _ProfileHeaderFadeTransition({
    required this.opacity,
    required this.child,
  });

  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (opacity >= 1) return child;
    return Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);
  }
}

class ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  ProfileHeaderDelegate({
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.onEdit,
    required this.onUploadAvatar,
    required this.isUploadingAvatar,
  });

  final String name;
  final String username;
  final String? avatarUrl;
  final VoidCallback onEdit;
  final VoidCallback onUploadAvatar;
  final bool isUploadingAvatar;

  @override
  double get minExtent => 88;

  @override
  double get maxExtent => 320;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double topInset = MediaQuery.viewPaddingOf(context).top;
    final double progress =
        (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final double screenWidth = MediaQuery.sizeOf(context).width;

    final double fogOpacity = (1.0 - (progress / 0.7)).clamp(0.0, 1.0);
    final double expandedOpacity = ((0.7 - progress) / 0.4).clamp(0.0, 1.0);
    final double collapsedOpacity = ((progress - 0.3) / 0.4).clamp(0.0, 1.0);

    const double expandedAvatarSize = 112;
    const double collapsedAvatarSizeTarget = 40;
    final double collapsedAvatarSize = ui.lerpDouble(expandedAvatarSize, collapsedAvatarSizeTarget, progress)!;
    final double collapsedAvatarTop =
        topInset + (minExtent - topInset - collapsedAvatarSize) / 2;
    const double collapsedAvatarLeft = 16;
    final double collapsedTitleTop =
        topInset + (minExtent - topInset - 28) / 2;

    final double gearTopExpanded = topInset + 8;
    final double gearTopCollapsed =
        topInset + (minExtent - topInset) / 2 - 24;
    final double gearTop = ui.lerpDouble(gearTopExpanded, gearTopCollapsed, progress)!;
    final double gearSurfaceBlend = ((progress - 0.3) / 0.4).clamp(0.0, 1.0);
    final Color gearColor = Color.lerp(
          scheme.primaryContainer,
          scheme.surfaceContainerHigh,
          gearSurfaceBlend,
        ) ??
        scheme.surfaceContainerHigh;

    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(
          Colors.transparent,
          scheme.surface.withValues(alpha: 0.95),
          progress,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: _ProfileHeaderFadeTransition(
              opacity: fogOpacity,
              child: CustomPaint(
                painter: _ExpressiveProfileFogPainter(
                  progress: progress,
                  scheme: scheme,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: progress,
                child: Container(
                  height: 92,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        scheme.surface.withValues(alpha: 0.16),
                        scheme.surface.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: _ProfileHeaderFadeTransition(
              opacity: expandedOpacity,
              child: Padding(
                padding: EdgeInsets.only(top: topInset + 20),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      GestureDetector(
                        onTap: isUploadingAvatar ? null : onUploadAvatar,
                        child: SizedBox(
                          width: 112,
                          height: 112,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              PulseAvatar(
                                radius: 56,
                                name: name,
                                avatarUrl: avatarUrl,
                                fallbackColor: scheme.primaryContainer,
                                textColor: scheme.onPrimaryContainer,
                                borderColor: scheme.surface,
                                borderWidth: 2,
                              ),
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: scheme.surface,
                                    shape: BoxShape.circle,
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: scheme.shadow.withValues(alpha: 0.10),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                        child: isUploadingAvatar
                                          ? AppLoadingIndicator(size: 12, color: scheme.onPrimary)
                                        : Icon(
                                            Icons.camera_alt_rounded,
                                            size: 12,
                                            color: scheme.onPrimary,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              username.isEmpty ? '' : '@$username',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: gearTop,
            child: Material(
              color: gearColor.withValues(alpha: 0.88),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: onEdit,
              ),
            ),
          ),
          Positioned(
            left: collapsedAvatarLeft,
            top: collapsedAvatarTop,
            child: _ProfileHeaderFadeTransition(
              opacity: collapsedOpacity,
              child: GestureDetector(
                onTap: isUploadingAvatar ? null : onUploadAvatar,
                child: SizedBox(
                  width: collapsedAvatarSize,
                  height: collapsedAvatarSize,
                  child: PulseAvatar(
                    radius: collapsedAvatarSize / 2,
                    name: name,
                    avatarUrl: avatarUrl,
                    fallbackColor: scheme.primaryContainer,
                    textColor: scheme.onPrimaryContainer,
                    borderColor: scheme.surface,
                    borderWidth: 2,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: collapsedAvatarLeft + 48,
            top: collapsedTitleTop,
            child: _ProfileHeaderFadeTransition(
              opacity: collapsedOpacity,
              child: SizedBox(
                width: screenWidth - (collapsedAvatarLeft + 48 + 16),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(ProfileHeaderDelegate oldDelegate) {
    return name != oldDelegate.name ||
        username != oldDelegate.username ||
        avatarUrl != oldDelegate.avatarUrl ||
        isUploadingAvatar != oldDelegate.isUploadingAvatar ||
        onEdit != oldDelegate.onEdit ||
        onUploadAvatar != oldDelegate.onUploadAvatar;
  }
}

class _ExpressiveProfileFogPainter extends CustomPainter {
  const _ExpressiveProfileFogPainter({
    required this.progress,
    required this.scheme,
  });

  final double progress;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.035),
            scheme.surfaceContainerHigh,
          ),
          Color.alphaBlend(
            scheme.tertiary.withValues(alpha: 0.02),
            scheme.surfaceContainerLow,
          ),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    final double drift = (1.0 - progress) * 8;
    final double phase = progress * math.pi * 2;
    canvas.save();
    canvas.clipRect(rect.inflate(48));

    _drawFogCluster(
      canvas,
      center: Offset(
        size.width * 0.22 + math.sin(phase + 0.2) * drift,
        size.height * 0.20,
      ),
      radiusX: size.width * 0.22,
      radiusY: 34,
      color: scheme.primary.withValues(alpha: 0.12),
      blurSigma: 32,
      lobeScale: 0.94,
    );
    _drawFogCluster(
      canvas,
      center: Offset(
        size.width * 0.74 + math.cos(phase + 0.7) * drift,
        size.height * 0.18,
      ),
      radiusX: size.width * 0.16,
      radiusY: 26,
      color: scheme.primaryContainer.withValues(alpha: 0.14),
      blurSigma: 28,
      lobeScale: 0.88,
    );
    _drawFogCluster(
      canvas,
      center: Offset(
        size.width * 0.54 + math.sin(phase + 1.2) * drift,
        size.height * 0.34,
      ),
      radiusX: size.width * 0.24,
      radiusY: 38,
      color: scheme.tertiary.withValues(alpha: 0.08),
      blurSigma: 32,
      lobeScale: 1.0,
    );
    _drawFogCluster(
      canvas,
      center: Offset(
        size.width * 0.34 + math.cos(phase + 1.7) * drift,
        size.height * 0.58,
      ),
      radiusX: size.width * 0.28,
      radiusY: 42,
      color: scheme.secondary.withValues(alpha: 0.06),
      blurSigma: 32,
      lobeScale: 1.06,
    );
    _drawFogCluster(
      canvas,
      center: Offset(
        size.width * 0.76 + math.sin(phase + 2.4) * drift,
        size.height * 0.62,
      ),
      radiusX: size.width * 0.18,
      radiusY: 30,
      color: scheme.primaryContainer.withValues(alpha: 0.10),
      blurSigma: 26,
      lobeScale: 0.90,
    );
    canvas.restore();
  }

  void _drawFogCluster(
    Canvas canvas, {
    required Offset center,
    required double radiusX,
    required double radiusY,
    required Color color,
    required double blurSigma,
    required double lobeScale,
  }) {
    final Paint corePaint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    final Path body = Path()
      ..addOval(
        Rect.fromCenter(
          center: center,
          width: radiusX * 2,
          height: radiusY * 2,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: center.translate(-radiusX * 0.28, radiusY * 0.06),
          width: radiusX * 1.04 * lobeScale,
          height: radiusY * 1.02 * lobeScale,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: center.translate(radiusX * 0.24, -radiusY * 0.12),
          width: radiusX * 0.98 * lobeScale,
          height: radiusY * 0.96 * lobeScale,
        ),
      );
    canvas.drawPath(body, corePaint);
  }

  @override
  bool shouldRepaint(_ExpressiveProfileFogPainter oldDelegate) {
    return progress != oldDelegate.progress || scheme != oldDelegate.scheme;
  }
}
