import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';

class ChatManageScreen extends ConsumerStatefulWidget {
  const ChatManageScreen({required this.chatId, super.key});

  final int chatId;

  @override
  ConsumerState<ChatManageScreen> createState() => _ChatManageScreenState();
}

class _ChatManageScreenState extends ConsumerState<ChatManageScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _usernameController;
  bool _commentsEnabled = true;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final chat = ref.read(chatByIdProvider(widget.chatId));
    _nameController = TextEditingController(text: chat?.name ?? '');
    _descController = TextEditingController(text: chat?.description ?? '');
    _usernameController = TextEditingController(text: chat?.username ?? '');
    _commentsEnabled = chat?.commentsEnabled ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .updateChat(
            widget.chatId,
            name: _nameController.text.trim(),
            description: _descController.text.trim(),
            username: _usernameController.text.trim().isEmpty
                ? null
                : _usernameController.text.trim(),
            commentsEnabled: _commentsEnabled,
          );
      await ref.read(chatsProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.groupManageChatUpdated)),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadAvatar() async {
    if (_uploadingAvatar) return;
    final FilePickerResult? picked = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;

    final Uint8List? bytes = picked.files.first.bytes;
    if (bytes == null || bytes.isEmpty) return;

    final String filename = picked.files.first.name.isNotEmpty
        ? picked.files.first.name
        : 'avatar.jpg';

    setState(() => _uploadingAvatar = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .uploadChatAvatar(widget.chatId, bytes, filename);
      await ref.read(chatsProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.groupManageAvatarUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _leaveChat() async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.groupManageLeaveTitle,
      subtitle: context.l10n.groupManageLeaveBody,
      confirmLabel: context.l10n.groupManageLeave,
      cancelLabel: context.l10n.commonCancel,
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (confirmed != true) return;

    try {
      await ref.read(chatRepositoryProvider).leaveChat(widget.chatId);
      await ref.read(chatsProvider.notifier).refresh();
      if (!mounted) return;
      context.go('/main/chats');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
    }
  }

  Future<void> _copyMeta(String title, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.chatManageCopied(title))));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final chat = ref.watch(chatByIdProvider(widget.chatId));
    final bool isChannel = chat?.chatType == 'channel';
    final bool isPublic = (chat?.username ?? '').trim().isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool? confirm = await showAppConfirmDialog(
          context: context,
          title: context.l10n.commonDiscardChanges,
          subtitle: context.l10n.commonDiscardChangesDesc,
          confirmLabel: context.l10n.commonDiscardChangesConfirm,
          cancelLabel: context.l10n.commonCancel,
        );
        if (confirm == true && mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.l10n.groupManageTitle(chat?.name ?? context.l10n.tabChats),
          ),
        ),
        body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenHorizontalPadding,
            vertical: 12,
          ),
          children: <Widget>[
            _panel(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      PulseAvatar(
                        radius: 34,
                        name: chat?.name ?? 'Chat',
                        avatarUrl: chat?.avatarUrl,
                        fallbackColor: scheme.primaryContainer,
                        textColor: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              chat?.name ?? 'Chat',
                              style: textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                 _metaPill(
                                  context,
                                  icon: isChannel
                                      ? Icons.campaign_rounded
                                      : Icons.groups_rounded,
                                  label: isChannel ? context.l10n.chatManageChannel : context.l10n.chatManageGroup,
                                ),
                                _metaPill(
                                  context,
                                  icon: isPublic
                                      ? Icons.public_rounded
                                      : Icons.lock_rounded,
                                  label: isPublic
                                      ? context.l10n.groupPublic
                                      : context.l10n.groupPrivate,
                                ),
                                _metaPill(
                                  context,
                                  icon: Icons.people_alt_rounded,
                                  label:
                                      '${chat?.membersCount ?? 0} ${context.l10n.chatMembers.toLowerCase()}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _uploadingAvatar ? null : _uploadAvatar,
                          icon: const Icon(Icons.image_rounded),
                          label: Text(
                            _uploadingAvatar
                                ? context.l10n.groupManageUploading
                                : context.l10n.groupManageChangeAvatar,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/chat/${widget.chatId}/members'),
                          icon: const Icon(Icons.group_rounded),
                          label: Text(context.l10n.chatMembers),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _panel(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.groupManageIdentity,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                   TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.chatManageName,
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.l10n.chatManageDescription,
                      prefixIcon: Icon(Icons.description_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: isChannel
                          ? context.l10n.groupPublicUsername
                          : context.l10n.groupPublicUsername,
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                ],
              ),
            ),
            if (isChannel) ...<Widget>[
              const SizedBox(height: 12),
              _panel(
                context,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.l10n.chatComments,
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.groupEnableCommentsSubtitle,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _commentsEnabled,
                      onChanged: (bool value) =>
                          setState(() => _commentsEnabled = value),
                    ),
                  ],
                ),
              ),
            ],
            if ((chat?.inviteLink ?? '').isNotEmpty ||
                (chat?.shareLink ?? '').isNotEmpty ||
                chat?.commentsChatId != null) ...<Widget>[
              const SizedBox(height: 12),
              _panel(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.groupManageLinks,
                      style: textTheme.titleLarge,
                    ),
                     if ((chat?.inviteLink ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      _metaRow(
                        context,
                        title: context.l10n.chatManageInviteLink,
                        value: chat!.inviteLink!,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () => _copyMeta(context.l10n.chatManageInviteLink, chat.inviteLink!),
                            icon: const Icon(Icons.copy_rounded),
                            label: Text(context.l10n.chatManageCopyInvite),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _copyMeta(context.l10n.chatManageInviteLink, chat.inviteLink!),
                            icon: const Icon(Icons.share_rounded),
                            label: Text(context.l10n.chatManageShareInvite),
                          ),
                        ],
                      ),
                    ],
                    if ((chat?.shareLink ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      _metaRow(
                        context,
                        title: context.l10n.chatManageShareLink,
                        value: chat!.shareLink!,
                      ),
                    ],
                    if (chat?.commentsChatId != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _metaRow(
                        context,
                        title: context.l10n.chatManageCommentsChatId,
                        value: '${chat!.commentsChatId}',
                        copyable: false,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            PulseButton(
              label: _saving
                  ? context.l10n.commonLoading
                  : context.l10n.groupManageSaveChanges,
              icon: Icons.check_circle_outline_rounded,
              onPressed: _saving ? () {} : _save,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _leaveChat,
              icon: Icon(Icons.exit_to_app_rounded, color: scheme.error),
              label: Text(
                context.l10n.groupManageLeave,
                style: TextStyle(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _panel(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.04),
          scheme.surfaceContainerLow,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.14),
        ),
      ),
      child: child,
    );
  }

  Widget _metaPill(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
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

  Widget _metaRow(
    BuildContext context, {
    required String title,
    required String value,
    bool copyable = true,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(value, style: textTheme.bodyMedium),
            ],
          ),
        ),
        if (copyable)
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(context.l10n.chatManageCopied(title))));
            },
            icon: Icon(Icons.copy_rounded, color: scheme.primary),
            tooltip: context.l10n.chatManageCopy,
          ),
      ],
    );
  }
}
