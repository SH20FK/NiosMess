import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

const _customColorPresets = <Color>[
  Color(0xFF6750A4), // Amethyst Violet
  Color(0xFF3F51B5), // Indigo
  Color(0xFF2563EB), // Royal Blue
  Color(0xFF0284C7), // Sky
  Color(0xFF00838F), // Cyan
  Color(0xFF006C5B), // Lagoon Teal
  Color(0xFF16A34A), // Emerald
  Color(0xFF65A30D), // Lime
  Color(0xFFD97706), // Amber
  Color(0xFFEA580C), // Orange
  Color(0xFFE11D48), // Crimson
  Color(0xFFDB2777), // Pink
  Color(0xFFA21CAF), // Fuchsia
  Color(0xFF7C3AED), // Vivid Purple
  Color(0xFF475569), // Slate
  Color(0xFF78350F), // Bronze
];

/// A local draft: selecting colors never changes the account's theme.
class CustomColorPickerSheet extends StatefulWidget {
  const CustomColorPickerSheet({
    required this.initialColor,
    required this.onApplyColor,
    super.key,
  });
  final Color initialColor;
  final ValueChanged<Color> onApplyColor;
  @override
  State<CustomColorPickerSheet> createState() => _CustomColorPickerSheetState();
}

class _CustomColorPickerSheetState extends State<CustomColorPickerSheet> {
  late Color _selected;
  late double _hue;
  late final TextEditingController _hex;
  bool _valid = true;
  String _code(Color color) =>
      color.toARGB32().toRadixString(16).substring(2).toUpperCase();
  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor.withValues(alpha: 1);
    _hue = HSVColor.fromColor(_selected).hue;
    _hex = TextEditingController(text: _code(_selected));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _select(Color color) {
    setState(() {
      _selected = color;
      final hsv = HSVColor.fromColor(color);
      if (hsv.saturation > 0 && hsv.value > 0) _hue = hsv.hue;
      _hex.text = _code(color);
      _valid = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = ColorScheme.fromSeed(
      seedColor: _selected,
      brightness: scheme.brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
    );
    final hsv = HSVColor.fromColor(_selected).withHue(_hue);
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(28),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.appearanceCustomColor,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: M3SpringCurves.expressiveStandard,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: preview.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.appearanceAccentPreview,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: preview.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: preview.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.palette_rounded,
                            color: preview.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '#${_code(_selected)}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: preview.onSurface),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ExcludeSemantics(
                      child: Row(
                        children: [
                          for (final color in [
                            preview.primary,
                            preview.secondary,
                            preview.tertiary,
                            preview.primaryContainer,
                          ])
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                height: 32,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.appearanceSelectHexPrompt,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = width / 2.1;
                  void pick(Offset offset) => _select(
                    HSVColor.fromAHSV(
                      1,
                      _hue,
                      (offset.dx / width).clamp(0, 1),
                      (1 - offset.dy / height).clamp(0, 1),
                    ).toColor(),
                  );
                  return Semantics(
                    label: context.l10n.appearanceCustomColor,
                    value: '#${_code(_selected)}',
                    child: GestureDetector(
                      key: const ValueKey('custom-color-plane'),
                      onTapDown: (event) => pick(event.localPosition),
                      onPanUpdate: (event) => pick(event.localPosition),
                      child: SizedBox(
                        height: height,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        HSVColor.fromAHSV(
                                          1,
                                          _hue,
                                          0,
                                          1,
                                        ).toColor(),
                                        HSVColor.fromAHSV(
                                          1,
                                          _hue,
                                          1,
                                          1,
                                        ).toColor(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        HSVColor.fromAHSV(
                                          0,
                                          _hue,
                                          0,
                                          0,
                                        ).toColor(),
                                        HSVColor.fromAHSV(
                                          1,
                                          _hue,
                                          0,
                                          0,
                                        ).toColor(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: (hsv.saturation * (width - 24)),
                                top: (1 - hsv.value) * (height - 24),
                                child: IgnorePointer(
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _selected,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: scheme.onSurface,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Semantics(
                label: context.l10n.appearanceCustomColor,
                value: '#${_code(_selected)}',
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: List.generate(
                            13,
                            (i) => HSVColor.fromAHSV(
                              1,
                              i * 30.0,
                              0.65,
                              0.9,
                            ).toColor(),
                          ),
                        ),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 0,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: _selected,
                        overlayColor: scheme.primary.withValues(alpha: 0.12),
                      ),
                      child: Slider(
                        value: _hue,
                        min: 0,
                        max: 360,
                        label: '#${_code(_selected)}',
                        onChanged: (hue) {
                          _hue = hue;
                          _select(hsv.withHue(hue).toColor());
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in _customColorPresets)
                    Semantics(
                      button: true,
                      selected: _selected.toARGB32() == color.toARGB32(),
                      label: '#${_code(color)}',
                      child: Tooltip(
                        message: '#${_code(color)}',
                        child: Material(
                          color: color,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              HapticService.tap();
                              _select(color);
                            },
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: _selected.toARGB32() == color.toARGB32()
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: ColorScheme.fromSeed(
                                        seedColor: color,
                                      ).onPrimary,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey('custom-color-hex'),
                controller: _hex,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-fA-F0-9]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: context.l10n.appearanceHexLabel,
                  prefixText: '#',
                  errorText: _valid ? null : context.l10n.appearanceInvalidHex,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onChanged: (code) => setState(() {
                  final parsed = code.length == 6
                      ? int.tryParse(code, radix: 16)
                      : null;
                  _valid = parsed != null;
                  if (parsed != null) {
                    _selected = Color(0xff000000 | parsed);
                    _hue = HSVColor.fromColor(_selected).hue;
                  }
                }),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('custom-color-apply'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: !_valid
                    ? null
                    : () {
                        HapticService.confirm();
                        widget.onApplyColor(_selected);
                        Navigator.of(context).pop();
                      },
                icon: const Icon(Icons.check_rounded),
                label: Text(context.l10n.appearanceApply),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
