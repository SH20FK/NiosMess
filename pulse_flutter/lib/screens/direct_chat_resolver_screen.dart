import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class DirectChatResolverScreen extends ConsumerStatefulWidget {
  const DirectChatResolverScreen({
    required this.username,
    this.isSecret = false,
    super.key,
  });

  final String username;
  final bool isSecret;

  @override
  ConsumerState<DirectChatResolverScreen> createState() =>
      _DirectChatResolverScreenState();
}

class _DirectChatResolverScreenState
    extends ConsumerState<DirectChatResolverScreen> {
  bool _loading = true;
  String? _error;
  final E2eeService _e2ee = E2eeService();

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

    try {
      String? publicKey;
      if (widget.isSecret) {
        publicKey = await _e2ee.getPublicKeyBase64();
        if (publicKey != null && publicKey.isNotEmpty) {
          try {
            await ref.read(authRepositoryProvider).setPublicKey(publicKey);
          } catch (_) {}
        }
      }

      final result = await ref
          .read(chatRepositoryProvider)
          .openDirectChatByUsername(
            widget.username,
            isSecret: widget.isSecret,
            publicKey: publicKey,
          );
      if (result == null || result.chatId <= 0) {
        throw ApiException(statusCode: 0, message: 'Could not resolve dialog.');
      }
      await ref.read(chatsProvider.notifier).refresh();
      if (!mounted) return;
      context.go('/chat/${result.chatId}');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSecret ? context.l10n.directResolverSecretTitle : context.l10n.appName),
      ),
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
                          widget.isSecret ? Icons.lock_rounded : Icons.chat_rounded,
                          size: 48,
                          color: widget.isSecret ? Colors.green : scheme.primary,
                        ),
                        const SizedBox(height: 20),
                        const AppLoadingIndicator(size: 64),
                        const SizedBox(height: 24),
                        Text(
                          context.l10n.directResolverResolving(widget.username),
                          style: textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isSecret
                              ? context.l10n.directResolverSecretEstablishing
                              : context.l10n.directResolverPreparing,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
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
                        Text(context.l10n.directResolverUserNotFound, style: textTheme.headlineSmall),
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
