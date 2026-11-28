import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
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

  // CAM16 seed schemes are expensive, so the preview only adopts a new seed
  // when a gesture commits (tap, pan end, slider end). Dragging repaints the
  // thumb and the code live but reuses the already-computed scheme.
  late Color _previewSeed;
  Color? _schemeSeed;
  Brightness? _schemeBrightness;
  ColorScheme? _scheme;
  final Map<Color, Color> _presetOnPrimary = <Color, Color>{};

  String _code(Color color) =>
      color.toARGB32().toRadixString(16).substring(2).toUpperCase();
  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor.withValues(alpha: 1);
    _hue = HSVColor.fromColor(_selected).hue;
    _previewSeed = _selected;
    _hex = TextEditingController(text: _code(_selected));
  }

  ColorScheme _schemeFor(Color seed, Brightness brightness) {
    if (_scheme == null ||
        _schemeSeed != seed ||
        _schemeBrightness != brightness) {
      _schemeSeed = seed;
      _schemeBrightness = brightness;
      _scheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      );
    }
    return _scheme!;
  }

  /// One tonal-spot scheme per preset swatch, computed when it is first
  /// selected instead of inside every item build.
  Color _presetOnPrimaryFor(Color color) => _presetOnPrimary.putIfAbsent(
    color,
    () => ColorScheme.fromSeed(seedColor: color).onPrimary,
  );

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _setDraft(Color color) {
    _selected = color;
    final hsv = HSVColor.fromColor(color);
    if (hsv.saturation > 0 && hsv.value > 0) _hue = hsv.hue;
    _hex.text = _code(color);
    _valid = true;
  }

  /// A committed selection also refreshes the preview scheme.
  void _select(Color color) {
    setState(() {
      _setDraft(color);
      _previewSeed = color;
    });
  }

  /// Dragging only moves the draft color; the scheme catches up on release.
  void _selectTransient(Color color) => setState(() => _setDraft(color));

  void _commitPreview() {
    if (_previewSeed == _selected) return;
    setState(() => _previewSeed = _selected);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = _schemeFor(_previewSeed, scheme.brightness);
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
              const SizedBox(height: AppSpacing.md),
              AnimatedContainer(
                duration: context.reduceMotion
                    ? Duration.zero : M3Durations.medium3,
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
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: context.reduceMotion
                              ? Duration.zero : M3Durations.medium3,
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
                        const SizedBox(width: AppSpacing.lg),
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
                                duration: context.reduceMotion
                                    ? Duration.zero : M3Durations.medium3,
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
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = width / 2.1;
                  void pick(Offset offset, {bool commit = false}) {
                    final color = HSVColor.fromAHSV(
                      1,
                      _hue,
                      (offset.dx / width).clamp(0, 1),
                      (1 - offset.dy / height).clamp(0, 1),
                    ).toColor();
                    if (commit) {
                      _select(color);
                    } else {
                      _selectTransient(color);
                    }
                  }

                  return Semantics(
                    label: context.l10n.appearanceCustomColor,
                    value: '#${_code(_selected)}',
                    child: GestureDetector(
                      key: const ValueKey('custom-color-plane'),
                      onTapDown: (event) => pick(
                        event.localPosition,
                        commit: true,
                      ),
                      onPanUpdate: (event) => pick(event.localPosition),
                      onPanEnd: (_) => _commitPreview(),
                      onPanCancel: _commitPreview,
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
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                label: context.l10n.appearanceCustomColor,
                value: '#${_code(_selected)}',
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
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
                          _selectTransient(hsv.withHue(hue).toColor());
                        },
                        onChangeEnd: (_) => _commitPreview(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
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
                                      color: _presetOnPrimaryFor(color),
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
                    // Typing is not a gesture: the preview follows each keystroke.
                    _previewSeed = _selected;
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
