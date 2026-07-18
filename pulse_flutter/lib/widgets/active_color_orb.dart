import 'package:flutter/material.dart';

class ActiveColorOrb extends StatefulWidget {
  const ActiveColorOrb({
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<ActiveColorOrb> createState() => _ActiveColorOrbState();
}

class _ActiveColorOrbState extends State<ActiveColorOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (widget.selected) {
      _pulseController.value = 1;
    }
  }

  @override
  void didUpdateWidget(ActiveColorOrb old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _pulseController.forward(from: 0);
    } else if (!widget.selected && old.selected) {
      _pulseController.reverse();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  List<Color> _tonalPalette(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return [
      scheme.surfaceContainerHigh,
      scheme.primaryContainer,
      scheme.primary,
      scheme.onPrimaryContainer,
      scheme.onPrimary,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = _tonalPalette(widget.color, scheme.brightness);

    return GestureDetector(
      onTap: widget.onTap,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulse = _pulseController.value;
            final orbSize = 48.0 + (widget.selected ? pulse * 4 : 0);
            final segHeight = (orbSize - 4) / 5;

            return Container(
              width: orbSize,
              height: orbSize + 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: widget.selected
                    ? Border.all(
                        color: scheme.primary,
                        width: 2.0 * (1 + pulse * 0.3),
                      )
                    : Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.3),
                        width: 1,
                      ),
                boxShadow: widget.selected
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.3 + pulse * 0.2),
                          blurRadius: 8 + pulse * 6,
                          spreadRadius: 1 + pulse * 2,
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  children: tones.map((c) {
                    return Expanded(
                      child: Container(color: c),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
