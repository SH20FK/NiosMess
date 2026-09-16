import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/identity/nios_mark.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';

/// Interactive Material 3 Expressive generative identity badge.
class NiosMarkBadge extends ConsumerStatefulWidget {
  const NiosMarkBadge({
    super.key,
    required this.id,
    this.name,
    this.size = 56,
    this.interactive = true,
  });

  final String id;
  final String? name;
  final double size;
  final bool interactive;

  @override
  ConsumerState<NiosMarkBadge> createState() => _NiosMarkBadgeState();
}

class _NiosMarkBadgeState extends ConsumerState<NiosMarkBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap(NiosMarkData mark) {
    if (!widget.interactive) return;

    TriSync.pop(ref: ref);
    _pulseController.forward().then((_) {
      if (mounted) _pulseController.reverse();
    });

    _showMarkSheet(context, mark);
  }

  void _showMarkSheet(BuildContext context, NiosMarkData mark) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Visual Hero Mark Preview
                Transform.rotate(
                  angle: mark.tiltDegrees * math.pi / 180,
                  child: M3Container(
                    mark.shape,
                    width: 96,
                    height: 96,
                    color: mark.color,
                    child: Center(
                      child: Text(
                        mark.monogram,
                        style: textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Onest',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.name ?? 'Nios Mark',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nios Mark • Генеративная идентичность',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Уникальная геометрическая форма и тон вычислены детерминированно из вашего аккаунта. Они остаются неизменными на всех платформах.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                // Action: Copy Share Link
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: 'https://ni-os.ru/m/${mark.id}'),
                          );
                          TriSync.snap(ref: ref);
                          Navigator.of(sheetContext).pop();
                          AppToast.showSuccess(
                            context,
                            'Ссылка на Nios Mark скопирована!',
                          );
                        },
                        icon: const Icon(Icons.link_rounded, size: 20),
                        label: const Text('Скопировать ссылку'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: 'niosmark://${mark.id}?seed=${mark.seed}'),
                          );
                          TriSync.snap(ref: ref);
                          Navigator.of(sheetContext).pop();
                          AppToast.showSuccess(
                            context,
                            'Идентификатор марки скопирован!',
                          );
                        },
                        icon: const Icon(Icons.share_rounded, size: 20),
                        label: const Text('Поделиться'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final NiosMarkData mark = NiosMark.generate(
      widget.id,
      brightness: scheme.brightness,
      name: widget.name,
    );

    final Widget badge = Transform.rotate(
      angle: mark.tiltDegrees * math.pi / 180,
      child: M3Container(
        mark.shape,
        width: widget.size,
        height: widget.size,
        color: mark.color,
        child: Center(
          child: Text(
            mark.monogram,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.size * 0.38,
              fontWeight: FontWeight.w700,
              fontFamily: 'Onest',
            ),
          ),
        ),
      ),
    );

    if (!widget.interactive) {
      return badge;
    }

    return GestureDetector(
      onTap: () => _handleTap(mark),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: badge,
      ),
    );
  }
}
