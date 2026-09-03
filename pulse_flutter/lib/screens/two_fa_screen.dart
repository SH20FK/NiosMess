import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/m3_organic_background.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class TwoFaScreen extends ConsumerStatefulWidget {
  const TwoFaScreen({this.initialIdentifier, super.key});

  final String? initialIdentifier;

  @override
  ConsumerState<TwoFaScreen> createState() => _TwoFaScreenState();
}

class _TwoFaScreenState extends ConsumerState<TwoFaScreen> {
  String _pin = '';
  static const int _pinLength = 6;

  // 6 distinct M3 shapes for the PIN indicator dots
  static const List<Shapes> _dotShapes = [
    Shapes.c9_sided_cookie,
    Shapes.triangle,
    Shapes.square,
    Shapes.c4_sided_cookie,
    Shapes.gem,
    Shapes.flower,
  ];

  // 6 vibrant pastel colors for the illuminated dots
  static const List<Color> _dotColors = [
    Color(0xFF5B8DEF), // Cobalt Blue
    Color(0xFF6ED0F6), // Soft Cyan
    Color(0xFFF67599), // Soft Pink
    Color(0xFF9E86F8), // Lavender
    Color(0xFF5FE1B5), // Mint
    Color(0xFFFF8B70), // Coral
  ];

  @override
  void initState() {
    super.initState();
    final String? identifier = widget.initialIdentifier;
    if (identifier != null && identifier.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(authProvider.notifier).setPendingIdentifier(identifier);
        }
      });
    }
  }

  void _onDigitPressed(String digit) {
    if (_pin.length < _pinLength) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin += digit;
      });

      if (_pin.length == _pinLength) {
        _submit();
      }
    }
  }

  void _onBackspacePressed() {
    if (_pin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _submit() async {
    if (_pin.length != _pinLength) {
      return;
    }

    final AuthActionResult result = await ref
        .read(authProvider.notifier)
        .verifyTwoFa(code: _pin);

    if (!mounted) {
      return;
    }

    if (result.success) {
      HapticService.confirm();
      context.go('/main/chats');
      return;
    }

    HapticService.destructive();
    AppToast.showError(context, result.message ?? context.l10n.twoFaFailed);
    setState(() {
      _pin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return M3OrganicBackground(
      showBackButton: true,
      showThemeToggle: true,
      onBack: () {
        if (Navigator.canPop(context)) {
          context.pop();
        } else {
          context.go('/login');
        }
      },
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),

                  // ── Screen Title ─────────────────────────────────────
                  Text(
                    context.l10n.twoFaHeroTitle,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ).animate().fade(duration: 350.ms),
                  const SizedBox(height: 8),

                  Text(
                    context.l10n.twoFaHeroSubtitle,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ).animate().fade(delay: 100.ms, duration: 350.ms),
                  const SizedBox(height: 32),

                  // ── Animated Geometric M3 PIN Dots ───────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (index) {
                      final bool isFilled = index < _pin.length;
                      final shape = _dotShapes[index % _dotShapes.length];
                      final activeColor = _dotColors[index % _dotColors.length];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: AnimatedScale(
                          scale: isFilled ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeInOut,
                            width: 22,
                            height: 22,
                            child: M3Container(
                              shape,
                              color: isFilled
                                  ? activeColor
                                  : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                              child: isFilled
                                  ? const SizedBox.shrink()
                                  : Center(
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ).animate().fade(delay: 150.ms, duration: 350.ms),
                  const SizedBox(height: 36),

                  // ── Loading indicator when submitting ────────────────
                  if (auth.busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: AppLoadingIndicator(size: 32),
                    )
                  else ...[
                    // ── M3 Numeric Keypad ──────────────────────────────
                    _M3NumericKeypad(
                      scheme: scheme,
                      onDigit: _onDigitPressed,
                      onBackspace: _onBackspacePressed,
                      onSubmit: _submit,
                      canSubmit: _pin.length == _pinLength,
                    ).animate().fade(delay: 200.ms, duration: 350.ms),
                  ],

                  SizedBox(height: bottomInset > 0 ? bottomInset : 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _M3NumericKeypad extends StatelessWidget {
  const _M3NumericKeypad({
    required this.scheme,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    required this.canSubmit,
  });

  final ColorScheme scheme;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildKeyRow(['1', '2', '3']),
        const SizedBox(height: 16),
        _buildKeyRow(['4', '5', '6']),
        const SizedBox(height: 16),
        _buildKeyRow(['7', '8', '9']),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Backspace Key
            _KeypadActionKey(
              icon: Icons.backspace_outlined,
              scheme: scheme,
              onTap: onBackspace,
            ),

            // Digit 0
            _KeypadDigitKey(
              digit: '0',
              scheme: scheme,
              onTap: () => onDigit('0'),
            ),

            // Submit Arrow Key
            _KeypadActionKey(
              icon: Icons.arrow_forward_rounded,
              scheme: scheme,
              isEnabled: canSubmit,
              isPrimary: canSubmit,
              onTap: onSubmit,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map(
            (d) => _KeypadDigitKey(
              digit: d,
              scheme: scheme,
              onTap: () => onDigit(d),
            ),
          )
          .toList(),
    );
  }
}

class _KeypadDigitKey extends StatelessWidget {
  const _KeypadDigitKey({
    required this.digit,
    required this.scheme,
    required this.onTap,
  });

  final String digit;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.65),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Text(
            digit,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadActionKey extends StatelessWidget {
  const _KeypadActionKey({
    required this.icon,
    required this.scheme,
    required this.onTap,
    this.isEnabled = true,
    this.isPrimary = false,
  });

  final IconData icon;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final bool isEnabled;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary
        ? scheme.primary
        : scheme.surfaceContainerHigh.withValues(alpha: 0.65);
    final fgColor = isPrimary
        ? scheme.onPrimary
        : scheme.onSurface.withValues(alpha: isEnabled ? 1.0 : 0.4);

    return Material(
      color: bgColor,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isEnabled ? onTap : null,
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: isPrimary
                ? null
                : Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
                    width: 1,
                  ),
          ),
          child: Icon(
            icon,
            size: 24,
            color: fgColor,
          ),
        ),
      ),
    );
  }
}
