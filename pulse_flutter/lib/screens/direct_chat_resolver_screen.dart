import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/navigation/direct_chat_navigator.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';

/// Resolves direct chat by username and navigates immediately into it,
/// falling back to the user's public profile if no direct chat exists.
class DirectChatResolverScreen extends ConsumerStatefulWidget {
  const DirectChatResolverScreen({required this.username, super.key});

  final String username;

  @override
  ConsumerState<DirectChatResolverScreen> createState() =>
      _DirectChatResolverScreenState();
}

class _DirectChatResolverScreenState
    extends ConsumerState<DirectChatResolverScreen> {
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveChat());
  }

  Future<void> _resolveChat() async {
    if (_resolved || !mounted) return;
    _resolved = true;

    final String cleanUsername = widget.username.trim().startsWith('@')
        ? widget.username.trim().substring(1)
        : widget.username.trim();

    if (cleanUsername.isEmpty) {
      if (mounted) context.go('/main/chats');
      return;
    }

    final int? chatId = await navigateToDirectChat(
      context,
      ref,
      username: cleanUsername,
    );

    if (chatId == null && mounted) {
      context.go('/profile/$cleanUsername');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
      ),
      body: PulseScaffoldBody(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const AppLoadingIndicator(size: 48),
              const SizedBox(height: 16),
              Text(
                context.l10n.deepLinkResolving,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
