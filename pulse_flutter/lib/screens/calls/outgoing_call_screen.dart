import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/chat_actions_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/services/calls/call_starter.dart';
import 'package:pulse_flutter/core/utils/bot_detector.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Arguments for launching the outgoing call screen.
class OutgoingCallArgs {
  const OutgoingCallArgs({
    required this.username,
    this.displayName = '',
    this.avatarUrl,
    this.chatId,
    this.isVideo = false,
  });

  final String username;
  final String displayName;
  final String? avatarUrl;
  final int? chatId;
  final bool isVideo;
}

/// Outgoing call screen rendered immediately in connecting state without
/// full-screen interstitial loading screens.
class OutgoingCallScreen extends ConsumerStatefulWidget {
  const OutgoingCallScreen({
    required this.args,
    super.key,
  });

  final OutgoingCallArgs args;

  @override
  ConsumerState<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends ConsumerState<OutgoingCallScreen>
    with SingleTickerProviderStateMixin {
  bool _cancelled = false;
  bool _isListenerNotice = false;
  String? _errorMessage;
  late final AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: CallTokens.rippleAnimationDuration,
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startCallFlow();
      }
    });
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _startCallFlow() async {
    final String targetUsername = widget.args.username.trim().toLowerCase();

    // 1. Bot check (ЗВН-7)
    if (BotDetector.isBot(targetUsername)) {
      if (!mounted || _cancelled) return;
      setState(() {
        _errorMessage = context.l10n.callsBotForbidden;
      });
      return;
    }

    // 2. Resolve chatId
    int? resolvedChatId = widget.args.chatId;
    if (resolvedChatId == null || resolvedChatId <= 0) {
      final List<ApiChatSummary> chats = ref.read(chatsProvider).value ?? const <ApiChatSummary>[];
      for (final ApiChatSummary c in chats) {
        if (c.chatType == 'direct' &&
            c.username != null &&
            c.username!.trim().toLowerCase() == targetUsername) {
          resolvedChatId = c.id;
          break;
        }
      }
    }

    if (resolvedChatId == null || resolvedChatId <= 0) {
      try {
        final DirectChatOpenResult? res = await ref
            .read(chatRepositoryProvider)
            .openDirectChat(username: widget.args.username);
        if (_cancelled || !mounted) return;
        if (res != null && res.chatId > 0) {
          resolvedChatId = res.chatId;
          unawaited(ref.read(chatsProvider.notifier).refresh());
        }
      } catch (e) {
        if (_cancelled || !mounted) return;
        setState(() {
          _errorMessage = e is ApiException ? e.message : context.l10n.callRedirectFailed;
        });
        return;
      }
    }

    if (resolvedChatId == null || resolvedChatId <= 0) {
      if (!mounted || _cancelled) return;
      setState(() {
        _errorMessage = context.l10n.callRedirectFailed;
      });
      return;
    }

    // 3. Initiate outgoing call (permissions requested in call_starter per ЗВН-4)
    try {
      final String peerName = widget.args.displayName.isNotEmpty
          ? widget.args.displayName
          : widget.args.username;

      final int callId = await startOutgoingCall(
        ref: ref,
        chatId: resolvedChatId,
        isVideo: widget.args.isVideo,
        peerName: peerName,
        peerAvatarUrl: widget.args.avatarUrl,
        peerUsername: widget.args.username,
        onPermissionResult: (bool isListener) {
          if (mounted && isListener) {
            setState(() {
              _isListenerNotice = true;
            });
          }
        },
      );

      if (_cancelled || !mounted) return;

      // Navigate to active call, replacing outgoing screen in the stack so 'back'
      // returns cleanly to the originating screen (e.g. profile).
      context.pushReplacement('/call/$callId');
    } on CallStartException catch (e) {
      if (_cancelled || !mounted) return;
      setState(() {
        if (e.failure == CallStartFailure.botForbidden) {
          _errorMessage = context.l10n.callsBotForbidden;
        } else if (e.failure == CallStartFailure.permissions) {
          _errorMessage = context.l10n.chatCallPermissionRequired;
        } else {
          _errorMessage = context.l10n.callRedirectFailed;
        }
      });
    } catch (e) {
      if (_cancelled || !mounted) return;
      setState(() {
        _errorMessage = e is ApiException ? e.message : context.l10n.callRedirectFailed;
      });
    }
  }

  void _cancelAndPop() {
    _cancelled = true;
    HapticService.tap();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/main/chats');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String displayName = widget.args.displayName.isNotEmpty
        ? widget.args.displayName
        : widget.args.username;

    return Scaffold(
      backgroundColor: CallTokens.darkSurface,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            // ── Top Bar ───────────────────────────────────────────────
            Positioned(
              top: 8,
              left: 12,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: scheme.onSurface,
                  size: 26,
                ),
                onPressed: _cancelAndPop,
              ),
            ),

            // ── Central User Information ──────────────────────────────
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PulseAvatar(
                      name: displayName,
                      avatarUrl: widget.args.avatarUrl,
                      radius: 64,
                      fallbackColor: scheme.primaryContainer,
                      textColor: scheme.onPrimaryContainer,
                      borderColor: scheme.outlineVariant.withValues(alpha: 0.3),
                      borderWidth: 2,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.args.username.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '@${widget.args.username}',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Call type indicator pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(CallTokens.pillBorderRadius),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.args.isVideo
                                ? Icons.videocam_rounded
                                : Icons.phone_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.args.isVideo
                                ? context.l10n.callIncomingVideo
                                : context.l10n.callIncomingVoice,
                            style: textTheme.labelMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status / Error
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.error_outline_rounded,
                                size: 20, color: scheme.onErrorContainer),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AppLoadingIndicator(
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            context.l10n.callsConnecting,
                            style: textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      if (_isListenerNotice) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.hearing_rounded,
                                  size: 16, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  context.l10n.callListenerModeNotice,
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // ── Bottom Action Dock ────────────────────────────────────
            Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(CallTokens.meetEndButtonHeight / 2),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(CallTokens.meetEndButtonHeight / 2),
                    onTap: _cancelAndPop,
                    child: Container(
                      width: CallTokens.meetEndButtonWidth,
                      height: CallTokens.meetEndButtonHeight,
                      decoration: BoxDecoration(
                        color: scheme.error,
                        borderRadius: BorderRadius.circular(CallTokens.meetEndButtonHeight / 2),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.call_end_rounded,
                          color: scheme.onError,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
