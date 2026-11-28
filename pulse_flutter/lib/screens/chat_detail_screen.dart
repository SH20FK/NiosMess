import 'package:pulse_flutter/providers/chat_productivity_provider.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:pulse_flutter/core/clipboard/pasted_image.dart';
import 'package:pulse_flutter/widgets/chat/pasted_images_dialog.dart';
import 'package:pulse_flutter/providers/encrypted_draft_sync_provider.dart';
import 'package:pulse_flutter/widgets/chat/file_request_action.dart';
import 'package:pulse_flutter/widgets/chat/interactive_composer.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/services/secret_chat/secret_chat_engine.dart';
import 'package:pulse_flutter/widgets/chat/chat_scroll_coordinator.dart';
import 'package:pulse_flutter/widgets/chat/e2ee_verification_sheet.dart';
import 'package:pulse_flutter/widgets/chat/reaction_picker_sheet.dart';
import 'package:pulse_flutter/widgets/chat/report_message_sheet.dart';
import 'package:pulse_flutter/widgets/chat/ai_actions_sheet.dart';
import 'dart:async';
import 'package:pulse_flutter/core/services/desktop_pasteboard_service.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/theme/nios_chroma.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_ai_rewrite_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_detail.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_attachment_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_composer_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_draft_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_message_action_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_message_presenter.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_media_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_screen_lifecycle.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_send_controller.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/inline_query_provider.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/desktop_chat_provider.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:pulse_flutter/providers/typing_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/repositories/report_repository.dart';
import 'package:pulse_flutter/widgets/m3_file_picker_bottom_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
import 'package:pulse_flutter/core/utils/screen_security_service.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/repositories/ai_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({
    required this.chatId,
    this.highlightMessageId,
    this.isDesktopSplit = false,
    super.key,
  });

  final String chatId;
  final int? highlightMessageId;
  final bool isDesktopSplit;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = CustomEmojiTextController();
  late final ChatScrollCoordinator _scrollCoordinator;
  late final FocusNode _inputFocusNode;

  // Cache providers that may be needed in dispose()
  SecretDraftSink? _secretDraftSink;

  late final ChatDraftController _draft;
  late final ChatMediaController _media;
  late final ChatMessageActionController _actions;
  late final ChatComposerController _composer;
  late final ChatSendController _send;
  late final ChatAttachmentController _attachments;

  int? get _replyToMessageId => _composer.replyToMessageId;
  String? get _replyPreviewText => _composer.replyPreviewText;
  int? get _editingMessageId => _composer.editingMessageId;
  bool get _isAiProcessing => _composer.isAiProcessing;

  late final ChatAiRewriteController _aiRewrite;

  late final ChatScreenLifecycle _lifecycle;

  int? get _chatId => int.tryParse(widget.chatId);

  ChatMessagePresenter get _presenter =>
      ChatMessagePresenter(context.l10n);

  void _goBack() {
    if (kIsWeb) {
      context.go("/main/chats");
      return;
    }
    if (widget.isDesktopSplit) {
      ref.read(desktopSelectedChatProvider.notifier).setSelectedChat(null);
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    try {
      if (context.canPop()) {
        context.pop();
        return;
      }
    } catch (_) {}
    try {
      context.go('/main/chats');
    } catch (_) {
      Navigator.maybePop(context);
    }
  }

  /// Everything the lifecycle needs from `ref`/`context`, wired as live
  /// getters and closures: the class itself holds neither.
  ChatScreenLifecycle _createLifecycle() => ChatScreenLifecycle(
    ports: ChatLifecyclePorts(
      chatId: _chatId,
      isMounted: () => mounted,
      isSecret: () => _isSecret,
      chatIsSecret: () {
        final int? id = _chatId;
        if (id == null) return null;
        return ref.read(chatByIdProvider(id))?.isSecret;
      },
      onSecretDetected: () {
        _isSecret = true;
        _bindSecret(ref.read(secretChatCoordinatorProvider).value);
      },
      setCanPersistOrdinaryDraft: (bool value) =>
          _canPersistOrdinaryDraft = value,
      haptics: () => ref.read(uiSettingsProvider).haptics,
      markMessagesRead: () {
        final int? id = _chatId;
        if (id == null) return Future<void>.value();
        return ref.read(chatMessagesProvider(id).notifier).markRead();
      },
      markChatAsRead: () {
        final int? id = _chatId;
        if (id == null) return;
        ref.read(chatsProvider.notifier).markChatAsRead(id);
      },
      refreshMessages: () {
        final int? id = _chatId;
        if (id == null) return Future<void>.value();
        return ref.read(chatMessagesProvider(id).notifier).refresh();
      },
      followingLatest: () {
        final int? id = _chatId;
        if (id == null) return false;
        return ref
            .read(chatMessagesProvider(id).notifier)
            .window
            .followingLatest;
      },
      fetchChat: (int id) => ref.read(chatRepositoryProvider).getChat(id),
      upsertChat: (ApiChatSummary chat) =>
          ref.read(chatsProvider.notifier).upsertChat(chat),
      loadOlderPage: () {
        final int? id = _chatId;
        if (id == null) return Future<int>.value(0);
        return ref
            .read(chatMessagesProvider(id).notifier)
            .loadOlder(pageSize: 50);
      },
      onLoadOlderError: (Object error) {
        if (mounted) AppToast.showError(context, error);
      },
      clearInlineQuery: () => ref.read(inlineQueryProvider.notifier).clear(),
      scrimColor: () => Theme.of(context).colorScheme.scrim,
      insertOverlay: (OverlayEntry entry) =>
          Overlay.of(context, rootOverlay: true).insert(entry),
      removeOverlay: (OverlayEntry entry) => entry.remove(),
      onInfo: (String message) {
        if (mounted) AppToast.showInfo(context, message);
      },
      sendScreenshotNotice: () {
        final int? id = _chatId;
        if (id == null) return;
        ref
            .read(chatMessagesProvider(id).notifier)
            .send('📷 Снимок экрана был зафиксирован');
      },
      onScrollToBottom: () => _scrollCoordinator.scrollToBottom(),
      beforeSecureFlag: () {
        final int? id = _chatId;
        if (id == null) return;
        _scrollCoordinator.setHasNewerHistory(
          ref.read(chatHistoryWindowProvider(id)).hasNewer,
        );
        // Secure flag first: restoring a draft needs `_isSecret` to be current
        // so a secret chat reads the engine, never DraftStorage.
        if (ref.read(chatByIdProvider(id)) != null) {
          unawaited(_draft.restore());
        }
      },
      disposeControllers: _disposeControllers,
    ),
  );

  /// The controllers' teardown, run from inside
  /// `ChatScreenLifecycle.dispose()` so the secure flag can stay the last act.
  void _disposeControllers() {
    _aiRewrite.dispose();
    _scrollCoordinator.dispose();
    _composer.dispose();
    _send.dispose();
    _attachments.dispose();
    // Cancel the pending debounce, then write the last text: the only chance
    // to persist the final <500 ms of typing.
    _draft.dispose();
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _inputFocusNode.dispose();
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = _createLifecycle()..attach();
    _scrollCoordinator = ChatScrollCoordinator(
      onJumpError: (error) {
        if (mounted) {
          AppToast.showError(context, error, onRetry: _lifecycle.scrollToBottom);
        }
      },
      onNearTop: _lifecycle.autoLoadOlderMessages,
      onNearBottom: () {
        final id = _chatId;
        if (id != null) {
          unawaited(
            ref.read(chatMessagesProvider(id).notifier).loadNewer().catchError((
              Object error,
            ) {
              if (mounted) AppToast.showError(context, error);
            }),
          );
        }
      },
      onJumpToLatest: () async {
        final id = _chatId;
        if (id != null) {
          await ref.read(chatMessagesProvider(id).notifier).jumpToLatest();
        }
      },
      onFollowLatestChanged: (atBottom) {
        final id = _chatId;
        if (id != null) {
          ref
              .read(chatMessagesProvider(id).notifier)
              .setFollowingLatest(atBottom);
        }
      },
      onReachedBottom: _lifecycle.onReachedBottom,
    );
    _inputController.addListener(_onInputChanged);
    _inputFocusNode = FocusNode();
    final int? composerChatId = _chatId;
    _composer = ChatComposerController(
      chatId: composerChatId,
      textController: _inputController,
      editMessage: (int id, String text) => ref
          .read(chatMessagesProvider(composerChatId!).notifier)
          .editMessage(id, text),
      identity: () {
        final session = ref.read(authProvider).session;
        return (userId: session?.userId, accessToken: session?.accessToken);
      },
      haptics: () => ref.read(uiSettingsProvider).haptics,
      onError: (Object error) {
        if (mounted) AppToast.showError(context, error);
      },
      info: (String message) {
        if (mounted) AppToast.showInfo(context, message);
      },
      myUserId: () => ref.read(authProvider).session?.userId ?? -1,
      messages: () {
        final int? id = _chatId;
        if (id == null) return const <ApiMessage>[];
        return ref.read(chatMessagesProvider(id)).value ?? const <ApiMessage>[];
      },
      replyAuthor: (ApiMessage message) => _presenter.resolveReplyAuthor(
        message,
        myUserId: ref.read(authProvider).session?.userId ?? -1,
        chatName: (ref.read(chatByIdProvider(_chatId ?? 0))?.name ?? '').trim(),
      ),
      replySnippet: (ApiMessage message) =>
          _presenter.resolveReplySnippet(message),
    );
    _send = ChatSendController(
      chatId: () => _chatId,
      textController: _inputController,
      l10n: () => context.l10n,
      chat: (int id) => ref.read(chatByIdProvider(id)),
      ensureChats: () => ref.read(chatsProvider.future),
      messages: () {
        final int? id = _chatId;
        if (id == null) return const <ApiMessage>[];
        return ref.read(chatMessagesProvider(id)).asData?.value ??
            const <ApiMessage>[];
      },
      myUserId: () => ref.read(authProvider).profile?.id,
      isAccountSpamBlocked: () =>
          ref.read(authProvider).profile?.isRestrictedBySpamBlock ?? false,
      isSecret: () => _isSecret,
      isUserBlocked: (int userId) =>
          ref.read(privacyProvider).isUserBlocked(userId),
      haptics: () => ref.read(uiSettingsProvider).haptics,
      replyToMessageId: () => _replyToMessageId,
      replyPreviewText: () => _replyPreviewText,
      sendSecret: (int chatId, String text, {int? replyToId}) => ref
          .read(chatMessagesProvider(chatId).notifier)
          .send(text, replyToId: replyToId),
      send:
          (
            int chatId,
            String text, {
            int? replyToId,
            void Function()? onLocalSaved,
          }) => ref
              .read(chatMessagesProvider(chatId).notifier)
              .send(text, replyToId: replyToId, onLocalSaved: onLocalSaved),
      clearReply: _composer.clearReply,
      restoreReply: (int replyId, String preview) {
        _composer.notifier.value = _composer.notifier.value.copyWith(
          replyToMessageId: () => replyId,
          replyPreviewText: () => preview,
        );
      },
      scrollToBottom: _lifecycle.scrollToBottom,
      markBlockedByUser: (int chatId) =>
          ref.read(chatsProvider.notifier).setChatBlockedByUser(chatId, true),
      onError: (Object error) {
        if (mounted) AppToast.showError(context, error);
      },
    );
    _attachments = ChatAttachmentController(
      chatId: () => _chatId,
      textController: _inputController,
      l10n: () => context.l10n,
      chat: (int id) => ref.read(chatByIdProvider(id)),
      ensureChats: () => ref.read(chatsProvider.future),
      isSecret: () => _isSecret,
      isEditingMessage: () => _editingMessageId != null,
      identity: () {
        final auth = ref.read(authProvider);
        return (
          userId: auth.session?.userId ?? -1,
          username: auth.session?.username ?? '',
          displayName: auth.profile?.displayName.trim() ?? '',
        );
      },
      replyToMessageId: () => _replyToMessageId,
      enqueueSecretFile:
          (
            int chatId,
            String filePath, {
            required String filename,
            required String type,
            required String text,
            int? replyToId,
          }) async {
            final secret = await ref.read(secretChatCoordinatorProvider.future);
            if (secret == null) throw StateError('Secret storage unavailable');
            await secret.enqueueAttachmentFile(
              chatId,
              filePath,
              filename: filename,
              type: type,
              text: text,
              replyToId: replyToId,
            );
          },
      enqueueSecretBytes:
          (
            int chatId,
            Uint8List bytes, {
            required String filename,
            required String type,
            required String text,
            int? replyToId,
          }) async {
            final secret = await ref.read(secretChatCoordinatorProvider.future);
            if (secret == null) throw StateError('Secret storage unavailable');
            await secret.enqueueAttachment(
              chatId,
              bytes,
              filename: filename,
              type: type,
              text: text,
              replyToId: replyToId,
            );
          },
      addOptimistic: (int chatId, ApiMessage message) => ref
          .read(chatMessagesProvider(chatId).notifier)
          .addOptimisticLocalMessage(message),
      enqueueUpload:
          ({
            required String localId,
            required int chatId,
            required String filePath,
            required Uint8List? bytes,
            required String filename,
            required String mediaSubtype,
            required int fileSize,
            required String text,
            required int? replyToId,
          }) => ref
              .read(uploadQueueProvider.notifier)
              .enqueue(
                localId: localId,
                chatId: chatId,
                filePath: filePath,
                bytes: bytes,
                filename: filename,
                mediaSubtype: mediaSubtype,
                fileSize: fileSize,
                text: text,
                replyToId: replyToId,
              ),
      clearReply: _composer.clearReply,
      scrollToBottom: _lifecycle.scrollToBottom,
      showError: (Object error) {
        if (mounted) AppToast.showError(context, error);
      },
      pickFiles:
          (Future<void> Function(String kind) onOpenInteractive) =>
              showM3FilePicker(
                context,
                onOpenInteractive: (String kind) {
                  unawaited(onOpenInteractive(kind));
                },
              ),
      showInteractive: (String kind) => showInteractiveComposer(context, kind),
      sendInteractive: (int targetChatId, String content) => ref
          .read(chatMessagesProvider(targetChatId).notifier)
          .send(content, requestAi: false),
      showImagesDialog:
          ({
            required List<PastedImage> images,
            required String caption,
            required Future<void> Function(
              List<PastedImage> images,
              String caption,
            )
            onSendAlbum,
            required Future<void> Function(
              PastedImage image,
              String caption,
            )
            onSend,
          }) => showPastedImagesDialog(
            context,
            images: images,
            caption: caption,
            onSendAlbum: onSendAlbum,
            onSend: onSend,
          ),
      requestInputFocus: () => _inputFocusNode.requestFocus(),
      isDesktop: () => DesktopPasteboardService.isDesktop,
      readClipboardFiles: () =>
          DesktopPasteboardService.getClipboardFilesOrImage(),
      sendSticker: (int chatId, int stickerId, {int? replyToId}) => ref
          .read(chatMessagesProvider(chatId).notifier)
          .sendSticker(stickerId, replyToId: replyToId),
    );

    _aiRewrite = ChatAiRewriteController(
      vsync: this,
      textController: _inputController,
      reduceMotion: () => context.reduceMotion,
      streamRequest: (AiRewriteRequest request) async =>
          ref.read(aiRepositoryProvider).streamRewriteText(request: request),
      onBusyChanged: (bool busy) {
        _composer.notifier.value = _composer.notifier.value.copyWith(
          isAiProcessing: busy,
        );
      },
      onError: (Object error) {
        if (mounted) AppToast.showError(context, error);
      },
      onSound: (SoundEvent event) =>
          ref.read(appSoundProvider).playEvent(event),
    );
    _draft = ChatDraftController(
      chatId: _chatId,
      textController: _inputController,
      // Read once here: `dispose()` saves the draft and must not touch `ref`.
      storage: ref.read(draftStorageProvider),
      isSecret: () => _isSecret,
      canPersistOrdinaryDraft: () => _canPersistOrdinaryDraft,
      secretSink: () => _secretDraftSink,
      ensureSecretReady: () async =>
          _bindSecret(await ref.read(secretChatCoordinatorProvider.future)),
      onBannerChanged: () {
        if (mounted) setState(() {});
      },
      onError: (Object error) => debugPrint('Draft save failed: $error'),
    );
    _actions = ChatMessageActionController(
      ports: ChatDetailPorts(
        read: <T>(ProviderListenable<T> provider) => ref.read(provider),
        l10n: () => context.l10n,
        chatId: () => _chatId,
        onError: (Object error) {
          if (mounted) AppToast.showError(context, error);
        },
        onSuccess: (String message) {
          if (mounted) AppToast.showSuccess(context, message);
        },
        onInfo: (String message) {
          if (mounted) AppToast.showInfo(context, message);
        },
        push: (String location, {Object? extra}) {
          context.push(location, extra: extra);
        },
        scrollToBottom: _lifecycle.scrollToBottom,
        haptics: () => ref.read(uiSettingsProvider).haptics,
      ),
      confirmDelete: () async =>
          await showAppConfirmDialog(
            context: context,
            title: context.l10n.chatDeleteMessageTitle,
            subtitle: context.l10n.chatDeleteMessageBody,
            confirmLabel: context.l10n.commonDelete,
            cancelLabel: context.l10n.commonCancel,
            destructive: true,
            icon: Icons.delete_outline_rounded,
          ) ??
          false,
      deleteMessage: (int messageId) {
        final int? id = _chatId;
        if (id == null) return Future<void>.value();
        return ref
            .read(chatMessagesProvider(id).notifier)
            .deleteMessage(messageId);
      },
      toggleReaction: (int messageId, String emoji) {
        final int? id = _chatId;
        if (id == null) return Future<void>.value();
        return ref
            .read(chatMessagesProvider(id).notifier)
            .toggleReaction(messageId, emoji);
      },
      pickReaction: (ApiMessage message) =>
          showReactionPickerSheet(context, message: message),
      pickReportReason: (ApiMessage message) => showReportMessageSheet(context),
      sendText: (int targetChatId, String text) =>
          ref.read(chatMessagesProvider(targetChatId).notifier).send(text),
      saveToSaved: (ApiMessage message, String text) => ref
          .read(chatProductivityRepositoryProvider)
          .saveMessageText(message, text),
      report:
          ({
            required int chatId,
            required int reportedUserId,
            required List<int> messageIds,
            required ApiMessage selectedMessage,
            required String reason,
          }) => ref
              .read(reportRepositoryProvider)
              .report(
                chatId: chatId,
                reportedUserId: reportedUserId,
                messageIds: messageIds,
                selectedMessage: selectedMessage,
                reason: reason,
              ),
      showScheduledComposer:
          ({
            required int chatId,
            required String text,
            required ApiMessage reminder,
          }) => showScheduledMessageComposer(
            context,
            ref,
            chatId: chatId,
            reminder: reminder,
            text: text,
          ),
      uploadAndSend: _attachments.uploadAndSend,
      fetchMedia:
          ({required String filePath, Uint8List? e2eeFileKey}) =>
              WsMediaFetcher.fetchAndDecryptMedia(
                filePath: filePath,
                wsClient: ref.read(webSocketClientProvider),
                e2eeFileKey: e2eeFileKey,
              ),
      setReply: _composer.setReply,
      beginEdit: _composer.editMessage,
      requestFile: (ApiMessage message) => requestChatFile(ref, message),
      requestForward: (ApiMessage message) =>
          _actions.forwardMessage(context, message),
    );
    _media = ChatMediaController(
      l10n: () => context.l10n,
      messages: () {
        final int? id = _chatId;
        if (id == null) return const <ApiMessage>[];
        return ref.read(chatMessagesProvider(id)).value ?? const <ApiMessage>[];
      },
      push: (String location, {Object? extra}) {
        context.push(location, extra: extra);
      },
      forward: (ApiMessage message) => _actions.forwardMessage(context, message),
      delete: (ApiMessage message) => _actions.deleteMessage(message),
      wsClient: () => ref.read(webSocketClientProvider),
    );
    _lifecycle.runAfterFirstFrame();
  }

  bool _isSecret = false;
  bool _canPersistOrdinaryDraft = false;

  /// Keeps the engine handle the draft controller saves through in sync with
  /// the coordinator. Never awaited from `dispose()`.
  void _bindSecret(SecretChatCoordinator? coordinator) {
    if (coordinator == null) return;
    _secretDraftSink = _SecretDraftSink(coordinator);
  }

  void _showE2eeVerification() {
    final int? chatId = _chatId;
    if (chatId == null) return;
    AppModal.showSheet(
      context: context,
      showDragHandle: false,
      builder: (_) => E2eeVerificationSheet(chatId: chatId),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    _draft.scheduleSave();
    final bool isEmpty = _inputController.text.trim().isEmpty;
    if (_isSecret ||
        ref.read(chatByIdProvider(_chatId ?? 0))?.isSecret != false) {
      return;
    }
    ref
        .read(inlineQueryProvider.notifier)
        .onInputChanged(chatId: _chatId, text: _inputController.text);
    if (!isEmpty) {
      final int? chatId = _chatId;
      if (chatId != null &&
          ref.read(chatByIdProvider(chatId))?.isSaved != true) {
        ref.read(typingProvider(chatId).notifier).sendTyping();
      }
    }
  }

  Future<void> _processTextWithAi(
    AiAction action, {
    String? targetLanguage,
  }) async {
    if (_isSecret ||
        ref.read(chatByIdProvider(_chatId ?? 0))?.isSecret != false) {
      AppToast.showInfo(context, context.l10n.secretLocalOnly);
      return;
    }
    await _aiRewrite.start(action, targetLanguage: targetLanguage);
  }

  void _cancelAiProcessing() => _aiRewrite.cancel();

  Future<void> _showAiBottomSheet(BuildContext context) async {
    if (_inputController.text.trim().isEmpty) return;
    final (AiAction, String? targetLanguage)? selection =
        await showAiActionsSheet(context);
    if (selection == null) return;
    final (AiAction action, String? targetLanguage) = selection;
    unawaited(_processTextWithAi(action, targetLanguage: targetLanguage));
  }

  String? _replyPreviewFor(ApiMessage message, Map<int, ApiMessage> byId) {
    if (message.replyToId == null) return null;
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final String chatName =
        (ref.read(chatByIdProvider(_chatId ?? 0))?.name ?? '').trim();
    return _presenter.replyPreviewFor(
      message,
      byId,
      myUserId: myUserId,
      chatName: chatName,
    );
  }


  @override
  Widget build(BuildContext context) {
    ref.watch(encryptedDraftSyncProvider);
    final int? chatId = _chatId;
    if (chatId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.chatTitleFallback(0))),
        body: PulseScaffoldBody(
          animatedBackdrop: false,
          maxWidth: 1560,
          child: Center(child: Text(context.l10n.chatInvalidId)),
        ),
      );
    }

    // Secret delivery belongs to the account coordinator, including while this
    // screen is mounted. Metadata changes only update local screen protection.
    ref.listen<bool?>(chatByIdProvider(chatId).select((c) => c?.isSecret), (
      previous,
      isSecret,
    ) {
      if (isSecret == null) return;
      _canPersistOrdinaryDraft = !isSecret;
      if (previous == null) unawaited(_draft.restore());
      if (isSecret != _isSecret) {
        _isSecret = isSecret;
        ScreenSecurityService.setSecureFlag(enabled: isSecret);
      }
    });

    final (String? chatType, String chatName, bool isSecretChat) = ref.watch(
      chatByIdProvider(
        chatId,
      ).select((c) => (c?.chatType, c?.name ?? '', c?.isSecret == true)),
    );

    final bool isSecret = isSecretChat || _isSecret;
    ref.listen<AsyncValue<Map<int, String>>>(liveDraftMapProvider, (
      previous,
      next,
    ) {
      if (isSecret || !next.hasValue || _editingMessageId != null) return;
      _draft.applyRemote(next.value?[chatId] ?? '');
    });
    if (isSecret && !_isSecret) {
      _isSecret = true;
      ScreenSecurityService.setSecureFlag(enabled: true);
    }

    final ColorScheme baseScheme = Theme.of(context).colorScheme;

    final bool isDirect = chatType == 'direct';
    final ColorScheme scheme = (isDirect && NiosChroma.shouldApply())
        ? NiosChroma.resolveChromaScheme(
            userScheme: baseScheme,
            partnerId: chatName.isNotEmpty ? chatName : chatId.toString(),
            chatId: chatId,
          )
        : baseScheme;

    final bool canRoutePop = ModalRoute.of(context)?.canPop ?? false;
    final Widget content = ChatDetailBody(
      chatId: chatId,
      isSecret: isSecret,
      isDesktopSplit: widget.isDesktopSplit,
      canRoutePop: canRoutePop,
      highlightMessageId: widget.highlightMessageId,
      interactionEnabled: _editingMessageId == null && !_isAiProcessing,
      scheme: scheme,
      inputController: _inputController,
      inputFocusNode: _inputFocusNode,
      composer: _composer,
      send: _send,
      attachments: _attachments,
      draft: _draft,
      actions: _actions,
      media: _media,
      scrollCoordinator: _scrollCoordinator,
      lifecycle: _lifecycle,
      presenter: _presenter,
      replyPreviewBuilder: _replyPreviewFor,
      onBack: _goBack,
      onHeaderBack: () {
        if (ref.read(uiSettingsProvider).haptics) {
          HapticService.reaction();
        }
        _goBack();
      },
      onSecurityTap: _showE2eeVerification,
      onShowAi: _showAiBottomSheet,
      onCancelAi: _cancelAiProcessing,
    );

    if (scheme == baseScheme) {
      return content;
    }

    return Theme(
      data: Theme.of(context).copyWith(colorScheme: scheme),
      child: content,
    );
  }
}

/// Adapts the account engine to [SecretDraftSink]. `engine` is a `late` field
/// on the coordinator, so it is touched only when a draft is read or written —
/// never while the sink is being bound.
class _SecretDraftSink implements SecretDraftSink {
  _SecretDraftSink(this._coordinator);

  final SecretChatCoordinator _coordinator;

  SecretChatEngine get _engine => _coordinator.engine;

  @override
  bool isOpen(int chatId) => _engine.findChat(chatId) != null;

  @override
  String? read(int chatId) => _engine.chat(chatId)['draft'] as String?;

  @override
  Future<void> save(int chatId, String text) => _engine.saveDraft(chatId, text);
}
