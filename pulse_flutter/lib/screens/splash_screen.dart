import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/session_provider.dart';
import 'package:pulse_flutter/widgets/animated_mesh_background.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFlow());
  }

  Future<void> _startFlow() async {
    await Future<void>.delayed(2200.ms);
    if (!mounted) {
      return;
    }

    await Future.wait(<Future<void>>[
      ref.read(sessionProvider.notifier).ensureLoaded(),
      ref.read(authProvider.notifier).ensureLoaded(),
    ]);
    if (!mounted) {
      return;
    }

    final SessionState session = ref.read(sessionProvider);
    if (!session.onboardingCompleted) {
      context.go('/onboarding');
      return;
    }

    final AuthState auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      context.go('/login');
      return;
    }

    context.go('/main/chats');
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AnimatedMeshBackground(
      child: Stack(
        children: <Widget>[
          // Hidden BackdropFilter to pre-compile blur shaders
          Positioned(
            left: 0,
            top: 0,
            width: 10,
            height: 10,
            child: Opacity(
              opacity: 0.01,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.20),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Image.asset(
                      'assets/NiosMess_icon.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                .animate(
                  onPlay: (AnimationController controller) => controller.repeat(reverse: true),
                )
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.06, 1.06),
                  duration: 1100.ms,
                  curve: Curves.easeInOut,
                ),
                const SizedBox(height: 20),
                Text(context.l10n.appName, style: textTheme.displayLarge),
                const SizedBox(height: 8),
                Text(
                  context.l10n.splashTagline,
                  style: textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (Theme.of(context).platform != TargetPlatform.android && Theme.of(context).platform != TargetPlatform.iOS) ...<Widget>[
                  const SizedBox(height: 32),
                  Text(
                    'Оптимизация графики...',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  )
                  .animate()
                  .fade(delay: 500.ms, duration: 800.ms),
                ],
              ],
            )
            .animate()
            .fade(duration: 500.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
          ),
        ],
      ),
    );
  }
}
