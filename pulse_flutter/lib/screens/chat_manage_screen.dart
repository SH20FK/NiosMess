import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
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
  String? _inviteLink;
  String? _shareLink;
  bool _canRotate = false;
  bool _rotatingLink = false;

  @override
  void initState() {
    super.initState();
    final chat = ref.read(chatByIdProvider(widget.chatId));
    _nameController = TextEditingController(text: chat?.name ?? '');
    _descController = TextEditingController(text: chat?.description ?? '');
    _usernameController = TextEditingController(text: chat?.username ?? '');
    _commentsEnabled = chat?.commentsEnabled ?? false;
    _inviteLink = chat?.inviteLink;
    _shareLink = chat?.shareLink;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInviteLink());
  }

  Future<void> _loadInviteLink() async {
    try {
      final Map<String, dynamic>? res =
          await ref.read(chatRepositoryProvider).getInviteLink(widget.chatId);
      if (res != null && mounted) {
        setState(() {
          _inviteLink = res['invite_link'] as String? ?? _inviteLink;
          _shareLink = res['share_link'] as String? ?? _shareLink;
          _canRotate = res['can_rotate'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _rotateInviteLink() async {
    if (_rotatingLink) return;
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Перевыпустить ссылку?',
      subtitle:
          'Предыдущая ссылка перестанет работать немедленно. Новые участники не смогут присоединиться по старой ссылке.',
      confirmLabel: 'Перевыпустить',
      cancelLabel: context.l10n.commonCancel,
      destructive: true,
      icon: Icons.link_off_rounded,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _rotatingLink = true);
    try {
      final Map<String, dynamic>? res =
          await ref.read(chatRepositoryProvider).rotateInviteLink(widget.chatId);
      if (res != null && mounted) {
        setState(() {
          _inviteLink = res['invite_link'] as String? ?? _inviteLink;
          _shareLink = res['share_link'] as String? ?? _shareLink;
        });
        await ref.read(chatsProvider.notifier).refresh();
        if (mounted) {
          AppToast.showSuccess(context, 'Ссылка успешно обновлена');
        }
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, e);
    } finally {
      if (mounted) setState(() => _rotatingLink = false);
    }
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
      final chat = ref.read(chatByIdProvider(widget.chatId));
      final bool isChannel = chat?.chatType == 'channel';
      final bool isGroup = chat?.chatType == 'group';
      final bool isPrivate = chat?.isPrivate ?? false;

      final String? targetUsername = (isGroup && isPrivate)
          ? null
          : (_usernameController.text.trim().isEmpty
              ? null
              : _usernameController.text.trim());

      await ref
          .read(chatRepositoryProvider)
          .updateChat(
            widget.chatId,
            name: _nameController.text.trim(),
            description: _descController.text.trim(),
            username: targetUsername,
            commentsEnabled: isChannel ? _commentsEnabled : null,
          );
      await ref.read(chatsProvider.notifier).refresh();
      if (!mounted) return;
      AppToast.showSuccess(context, context.l10n.groupManageChatUpdated);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadAvatar() async {
    if (_uploadingAvatar) return;
    final List<PlatformFile> picked = await FilePicker.pickFiles(
      type: FileType.image,
    );
    if (picked.isEmpty || !mounted) return;

    final Uint8List bytes = await picked.first.readAsBytes();
    if (bytes.isEmpty) return;

    final String filename = picked.first.name.isNotEmpty
        ? picked.first.name
        : 'avatar.jpg';

    setState(() => _uploadingAvatar = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .uploadChatAvatar(widget.chatId, bytes, filename);
      await ref.read(chatsProvider.notifier).refresh();
      if (!mounted) return;
      AppToast.showSuccess(context, context.l10n.groupManageAvatarUpdated);
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e);
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
      AppToast.showError(context, e);
    }
  }

  Future<void> _copyMeta(String title, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    AppToast.showInfo(context, context.l10n.chatManageCopied(title));
  }

  bool _hasChanges(dynamic chat) {
    if (chat == null) return false;
    final bool isChannel = chat.chatType == 'channel';
    final bool isGroup = chat.chatType == 'group';
    final bool isPrivate = chat.isPrivate ?? false;
    final bool canHaveUsername = !isGroup || !isPrivate;

    return _nameController.text != (chat.name ?? '') ||
        _descController.text != (chat.description ?? '') ||
        (canHaveUsername && _usernameController.text != (chat.username ?? '')) ||
        (isChannel && _commentsEnabled != (chat.commentsEnabled ?? false));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final chat = ref.watch(chatByIdProvider(widget.chatId));
    final bool isChannel = chat?.chatType == 'channel';
    final bool isGroup = chat?.chatType == 'group';
    final bool isPrivate = chat?.isPrivate ?? false;
    final bool isPublic = (chat?.username ?? '').trim().isNotEmpty;
    final bool hasChanges = _hasChanges(chat);
    final String rawInvite = _inviteLink ?? chat?.inviteLink ?? '';
    final String effectiveInviteLink = AppUrlLauncher.formatCanonicalInviteUrl(rawInvite);
    final String rawShare = _shareLink ?? chat?.shareLink ?? '';
    final String effectiveShareLink = AppUrlLauncher.formatCanonicalInviteUrl(rawShare);

    final bool canRoutePop = ModalRoute.of(context)?.canPop ?? false;
    return PopScope(
      canPop: canRoutePop && !hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!hasChanges) {
          if (canRoutePop) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          } else {
            try {
              context.go('/main/chats');
            } catch (_) {
              Navigator.maybePop(context);
            }
          }
          return;
        }
        final bool? confirm = await showAppConfirmDialog(
          context: context,
          title: context.l10n.commonDiscardChanges,
          subtitle: context.l10n.commonDiscardChangesDesc,
          confirmLabel: context.l10n.commonDiscardChangesConfirm,
          cancelLabel: context.l10n.commonCancel,
        );
        if (confirm == true && context.mounted) {
          if (canRoutePop) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          } else {
            try {
              context.go('/main/chats');
            } catch (_) {
              Navigator.maybePop(context);
            }
          }
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
                        name: chat?.name ?? context.l10n.commonChat,
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
                              chat?.name ?? context.l10n.commonChat,
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
                  if (!isGroup || !isPrivate) ...<Widget>[
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
            if (effectiveInviteLink.isNotEmpty ||
                effectiveShareLink.isNotEmpty ||
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
                     if (effectiveInviteLink.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      _metaRow(
                        context,
                        title: context.l10n.chatManageInviteLink,
                        value: effectiveInviteLink,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () => _copyMeta(context.l10n.chatManageInviteLink, effectiveInviteLink),
                            icon: const Icon(Icons.copy_rounded),
                            label: Text(context.l10n.chatManageCopyInvite),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _copyMeta(context.l10n.chatManageInviteLink, effectiveInviteLink),
                            icon: const Icon(Icons.share_rounded),
                            label: Text(context.l10n.chatManageShareInvite),
                          ),
                          if (_canRotate)
                            OutlinedButton.icon(
                              onPressed: _rotatingLink ? null : _rotateInviteLink,
                              icon: _rotatingLink
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(Icons.sync_rounded, color: scheme.error),
                              label: Text(
                                'Перевыпустить',
                                style: TextStyle(color: scheme.error),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (effectiveShareLink.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      _metaRow(
                        context,
                        title: context.l10n.chatManageShareLink,
                        value: effectiveShareLink,
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
              onPressed: _saving ? null : _save,
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
              AppToast.showInfo(context, context.l10n.chatManageCopied(title));
            },
            icon: Icon(Icons.copy_rounded, color: scheme.primary),
            tooltip: context.l10n.chatManageCopy,
          ),
      ],
    );
  }
}
