import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/services/calls/call_starter.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';

/// Resolves a username to a direct chat and immediately starts a call —
/// backs the `/call/dm/:username?isVideo=` route used from public profiles.
class CallRedirectScreen extends ConsumerStatefulWidget {
  const CallRedirectScreen({
    required this.username,
    this.isVideo = false,
    super.key,
  });

  final String username;
  final bool isVideo;

  @override
  ConsumerState<CallRedirectScreen> createState() =>
      _CallRedirectScreenState();
}

class _CallRedirectScreenState extends ConsumerState<CallRedirectScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    int chatId;
    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .openDirectChatByUsername(widget.username);
      if (result == null || result.chatId <= 0) {
        throw ApiException(statusCode: 0, message: 'Could not resolve dialog.');
      }
      chatId = result.chatId;
      await ref.read(chatsProvider.notifier).refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : '$error';
      });
      return;
    }

    try {
      final int callId = await startOutgoingCall(
        ref: ref,
        chatId: chatId,
        isVideo: widget.isVideo,
      );
      if (!mounted) return;
      context.go('/call/$callId');
    } on CallStartException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.failure == CallStartFailure.permissions
            ? context.l10n.chatCallPermissionRequired
            : context.l10n.chatCallFailed(error);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.l10n.chatCallFailed(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.profileCall)),
      body: PulseScaffoldBody(
        maxWidth: 560,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _loading
                  ? Column(
                      key: const ValueKey<String>('loading'),
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          widget.isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          size: 48,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 20),
                        const AppLoadingIndicator(size: 64),
                        const SizedBox(height: 24),
                        Text(
                          context.l10n.callRedirectStarting(widget.username),
                          style: textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey<String>('error'),
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.error_outline_rounded,
                          size: 56,
                          color: scheme.error,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.l10n.callRedirectFailed,
                          style: textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error ?? context.l10n.directResolverUserNotFoundDesc,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            OutlinedButton(
                              onPressed: () => context.pop(),
                              child: Text(context.l10n.groupBack),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: _resolve,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(context.l10n.commonRetry),
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
}
