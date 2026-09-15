import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/session_provider.dart';
import 'package:pulse_flutter/widgets/app_logo_mark.dart';
import 'package:pulse_flutter/widgets/m3_organic_background.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _hasError = false;
  String? _errorMessage;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFlow());
  }

  Future<void> _startFlow() async {
    if (!mounted) return;
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _isRetrying = true;
    });

    try {
      final Future<void> minDisplayDelay =
          Future<void>.delayed(const Duration(milliseconds: 350));
      final Future<void> initialization = Future.wait(<Future<void>>[
        ref.read(sessionProvider.notifier).ensureLoaded(),
        ref.read(authProvider.notifier).ensureLoaded(),
      ]);

      await Future.wait(<Future<void>>[minDisplayDelay, initialization]);
      if (!mounted) return;

      // 1. Authenticated users always proceed directly to main chats (zero onboarding flash)
      final AuthState auth = ref.read(authProvider);
      if (auth.isAuthenticated) {
        context.go('/main/chats');
        return;
      }

      // 2. Unauthenticated first-time users proceed to onboarding
      final SessionState session = ref.read(sessionProvider);
      if (!session.onboardingCompleted) {
        context.go('/onboarding');
        return;
      }

      // 3. Returning unauthenticated users proceed to login
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isRetrying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return M3OrganicBackground(
      showBackButton: false,
      showThemeToggle: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Hero Brand Logo with unified tag and M3 spring motion
              Hero(
                tag: 'app_brand_logo',
                child: const AppLogoMark(size: 96),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.82, 0.82),
                    end: const Offset(1, 1),
                    duration: const Duration(milliseconds: 380),
                    curve: M3SpringCurves.spatial,
                  )
                  .fade(duration: const Duration(milliseconds: 300)),
              const SizedBox(height: 20),

              Text(
                context.l10n.appName,
                style: textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ).animate().fade(
                    delay: const Duration(milliseconds: 80),
                    duration: const Duration(milliseconds: 280),
                  ),
              const SizedBox(height: 8),

              Text(
                context.l10n.splashTagline,
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ).animate().fade(
                    delay: const Duration(milliseconds: 140),
                    duration: const Duration(milliseconds: 280),
                  ),
              const SizedBox(height: 36),

              // Dynamic State: Error with Retry, or subtle M3 indicator if delayed
              if (_hasError) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.6),
                    borderRadius: AppRadii.lgRadius,
                    border: Border.all(
                      color: scheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, color: scheme.error, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage ?? context.l10n.commonError,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          HapticService.selection();
                          _startFlow();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadii.fullRadius,
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(context.l10n.commonRetry),
                      ),
                    ],
                  ),
                ).animate().fade(duration: const Duration(milliseconds: 250)),
              ] else if (_isRetrying) ...[
                AppLoadingIndicator(size: 28, color: scheme.primary)
                    .animate()
                    .fade(
                      delay: const Duration(milliseconds: 500),
                      duration: const Duration(milliseconds: 300),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
