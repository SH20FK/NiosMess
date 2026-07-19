import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class ActiveColorOrb extends ConsumerStatefulWidget {
  const ActiveColorOrb({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.label,
    super.key,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String label;

  @override
  ConsumerState<ActiveColorOrb> createState() => _ActiveColorOrbState();
}

class _ActiveColorOrbState extends ConsumerState<ActiveColorOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnim;
  late final Animation<double> _glowAnim;

  late ColorScheme _seedScheme;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnim = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60,
      ),
    ]).animate(_bounceController);

    _glowAnim = Tween<double>(begin: 0.3, end: 0.55)
        .animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut));

    _seedScheme = ColorScheme.fromSeed(
      seedColor: widget.color,
      brightness: Theme.of(context).brightness,
    );

    if (widget.selected) {
      _bounceController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ActiveColorOrb old) {
    super.didUpdateWidget(old);
    if (widget.color != old.color) {
      _seedScheme = ColorScheme.fromSeed(
        seedColor: widget.color,
        brightness: Theme.of(context).brightness,
      );
    }
    if (widget.selected && !old.selected) {
      _bounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final seedPrimary = _seedScheme.primary;

    return Semantics(
      selected: widget.selected,
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTap: () {
          ref.read(appSoundProvider).playUiTick();
          if (ref.read(uiSettingsProvider).haptics) {
            HapticService.tap();
          }
          widget.onTap();
        },
        child: RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedBuilder(
                animation: _bounceController,
                builder: (context, child) {
                  final scale = widget.selected ? _bounceAnim.value : 1.0;
                  final glowAlpha = widget.selected ? _glowAnim.value : 0.0;

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: seedPrimary,
                        border: widget.selected
                            ? Border.all(
                                color: seedPrimary.withValues(alpha: 0.6),
                                width: 3,
                              )
                            : Border.all(
                                color: scheme.outlineVariant.withValues(alpha: 0.2),
                                width: 1,
                              ),
                        boxShadow: widget.selected
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: seedPrimary.withValues(alpha: glowAlpha),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              ]
                            : <BoxShadow>[
                                BoxShadow(
                                  color: scheme.shadow.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: widget.selected
                          ? Icon(
                              Icons.check_rounded,
                              color: _seedScheme.onPrimary,
                              size: 26,
                            )
                          : null,
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: textTheme.labelSmall?.copyWith(
                  color: widget.selected
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
