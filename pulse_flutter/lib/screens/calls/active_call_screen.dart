import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'active_voice_call_screen.dart';
import 'active_video_call_screen.dart';

class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  Timer? _timeoutTimer;
  bool _isTimedOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          ref.read(isCallScreenOpenProvider.notifier).setOpen(true);
        } catch (_) {}
      }
    });
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    if (mounted) {
      setState(() {
        _isTimedOut = false;
      });
    }
    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) {
        final session = ref.read(callSessionProvider)?.session;
        if (session == null) {
          setState(() {
            _isTimedOut = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    try {
      ref.read(isCallScreenOpenProvider.notifier).setOpen(false);
    } catch (_) {}
    super.dispose();
  }

  void _popOrGoHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      ref.read(appRouterProvider).go('/main/chats');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(callSessionProvider)?.session;
    final theme = Theme.of(context);
    final appScheme = theme.colorScheme;
    final callScheme = ColorScheme.fromSeed(
      seedColor: appScheme.primary,
      brightness: Brightness.dark,
    );
    final textTheme = theme.textTheme;

    if (session == null) {
      if (_isTimedOut) {
        final radii = AppRadii.of(context);
        return Scaffold(
          backgroundColor: CallTokens.darkSurface,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0F14),
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.2),
                radius: 1.1,
                colors: [
                  callScheme.error.withValues(alpha: 0.12),
                  callScheme.surfaceContainerLowest,
                  const Color(0xFF0B0C10),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: callScheme.surfaceContainerHigh.withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(radii.card),
                        border: Border.all(
                          color: callScheme.outlineVariant.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: callScheme.errorContainer,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.phone_missed_rounded,
                              size: 32,
                              color: callScheme.onErrorContainer,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            context.l10n.callSessionNotFound,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: callScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.callTimeout,
                            style: textTheme.bodyMedium?.copyWith(
                              color: callScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    HapticService.tap();
                                    _popOrGoHome();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: callScheme.onSurface,
                                    side: BorderSide(
                                      color: callScheme.outlineVariant.withValues(alpha: 0.4),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(radii.button),
                                    ),
                                  ),
                                  child: Text(context.l10n.callBackToChats),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    HapticService.tap();
                                    _startTimeoutTimer();
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: callScheme.primary,
                                    foregroundColor: callScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(radii.button),
                                    ),
                                  ),
                                  child: Text(context.l10n.callRetry),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Connecting state before session connects
      return Scaffold(
        backgroundColor: CallTokens.darkSurface,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F14),
            gradient: RadialGradient(
              center: const Alignment(0.0, -0.25),
              radius: 1.1,
              colors: [
                callScheme.primary.withValues(alpha: 0.16),
                callScheme.tertiary.withValues(alpha: 0.06),
                const Color(0xFF0B0C10),
              ],
              stops: const [0.0, 0.50, 1.0],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: <Widget>[
                // Top close button
                Positioned(
                  top: 8,
                  left: 12,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: callScheme.onSurface,
                      size: 26,
                    ),
                    onPressed: () {
                      HapticService.tap();
                      _popOrGoHome();
                    },
                  ),
                ),

                // Center connecting indicator
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: callScheme.surfaceContainerHigh,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: callScheme.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.phone_in_talk_rounded,
                            size: 48,
                            color: callScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AppLoadingIndicator(
                            size: 16,
                            color: callScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            context.l10n.callsConnecting,
                            style: textTheme.bodyLarge?.copyWith(
                              color: callScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Установка защищённого соединения...',
                        style: textTheme.bodySmall?.copyWith(
                          color: callScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom cancel button
                Positioned(
                  bottom: 36,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Tooltip(
                      message: context.l10n.callEnd,
                      child: TouchContainer(
                        width: CallTokens.meetEndButtonWidth,
                        height: CallTokens.meetEndButtonHeight,
                        borderRadius: BorderRadius.circular(CallTokens.meetEndButtonHeight / 2),
                        color: callScheme.error,
                        scaleDown: 0.94,
                        releaseCurve: M3SpringCurves.spatial,
                        enableHaptics: true,
                        onTap: () {
                          HapticService.confirm();
                          _popOrGoHome();
                        },
                        child: Center(
                          child: Icon(
                            Icons.call_end_rounded,
                            color: callScheme.onError,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    _timeoutTimer?.cancel();
    final isVideo = session.currentData.isVideo;
    if (isVideo) {
      return const ActiveVideoCallScreen();
    } else {
      return const ActiveVoiceCallScreen();
    }
  }
}
