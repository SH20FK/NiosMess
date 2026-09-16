import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/providers/call_session_provider.dart';
import 'package:pulse_flutter/router/app_router.dart';
import 'active_voice_call_screen.dart';
import 'active_video_call_screen.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

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
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(callSessionProvider)?.session;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (session == null) {
      if (_isTimedOut) {
        final radii = AppRadii.of(context);
        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  ref.read(appRouterProvider).go('/main/chats');
                }
              },
            ),
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(radii.card),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.phone_missed_rounded,
                          size: 32,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.l10n.callSessionNotFound,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.callTimeout,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else {
                                  ref.read(appRouterProvider).go('/main/chats');
                                }
                              },
                              style: OutlinedButton.styleFrom(
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
                              onPressed: _startTimeoutTimer,
                              style: FilledButton.styleFrom(
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
        );
      }

      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                ref.read(appRouterProvider).go('/main/chats');
              }
            },
          ),
        ),
        body: Center(
          child: AppLoadingIndicator(color: scheme.primary),
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
