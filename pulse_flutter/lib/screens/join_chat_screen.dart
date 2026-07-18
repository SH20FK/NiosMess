import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/invite_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';

class JoinChatScreen extends ConsumerStatefulWidget {
  const JoinChatScreen({this.initialSlug, super.key});

  final String? initialSlug;

  @override
  ConsumerState<JoinChatScreen> createState() => _JoinChatScreenState();
}

class _JoinChatScreenState extends ConsumerState<JoinChatScreen> {
  final TextEditingController _slugController = TextEditingController();

  ApiInvitePreview? _preview;
  bool _loadingPreview = false;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    final String initial = (widget.initialSlug ?? '').trim();
    if (initial.isNotEmpty) {
      _slugController.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPreview();
      });
    }
  }

  @override
  void dispose() {
    _slugController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    if (_loadingPreview) return;

    final String raw = _slugController.text.trim();
    if (raw.isEmpty) {
      setState(() => _preview = null);
      return;
    }

    setState(() {
      _loadingPreview = true;
      _preview = null;
    });

    try {
      final ApiInvitePreview? preview = await ref
          .read(chatRepositoryProvider)
          .getInvitePreview(raw);
      if (!mounted) return;
      setState(() => _preview = preview);
      if (preview == null) {
        AppToast.showInfo(context, context.l10n.groupInvitePreviewNotFound);
      }
    } catch (error) {
      if (!mounted) return;
      final String message = error is ApiException
          ? error.message
          : context.l10n.groupInviteFailedLoad('$error');
      AppToast.showError(context, message);
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _join() async {
    final AuthState auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      if (!mounted) return;
      AppToast.showInfo(context, context.l10n.groupSignInToJoin);
      context.push('/login');
      return;
    }

    final String raw = _slugController.text.trim();
    if (raw.isEmpty || _joining) return;

    setState(() => _joining = true);
    try {
      final result = await ref.read(chatRepositoryProvider).joinBySlug(raw);
      if (!mounted) return;
      if (result == null || result.chatId <= 0) {
        throw ApiException(statusCode: 0, message: 'Could not join chat');
      }
      await ref.read(chatsProvider.notifier).refresh();
      if (!mounted) return;
      context.replace('/chat/${result.chatId}');
      AppToast.showSuccess(context, result.message);
    } catch (error) {
      if (!mounted) return;
      final String message = error is ApiException
          ? error.message
          : context.l10n.groupJoinFailed('$error');
      AppToast.showError(context, message);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.groupJoinTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenHorizontalPadding,
            vertical: 14,
          ),
          children: <Widget>[
            Text(
              context.l10n.groupJoinHeadline,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.groupJoinSubtitle,
              style: textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.groupInviteLinkOrSlug,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _slugController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _loadPreview(),
                    decoration: InputDecoration(
                      hintText: 'https://ni-os.ru/join/work_chat',
                      prefixIcon: const Icon(Icons.link_rounded),
                      suffixIcon: IconButton(
                        onPressed: () async {
                          final ClipboardData? data = await Clipboard.getData(
                            'text/plain',
                          );
                          final String text = (data?.text ?? '').trim();
                          if (text.isEmpty) return;
                          _slugController.text = text;
                          await _loadPreview();
                        },
                        icon: const Icon(Icons.content_paste_rounded),
                        tooltip: context.l10n.commonPasteFromClipboard,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PulseButton(
                    label: _loadingPreview
                        ? context.l10n.commonLoading
                        : context.l10n.groupPreviewInvite,
                    icon: Icons.visibility_rounded,
                    onPressed: _loadingPreview ? () {} : _loadPreview,
                  ),
                ],
              ),
            ),
            if (_preview != null) ...<Widget>[
              const SizedBox(height: 14),
              _previewCard(context, _preview!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _previewCard(BuildContext context, ApiInvitePreview preview) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isChannel = preview.chatType == 'channel';

    Widget metaPill(IconData icon, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: textTheme.labelLarge),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              PulseAvatar(
                radius: 30,
                name: preview.name,
                avatarUrl: preview.avatarUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(preview.name, style: textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      isChannel
                          ? context.l10n.groupChannelPreview
                          : context.l10n.groupGroupPreview,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              metaPill(
                isChannel ? Icons.campaign_rounded : Icons.groups_rounded,
                isChannel
                    ? context.l10n.groupTypeChannel
                    : context.l10n.groupTypeGroup,
              ),
              metaPill(
                Icons.people_alt_rounded,
                '${preview.membersCount} ${context.l10n.chatMembers.toLowerCase()}',
              ),
            ],
          ),
          if (preview.description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.54),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                preview.description.trim(),
                style: textTheme.bodyLarge,
              ),
            ),
          ],
          if ((preview.inviteLink ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            SelectableText(
              preview.inviteLink!,
              style: textTheme.bodySmall?.copyWith(color: scheme.primary),
            ),
          ],
          const SizedBox(height: 14),
          PulseButton(
            label: _joining
                ? context.l10n.groupJoining
                : context.l10n.groupJoinChat,
            icon: Icons.login_rounded,
            onPressed: _joining ? () {} : _join,
          ),
        ],
      ),
    );
  }
}
