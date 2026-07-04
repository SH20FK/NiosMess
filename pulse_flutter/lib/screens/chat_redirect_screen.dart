import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';

class ChatRedirectScreen extends ConsumerStatefulWidget {
  const ChatRedirectScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<ChatRedirectScreen> createState() => _ChatRedirectScreenState();
}

class _ChatRedirectScreenState extends ConsumerState<ChatRedirectScreen> {
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

    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .resolveShortLink(widget.slug);

      if (!mounted) return;

      if (result != null && result.isNotEmpty) {
        context.go(result);
      } else {
        setState(() {
          _loading = false;
          _error = context.l10n.deepLinkNotFound;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('NiosMess')),
      body: PulseScaffoldBody(
        maxWidth: 560,
        child: Center(
          child: _loading
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const AppLoadingIndicator(size: 64),
                    const SizedBox(height: 24),
                    Text(
                      context.l10n.deepLinkResolving,
                      style: textTheme.headlineSmall,
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.link_off_rounded, size: 56, color: scheme.error),
                    const SizedBox(height: 20),
                    Text(
                      _error ?? context.l10n.deepLinkNotFound,
                      style: textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => context.go('/main/chats'),
                      child: Text(context.l10n.groupBack),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
