import 'package:pulse_flutter/providers/chat_productivity_provider.dart';
import 'package:pulse_flutter/widgets/chat_productivity.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:pulse_flutter/widgets/chat/chat_file_drop_target.dart';
import 'package:pulse_flutter/core/clipboard/pasted_image.dart';
import 'package:pulse_flutter/widgets/chat/browser_image_paste_target.dart';
import 'package:pulse_flutter/widgets/chat/pasted_images_dialog.dart';
import 'package:pulse_flutter/providers/encrypted_draft_sync_provider.dart';
import 'package:pulse_flutter/widgets/chat/encrypted_draft_conflict_notice.dart';
import 'package:pulse_flutter/widgets/chat/live_location_card.dart';
import 'package:pulse_flutter/widgets/chat/file_request_action.dart';
import 'package:pulse_flutter/widgets/chat/interactive_composer.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/services/secret_chat/secret_chat_engine.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_app_bar.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_input_area.dart';
import 'package:pulse_flutter/widgets/chat/chat_viewport.dart';
import 'package:pulse_flutter/widgets/chat/chat_empty_state.dart';
import 'package:pulse_flutter/widgets/chat/chat_scroll_coordinator.dart';
import 'package:pulse_flutter/widgets/chat/chat_overlay_layer.dart';
import 'package:pulse_flutter/widgets/chat/e2ee_verification_sheet.dart';
import 'package:pulse_flutter/widgets/chat/reaction_picker_sheet.dart';
import 'package:pulse_flutter/widgets/chat/report_message_sheet.dart';
import 'package:pulse_flutter/widgets/chat/ai_actions_sheet.dart';
import 'package:pulse_flutter/widgets/chat/auto_delete_bottom_sheet.dart';
import 'dart:async';
import 'package:pulse_flutter/core/services/desktop_pasteboard_service.dart';
import 'package:pulse_flutter/widgets/chat/desktop_drag_drop_area.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/router/app_navigation.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/bot_detector.dart';
import 'package:pulse_flutter/core/theme/nios_chroma.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, kIsWeb;
import 'package:flutter/services.dart';
import 'package:pulse_flutter/widgets/chat/chat_message_list.dart';
import 'package:pulse_flutter/widgets/chat/spamblock_banner.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_ai_rewrite_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_attachment_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_composer_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_draft_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_message_action_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_message_presenter.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_media_controller.dart';
import 'package:pulse_flutter/screens/chat_detail/chat_send_controller.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/inline_query_model.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
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
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';
import 'package:pulse_flutter/core/services/desktop_window_service.dart';
import 'package:pulse_flutter/core/utils/screen_security_service.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/repositories/ai_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/screens/calls/outgoing_call_screen.dart';
import 'package:pulse_flutter/widgets/calls/active_group_call_banner.dart';

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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
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

  final ValueNotifier<bool> _loadingOlderNotifier = ValueNotifier<bool>(false);

  late final ChatAiRewriteController _aiRewrite;

  // Screenshot protection overlay
  OverlayEntry? _screenshotOverlay;

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

  Widget _dateSeparator(DateTime resolvedDate, DateTime now) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Text(
            _presenter.dateSeparatorLabel(resolvedDate, now),
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCoordinator = ChatScrollCoordinator(
      onJumpError: (error) {
        if (mounted) {
          AppToast.showError(context, error, onRetry: _scrollToBottom);
        }
      },
      onNearTop: _autoLoadOlderMessages,
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
      onReachedBottom: () {
        final int? cid = _chatId;
        if (cid != null && PushNotificationService.isForeground) {
          unawaited(ref.read(chatMessagesProvider(cid).notifier).markRead());
          ref.read(chatsProvider.notifier).markChatAsRead(cid);
        }
      },
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
      scrollToBottom: _scrollToBottom,
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
      scrollToBottom: _scrollToBottom,
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
        scrollToBottom: _scrollToBottom,
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
    final int? cid = _chatId;
    if (cid != null) PushNotificationService.setCurrentChat(cid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = _chatId;
      if (id != null) {
        _scrollCoordinator.setHasNewerHistory(
          ref.read(chatHistoryWindowProvider(id)).hasNewer,
        );
        // Secure flag first: restoring a draft needs `_isSecret` to be current
        // so a secret chat reads the engine, never DraftStorage.
        _applySecureFlag();
        if (ref.read(chatByIdProvider(id)) != null) {
          unawaited(_draft.restore());
        }
      }
      _refreshNow();
    });
  }

  bool _isSecret = false;
  bool _canPersistOrdinaryDraft = false;

  void _applySecureFlag() {
    final int? chatId = _chatId;
    if (chatId == null) return;
    final ApiChatSummary? chat = ref.read(chatByIdProvider(chatId));
    _canPersistOrdinaryDraft = chat?.isSecret == false;
    if (chat?.isSecret == true) {
      _isSecret = true;
      _bindSecret(ref.read(secretChatCoordinatorProvider).value);
      ScreenSecurityService.setSecureFlag(enabled: true);
    }
  }

  /// Keeps the engine handle the draft controller saves through in sync with
  /// the coordinator. Never awaited from `dispose()`.
  void _bindSecret(SecretChatCoordinator? coordinator) {
    if (coordinator == null) return;
    _secretDraftSink = _SecretDraftSink(coordinator);
  }

  DateTime? _lastScreenshotAlertTime;

  void _handleScreenshotAction() {
    if (!mounted) return;
    final DateTime now = DateTime.now();
    if (_lastScreenshotAlertTime != null &&
        now.difference(_lastScreenshotAlertTime!).inSeconds < 5) {
      return;
    }
    _lastScreenshotAlertTime = now;
    HapticService.confirm();
    AppToast.showInfo(context, 'В секретном чате зафиксирован снимок экрана');
    final int? chatId = _chatId;
    if (chatId != null) {
      ref
          .read(chatMessagesProvider(chatId).notifier)
          .send('📷 Снимок экрана был зафиксирован');
    }
  }

  Future<void> _autoLoadOlderMessages() async {
    if (_loadingOlderNotifier.value) return;
    _loadingOlderNotifier.value = true;
    try {
      await _loadOlderMessages();
    } finally {
      _loadingOlderNotifier.value = false;
    }
  }

  void _scrollToBottom() {
    if (ref.read(uiSettingsProvider).haptics) {
      HapticService.tap();
    }
    final int? cid = _chatId;
    if (cid != null && PushNotificationService.isForeground) {
      unawaited(ref.read(chatMessagesProvider(cid).notifier).markRead());
      ref.read(chatsProvider.notifier).markChatAsRead(cid);
    }
    _scrollCoordinator.scrollToBottom();
  }

  @override
  void dispose() {
    final int? cid = _chatId;
    if (cid != null && PushNotificationService.isForeground) {
      try {
        unawaited(ref.read(chatMessagesProvider(cid).notifier).markRead());
        ref.read(chatsProvider.notifier).markChatAsRead(cid);
      } catch (_) {}
    }
    PushNotificationService.setCurrentChat(null);
    WidgetsBinding.instance.removeObserver(this);
    _aiRewrite.dispose();
    _removeScreenshotOverlay();
    _scrollCoordinator.dispose();
    _loadingOlderNotifier.dispose();
    _composer.dispose();
    _send.dispose();
    _attachments.dispose();
    // Cancel the pending debounce, then write the last text: the only chance
    // to persist the final <500 ms of typing.
    _draft.dispose();
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _inputFocusNode.dispose();
    try {
      ref.read(inlineQueryProvider.notifier).clear();
    } catch (_) {
      // The provider may already be gone when the screen outlives its scope.
    }
    if (_isSecret) {
      ScreenSecurityService.setSecureFlag(enabled: false);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isSecret) {
      if (state == AppLifecycleState.resumed) unawaited(_refreshNow());
      return;
    }
    if (DesktopWindowService.isDesktop) {
      _removeScreenshotOverlay();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _showScreenshotOverlay();
    } else {
      _removeScreenshotOverlay();
    }
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

  void _showScreenshotOverlay() {
    if (_screenshotOverlay != null) return;
    _screenshotOverlay = OverlayEntry(
      builder: (_) => Container(
        color: Theme.of(context).colorScheme.scrim,
        width: double.infinity,
        height: double.infinity,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_screenshotOverlay!);
  }

  void _removeScreenshotOverlay() {
    _screenshotOverlay?.remove();
    _screenshotOverlay = null;
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
  Future<void> _refreshNow() async {
    final int? chatId = _chatId;
    if (chatId == null) return;
    try {
      await ref.read(chatMessagesProvider(chatId).notifier).refresh();
      final followingLatest = ref
          .read(chatMessagesProvider(chatId).notifier)
          .window
          .followingLatest;
      if ((_isSecret || followingLatest) &&
          PushNotificationService.isForeground) {
        await ref.read(chatMessagesProvider(chatId).notifier).markRead();
        ref.read(chatsProvider.notifier).markChatAsRead(chatId);
      }
      if (_isSecret || chatId < 0) return;
      final ApiChatSummary? freshChat = await ref
          .read(chatRepositoryProvider)
          .getChat(chatId);
      if (freshChat != null && mounted) {
        ref
            .read(chatsProvider.notifier)
            .upsertChat(
              freshChat.copyWith(
                unreadCount: followingLatest ? 0 : freshChat.unreadCount,
              ),
            );
      }
    } catch (e) {
      debugPrint('Failed to refresh: $e');
    }
  }

  Future<bool> _loadOlderMessages() async {
    final int? chatId = _chatId;
    if (chatId == null) {
      return false;
    }
    try {
      final int added = await ref
          .read(chatMessagesProvider(chatId).notifier)
          .loadOlder(pageSize: 50);
      return added > 0;
    } catch (error) {
      if (!mounted) return false;
      AppToast.showError(context, error);
      return false;
    }
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

  Future<void> _retrySend(ApiMessage message) async {
    if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
    final int? chatId = _chatId;
    if (chatId == null) return;

    final secret = ref.read(secretChatCoordinatorProvider).value;
    if (secret?.engine.findChat(chatId) != null) {
      await secret!.engine.retry(chatId, message.id);
      return;
    }
    final String localId = message.id.toString();
    final Map<String, UploadTask> uploadTasks = ref.read(uploadQueueProvider);
    if (uploadTasks.containsKey(localId)) {
      // It was an upload task (media/voice/circle/document).
      // Mark local message as sending again and trigger upload retry.
      ref
          .read(chatMessagesProvider(chatId).notifier)
          .markLocalMessageSending(message.id);
      ref.read(uploadQueueProvider.notifier).retry(localId);
      return;
    }

    // Keep the only durable original until its replacement is acknowledged.
    await ref
        .read(chatMessagesProvider(chatId).notifier)
        .send(message.content, replyToId: message.replyToId, localId: localId);
  }

  void _startCall({required bool isVideo}) {
    final int? chatId = _chatId;
    if (chatId == null) return;

    final ApiChatSummary? currentChat = ref.read(chatByIdProvider(chatId));
    if (currentChat != null && currentChat.chatType == 'direct') {
      final int? partnerId = currentChat.partnerUserId;
      final bool isBlockedByMe =
          (partnerId != null &&
              ref.read(privacyProvider).isUserBlocked(partnerId)) ||
          currentChat.isBlockedByMe;
      final bool isBlockedByUser = currentChat.isBlockedByUser;
      if (isBlockedByMe) {
        AppToast.showError(context, context.l10n.chatUnblockToCall);
        return;
      }
      if (isBlockedByUser) {
        AppToast.showError(context, context.l10n.chatCallsRestrictedByUser);
        return;
      }
    }

    final String partnerName = currentChat?.name ?? '';
    final String partnerUsername = currentChat?.username ?? '';
    final String? avatarUrl = currentChat?.avatarUrl;

    context.push(
      '/call/outgoing',
      extra: OutgoingCallArgs(
        username: partnerUsername.isNotEmpty ? partnerUsername : partnerName,
        displayName: partnerName,
        avatarUrl: avatarUrl,
        chatId: chatId,
        isVideo: isVideo,
      ),
    );
  }

  void _startVoiceCall() => _startCall(isVideo: false);

  void _startVideoCall() => _startCall(isVideo: true);

  void _handleOpenMediaFor(ApiMessage message) {
    if (message.hasMedia) {
      _media.openMedia(context, message);
    }
  }

  void _handleLongPressMediaFor(
    ApiMessage message,
    bool isMine,
    bool amAdminOrOwner,
  ) {
    if (message.hasMedia) {
      _media.showMediaActions(
        context,
        message,
        isMine: isMine,
        amAdminOrOwner: amAdminOrOwner,
      );
    }
  }

  void _handleLongPressFor(
    ApiMessage message,
    bool isMine,
    bool isChannel,
    bool amAdminOrOwner,
  ) {
    // The menu needs the screen's context; every outcome is the controller's.
    _actions.showMessageActions(
      context,
      message,
      isMine: isMine,
      isChannel: isChannel,
      amAdminOrOwner: amAdminOrOwner,
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
    final Widget content = ChatFileDropTarget(
      conversationId: chatId,
      enabled: _editingMessageId == null && !_isAiProcessing,
      onFiles: (files) => unawaited(_attachments.previewPastedImages(files)),
      child: BrowserImagePasteTarget(
        focusNode: _inputFocusNode,
        enabled: _editingMessageId == null && !_isAiProcessing,
        onImages: (images) => unawaited(_attachments.previewPastedImages(images)),
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): () {
              final composer = _composer.notifier.value;
              if (composer.editingMessageId != null) {
                _composer.cancelEdit();
              } else if (composer.replyToMessageId != null) {
                _composer.clearReply();
              } else if (!widget.isDesktopSplit && canRoutePop) {
                _goBack();
              }
            },
            if (DesktopPasteboardService.isDesktop)
              const SingleActivator(
                LogicalKeyboardKey.keyV,
                control: true,
              ): () {
                // Focused TextField handles Ctrl+V via ChatInputBar.onDesktopPaste;
                // ignore here so both listeners never double-send the same paste.
                if (_inputFocusNode.hasFocus) return;
                unawaited(_attachments.handleDesktopPaste());
              },
            if (DesktopPasteboardService.isDesktop)
              const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () {
                if (_inputFocusNode.hasFocus) return;
                unawaited(_attachments.handleDesktopPaste());
              },
            if (isSecret) ...<ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.printScreen):
                  _handleScreenshotAction,
              const SingleActivator(
                LogicalKeyboardKey.keyS,
                shift: true,
                meta: true,
              ): _handleScreenshotAction,
              const SingleActivator(
                LogicalKeyboardKey.keyS,
                shift: true,
                control: true,
              ): _handleScreenshotAction,
              const SingleActivator(
                LogicalKeyboardKey.digit3,
                shift: true,
                meta: true,
              ): _handleScreenshotAction,
              const SingleActivator(
                LogicalKeyboardKey.digit4,
                shift: true,
                meta: true,
              ): _handleScreenshotAction,
            },
          },
          child: PopScope(
            canPop: !widget.isDesktopSplit && canRoutePop,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (didPop) return;
              // Native two-pane layout: the shell's PopScope on the same route
              // closes this pane. Handling it here as well made one back press
              // do two things.
              if (widget.isDesktopSplit && !kIsWeb) return;
              _goBack();
            },
            child: Scaffold(
              appBar: _ChatHeaderScope(
                chatId: chatId,
                isDesktopSplit: widget.isDesktopSplit,
                isSecret: isSecret,
                onBack: () {
                  if (ref.read(uiSettingsProvider).haptics) {
                    HapticService.reaction();
                  }
                  _goBack();
                },
                onVoiceCall: _startVoiceCall,
                onVideoCall: _startVideoCall,
                onSecurityTap: _showE2eeVerification,
              ),
              body: DesktopDragDropArea(
                onFilesDropped: _attachments.uploadDesktopFiles,
                child: ChatViewport(
                  topBanner: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ref.watch(
                        chatByIdProvider(chatId).select(
                          (c) => c?.chatType == 'group',
                        ),
                      ))
                        ActiveGroupCallBanner(chatId: chatId),
                      ChatTopBannerLayer(
                        chatId: chatId,
                        isSecret: isSecret,
                        loadingOlderNotifier: _loadingOlderNotifier,
                        onE2eeTap: _showE2eeVerification,
                      ),
                      if (!isSecret)
                        EncryptedDraftConflictNotice(
                          chatId: chatId,
                          onSelected: (text) {
                            _inputController.text = text;
                            _draft.saveNow();
                          },
                        ),
                    ],
                  ),
                  messagesBuilder:
                      (
                        BuildContext context,
                        ValueListenable<double> bottomInset,
                      ) {
                        return _ChatMessagesScope(
                          chatId: chatId,
                          highlightMessageId: widget.highlightMessageId,
                          scrollCoordinator: _scrollCoordinator,
                          inputFocusNode: _inputFocusNode,
                          bottomInset: bottomInset,
                          onOpenComments: (ApiMessage msg) {
                            context.push(
                              '/channel/$chatId/post/${msg.id}/comments',
                            );
                          },
                          onReactionTap: (ApiMessage msg, String emoji) =>
                              _actions.react(msg, emoji),
                          onOpenMedia: _handleOpenMediaFor,
                          onLongPressMedia: _handleLongPressMediaFor,
                          onLongPress: _handleLongPressFor,
                          onSwipeToReply: _composer.setReply,
                          onRetrySend: _retrySend,
                          displayTextBuilder: _presenter.displayText,
                          mediaUrlBuilder: _presenter.mediaUrlFor,
                          isImageMediaBuilder: _presenter.isImageMedia,
                          mediaLabelBuilder: _presenter.mediaLabel,
                          replyPreviewBuilder: _replyPreviewFor,
                          dateSeparatorBuilder: _dateSeparator,
                        );
                      },
                  floatingActionButton: _scrollCoordinator.buildFab(
                    chatId: chatId,
                  ),
                  composer: _ChatComposerScope(
                    chatId: chatId,
                    composerNotifier: _composer.notifier,
                    inputController: _inputController,
                    inputFocusNode: _inputFocusNode,
                    showDraftRestoredBanner: _draft.showRestoredBanner,
                    onClearDraft: _draft.clear,
                    onSend: _send.send,
                    onCommitEdit: _composer.commitEdit,
                    onCancelEdit: _composer.cancelEdit,
                    onClearReply: _composer.clearReply,
                    onAttachMedia: _attachments.pickAndUploadMedia,
                    onAiPressed: (ctx, _) => _showAiBottomSheet(ctx),
                    onVoiceSend: (p) => unawaited(_attachments.sendVoiceMessage(p)),
                    onCircleSend: (p) => unawaited(_attachments.sendCircleVideo(p)),
                    onCancelAi: _cancelAiProcessing,
                    onSendSticker: (s) => unawaited(_attachments.sendSticker(s)),
                    onEditLastMessage: _composer.editLastMessage,
                    onAttachFiles: _attachments.uploadDesktopFiles,
                    onDesktopPaste: _attachments.handleDesktopPaste,
                    scheme: scheme,
                  ),
                ),
              ),
              backgroundColor: scheme.surface,
            ),
          ),
        ),
      ),
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

// ── Isolated Header Scope ──────────────────────────────────────────────────
class _ChatHeaderScope extends ConsumerWidget implements PreferredSizeWidget {
  const _ChatHeaderScope({
    required this.chatId,
    required this.isDesktopSplit,
    required this.isSecret,
    required this.onBack,
    required this.onVoiceCall,
    required this.onVideoCall,
    required this.onSecurityTap,
  });

  final int chatId;
  final bool isDesktopSplit;
  final bool isSecret;
  final VoidCallback onBack;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onSecurityTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  static IconData chatHeaderIcon(bool isChannel, bool isGroup) {
    if (isChannel) return Icons.campaign_rounded;
    if (isGroup) return Icons.groups_rounded;
    return Icons.person_rounded;
  }

  static String chatSubtitle(
    BuildContext context,
    ApiChatSummary? chat,
    bool isChannel,
    bool isGroup, {
    String? directUsername,
  }) {
    if (chat == null) return '';
    final String description = chat.description.trim();
    final String memberCount = context.l10n.chatMemberCount(chat.membersCount);
    if (isChannel) {
      return description.isEmpty ? memberCount : '$memberCount • $description';
    }
    if (isGroup) {
      return description.isEmpty ? memberCount : '$memberCount • $description';
    }
    if (chat.chatType == 'direct') {
      final String username = (directUsername ?? chat.username ?? '').trim();
      if (username.isEmpty) {
        return description;
      }
      if (description.isEmpty) return '@$username';
      return '@$username • $description';
    }
    return memberCount;
  }

  static String? resolveDirectUsername(
    ApiChatSummary? chat,
    List<ApiChatMember> members,
    int myUserId,
  ) {
    if (chat?.chatType == 'group' || chat?.chatType == 'channel') return null;
    final String chatUsername = (chat?.username ?? '').trim();
    if (chatUsername.isNotEmpty) return chatUsername;

    for (final ApiChatMember member in members) {
      if (member.userId != myUserId && member.username.trim().isNotEmpty) {
        return member.username.trim();
      }
    }
    return null;
  }

  static String resolveDirectDisplayName(
    BuildContext context,
    ApiChatSummary? chat,
    List<ApiChatMember> members,
    int myUserId,
    int chatId,
  ) {
    final String chatName = (chat?.name ?? '').trim();
    if (chatName.isNotEmpty) return chatName;

    for (final ApiChatMember member in members) {
      if (member.userId != myUserId && member.displayName.trim().isNotEmpty) {
        return member.displayName.trim();
      }
    }
    return context.l10n.chatTitleFallback(chatId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatByIdProvider(chatId));
    final List<ApiChatMember> members =
        ref.watch(chatMembersProvider(chatId)).value ?? const <ApiChatMember>[];
    final int myUserId = ref.watch(
      authProvider.select((a) => a.session?.userId ?? -1),
    );

    final bool isChannel = chat?.chatType == 'channel';
    final bool isGroup = chat?.chatType == 'group';
    final String? directUsername = resolveDirectUsername(
      chat,
      members,
      myUserId,
    );
    final String title = chat?.isSaved == true
        ? context.l10n.savedMessagesTitle
        : chat?.chatType == 'direct'
        ? resolveDirectDisplayName(context, chat, members, myUserId, chatId)
        : ((chat?.name ?? '').trim().isNotEmpty
              ? chat!.name.trim()
              : context.l10n.chatTitleFallback(chatId));

    return ChatDetailAppBar(
      onShareLocation:
          chat?.chatType == 'direct' &&
              chat?.isSecret != true &&
              !isSecret &&
              chat?.isBotChat != true &&
              chat?.isSaved != true
          ? () => showLiveLocationComposer(context, ref, chatId)
          : null,
      managementChatId: chat?.topicParentId,
      isSaved: chat?.isSaved == true,
      onScheduledMessages: isSecret || chat?.isSecret == true
          ? null
          : () => AppModal.showSheet<void>(
              context: context,
              isScrollable: true,
              builder: (sheetContext) => SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * 0.75,
                child: ScheduledMessagesScreen(chatId: chatId),
              ),
            ),
      onTopics: isGroup
          ? () => pushAppRoute<void>(
              context,
              '/chat/${chat?.topicParentId ?? chatId}/topics',
              fallback: (_) =>
                  GroupTopicsScreen(chatId: chat?.topicParentId ?? chatId),
            )
          : null,
      onCreateInteractive:
          chat != null &&
              !isSecret &&
              !chat.isSecret &&
              !chat.isBotChat &&
              (chat.chatType == 'direct' || chat.chatType == 'group')
          ? (kind) async {
              final accountId = ref.read(authProvider).session?.userId;
              final content = await showInteractiveComposer(context, kind);
              if (!context.mounted ||
                  content == null ||
                  ref.read(authProvider).session?.userId != accountId) {
                return;
              }
              try {
                await ref
                    .read(chatMessagesProvider(chatId).notifier)
                    .send(content, requestAi: false);
              } catch (error) {
                if (context.mounted) {
                  AppToast.showError(
                    context,
                    context.l10n.interactiveSendFailed,
                  );
                }
              }
            }
          : null,
      chatId: chatId,
      isDesktopSplit: isDesktopSplit,
      title: title,
      avatarUrl: chat?.avatarUrl,
      headerIcon: chatHeaderIcon(isChannel, isGroup),
      statusEmoji: chat?.partnerStatusEmoji,
      isGroup: isGroup,
      isChannel: isChannel,
      isSecret: chat?.isSecret == true || isSecret,
      directUsername: directUsername,
      autoDeleteDuration: chat?.formattedAutoDeleteDuration,
      isVerified:
          chat?.isVerified == true ||
          chat?.username?.toLowerCase() == 'support' ||
          directUsername?.toLowerCase() == 'support',
      isBot:
          chat?.chatType == 'bot' ||
          BotDetector.isBot(chat?.username) ||
          BotDetector.isBot(directUsername),
      isOnline:
          chat?.isSaved != true &&
          chat?.chatType == 'direct' &&
          chat?.isOnline == true,
      onBack: onBack,
      onVoiceCall: onVoiceCall,
      onVideoCall: onVideoCall,
      onSecurityTap: onSecurityTap,
      onAutoDeleteTap: () {
        AutoDeleteBottomSheet.show(
          context,
          chatId: chatId,
          currentAutoDeleteSeconds: chat?.autoDeleteSeconds,
          isSecret: chat?.isSecret == true || isSecret,
        );
      },
      typingSubtitle: chat?.isSaved == true
          ? Text(
              context.l10n.savedMessagesSubtitle,
              style: Theme.of(context).textTheme.bodySmall,
            )
          : _TypingSubtitle(
              chatId: chatId,
              isOnline: chat?.isOnline == true,
              isDirect: chat?.chatType == 'direct' && !isGroup && !isChannel,
              fallback: chatSubtitle(
                context,
                chat,
                isChannel,
                isGroup,
                directUsername: directUsername,
              ),
            ),
    );
  }
}

// ── Isolated Messages Scope ────────────────────────────────────────────────
class _ChatMessagesScope extends ConsumerWidget {
  const _ChatMessagesScope({
    required this.chatId,
    this.highlightMessageId,
    required this.scrollCoordinator,
    required this.inputFocusNode,
    required this.bottomInset,
    required this.onOpenComments,
    required this.onReactionTap,
    required this.onOpenMedia,
    required this.onLongPressMedia,
    required this.onLongPress,
    required this.onSwipeToReply,
    required this.onRetrySend,
    required this.displayTextBuilder,
    required this.mediaUrlBuilder,
    required this.isImageMediaBuilder,
    required this.mediaLabelBuilder,
    required this.replyPreviewBuilder,
    required this.dateSeparatorBuilder,
  });

  final int chatId;
  final int? highlightMessageId;
  final ChatScrollCoordinator scrollCoordinator;
  final FocusNode inputFocusNode;
  final ValueListenable<double> bottomInset;
  final void Function(ApiMessage) onOpenComments;
  final void Function(ApiMessage, String) onReactionTap;
  final void Function(ApiMessage) onOpenMedia;
  final void Function(ApiMessage, bool isMine, bool amAdminOrOwner)
  onLongPressMedia;
  final void Function(
    ApiMessage,
    bool isMine,
    bool isChannel,
    bool amAdminOrOwner,
  )
  onLongPress;
  final void Function(ApiMessage) onSwipeToReply;
  final void Function(ApiMessage) onRetrySend;
  final String Function(ApiMessage) displayTextBuilder;
  final String? Function(ApiMessage) mediaUrlBuilder;
  final bool Function(ApiMessage, String url) isImageMediaBuilder;
  final String? Function(ApiMessage, String url) mediaLabelBuilder;
  final String? Function(ApiMessage, Map<int, ApiMessage> byId)
  replyPreviewBuilder;
  final Widget Function(DateTime date, DateTime now) dateSeparatorBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ChatHistoryWindowState>(chatHistoryWindowProvider(chatId), (
      previous,
      next,
    ) {
      scrollCoordinator.setHasNewerHistory(next.hasNewer);
      final incoming =
          next.incomingRevision -
          (previous?.incomingRevision ?? next.incomingRevision);
      if (incoming > 0) scrollCoordinator.onIncomingMessages(incoming);
    });
    final window = ref.watch(chatHistoryWindowProvider(chatId));

    final AsyncValue<List<ApiMessage>> messagesAsync = ref.watch(
      chatMessagesProvider(chatId),
    );
    final int myUserId = ref.watch(
      authProvider.select((a) => a.session?.userId ?? -1),
    );
    final (bool isChannel, bool isGroup, bool isSecret) = ref.watch(
      chatByIdProvider(chatId).select(
        (c) => (
          c?.chatType == 'channel',
          c?.chatType == 'group',
          c?.isSecret == true,
        ),
      ),
    );
    final String myRole = ref.watch(myChatRoleProvider(chatId));
    final bool amAdminOrOwner = myRole == 'admin' || myRole == 'owner';

    return messagesAsync.when(
      data: (List<ApiMessage> messages) {
        if (messages.isEmpty) {
          if (isSecret) {
            return ChatEmptyState.secret(
              title: context.l10n.secretChatTitle,
              description: context.l10n.secretChatDesc,
              actionLabel: context.l10n.chatSendFirst,
              onAction: () => inputFocusNode.requestFocus(),
            );
          }

          return ChatEmptyState.empty(
            title: context.l10n.chatNoMessages,
            description: context.l10n.chatSendFirst,
            actionLabel: context.l10n.chatSendFirst,
            onAction: () => inputFocusNode.requestFocus(),
          );
        }

        return ChatMessageList(
          messages: messages,
          scrollController: scrollCoordinator.scrollController,
          followingLatest: window.followingLatest,
          highlightMessageId: highlightMessageId,
          initialScrollAnchor: ref
              .read(chatMessagesProvider(chatId).notifier)
              .scrollAnchor,
          canSaveScrollAnchor: () => !scrollCoordinator.isJumping,
          onScrollAnchorChanged: ref
              .read(chatMessagesProvider(chatId).notifier)
              .saveScrollAnchor,
          onRequestMessage: (id) =>
              ref.read(chatMessagesProvider(chatId).notifier).loadAround(id),
          authUserId: myUserId,
          amAdminOrOwner: amAdminOrOwner,
          isChannel: isChannel,
          isGroup: isGroup,
          bottomPadding: bottomInset,
          topPadding: 48.0,
          onOpenComments: onOpenComments,
          onReactionTap: onReactionTap,
          onOpenMedia: onOpenMedia,
          onLongPressMedia: onLongPressMedia,
          onLongPress: onLongPress,
          onSwipeToReply: onSwipeToReply,
          onCallbackQuery: (ApiMessage message, String data) {
            return ref
                .read(chatMessagesProvider(chatId).notifier)
                .sendCallbackQuery(message.id, data);
          },
          onRetrySend: onRetrySend,
          displayTextBuilder: displayTextBuilder,
          mediaUrlBuilder: mediaUrlBuilder,
          isImageMediaBuilder: isImageMediaBuilder,
          mediaLabelBuilder: mediaLabelBuilder,
          replyPreviewBuilder: replyPreviewBuilder,
          dateSeparatorBuilder: dateSeparatorBuilder,
          animatedMessageBuilder:
              ({
                required int messageId,
                required bool animate,
                required int staggerIndex,
                required bool isMine,
                required Widget child,
              }) {
                return _AnimatedMessage(
                  key: ValueKey<int>(messageId),
                  animate: animate,
                  staggerIndex: staggerIndex,
                  isMine: isMine,
                  child: child,
                );
              },
        );
      },
      loading: () => const MessageListSkeleton(),
      error: (Object error, StackTrace trace) {
        return ChatEmptyState.error(
          title: context.l10n.chatConnecting,
          description: context.l10n.chatReconnecting,
          actionLabel: context.l10n.refreshAction,
          onAction: () => ref.invalidate(chatMessagesProvider(chatId)),
        );
      },
    );
  }
}

// ── Isolated Composer Scope ────────────────────────────────────────────────
class _ChatComposerScope extends ConsumerWidget {
  const _ChatComposerScope({
    required this.chatId,
    required this.composerNotifier,
    required this.inputController,
    required this.inputFocusNode,
    required this.showDraftRestoredBanner,
    required this.onClearDraft,
    required this.onSend,
    required this.onCommitEdit,
    required this.onCancelEdit,
    required this.onClearReply,
    required this.onAttachMedia,
    required this.onAiPressed,
    required this.onVoiceSend,
    required this.onCircleSend,
    required this.onCancelAi,
    required this.onSendSticker,
    required this.onEditLastMessage,
    required this.onAttachFiles,
    required this.onDesktopPaste,
    required this.scheme,
  });

  final int chatId;
  final ValueNotifier<ChatComposerState> composerNotifier;
  final TextEditingController inputController;
  final FocusNode inputFocusNode;
  final bool showDraftRestoredBanner;
  final VoidCallback onClearDraft;
  final VoidCallback onSend;
  final VoidCallback onCommitEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onClearReply;
  final VoidCallback onAttachMedia;
  final void Function(BuildContext, ColorScheme) onAiPressed;
  final void Function(String) onVoiceSend;
  final void Function(String)? onCircleSend;
  final VoidCallback onCancelAi;
  final void Function(ApiSticker) onSendSticker;
  final VoidCallback onEditLastMessage;
  final void Function(List<String>, {bool sendAsDocument})? onAttachFiles;
  final Future<void> Function() onDesktopPaste;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (
      bool isChannel,
      bool isDirect,
      int? partnerUserId,
      bool isBlockedByMeChat,
      bool isBlockedByUser,
    ) = ref.watch(
      chatByIdProvider(chatId).select(
        (c) => (
          c?.chatType == 'channel',
          c?.chatType == 'direct',
          c?.partnerUserId,
          c?.isBlockedByMe ?? false,
          c?.isBlockedByUser ?? false,
        ),
      ),
    );

    final String myRole = ref.watch(myChatRoleProvider(chatId));
    final bool canPostInChannel =
        !isChannel || myRole == 'admin' || myRole == 'owner';

    final int? partnerId = partnerUserId;
    final bool isBlockedByMe =
        isDirect &&
        partnerId != null &&
        (ref.watch(privacyProvider).isUserBlocked(partnerId) ||
            isBlockedByMeChat);

    final bool hasActiveUploads = ref.watch(
      hasActiveChatUploadsProvider(chatId),
    );
    final bool hapticsEnabled = ref.watch(
      uiSettingsProvider.select((s) => s.haptics),
    );
    final bool sendOnEnter = ref.watch(
      uiSettingsProvider.select((s) => s.sendOnEnter),
    );

    final (
      bool isAccountSpamBlocked,
      DateTime? spamBlockUntil,
      String? spamBlockReason,
      int? myUserId,
    ) = ref.watch(
      authProvider.select(
        (a) => (
          a.profile?.isRestrictedBySpamBlock ?? false,
          a.profile?.spamBlockUntil,
          a.profile?.spamBlockReason,
          a.profile?.id,
        ),
      ),
    );
    final ApiChatSummary? currentChat = isAccountSpamBlocked
        ? ref.watch(chatByIdProvider(chatId))
        : null;
    final bool hasPartnerReply =
        isAccountSpamBlocked &&
        currentChat?.chatType == 'direct' &&
        myUserId != null &&
        ref.watch(
          chatMessagesProvider(chatId).select(
            (s) => (s.asData?.value ?? const <ApiMessage>[]).any(
              (m) => m.senderId != myUserId,
            ),
          ),
        );
    final bool isSpamBlocked = isChatRestrictedBySpamBlock(
      isAccountSpamBlocked: isAccountSpamBlocked,
      chat: currentChat,
      myUserId: myUserId,
      hasPartnerReply: hasPartnerReply,
    );

    if (ref.watch(
      chatByIdProvider(chatId).select((c) => c?.topicClosed == true),
    )) {
      return const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Тема закрыта. Читать сообщения можно, отправлять — после открытия темы.',
          ),
        ),
      );
    }
    return ValueListenableBuilder<ChatComposerState>(
      valueListenable: composerNotifier,
      builder:
          (BuildContext context, ChatComposerState composerState, Widget? _) {
            return ChatDetailInputArea(
              chatId: chatId,
              isBlockedByMe: isBlockedByMe,
              isBlockedByUser: isDirect && isBlockedByUser,
              onUnblockUser: partnerId != null
                  ? () async {
                      HapticService.confirm();
                      final bool success = await ref
                          .read(privacyProvider.notifier)
                          .unblockUser(partnerId);
                      if (!context.mounted) return;
                      if (success) {
                        AppToast.showSuccess(
                          context,
                          context.l10n.userUnblockedSuccess,
                        );
                      }
                    }
                  : null,
              onCancelAi: onCancelAi,
              onSendSticker: onSendSticker,
              onSendInlineResult: (InlineQueryResult result) {
                inputController.text = result.messageText;
                onSend();
              },
              canPostInChannel: canPostInChannel,
              showDraftRestoredBanner: showDraftRestoredBanner,
              onClearDraft: onClearDraft,
              uploadingMedia: hasActiveUploads,
              inputController: inputController,
              inputFocusNode: inputFocusNode,
              isAiProcessing: composerState.isAiProcessing,
              editingMessageId: composerState.editingMessageId,
              editingOriginalText: composerState.editingOriginalText,
              replyToMessageId: composerState.replyToMessageId,
              replyPreviewText: composerState.replyPreviewText,
              onSend: onSend,
              onCommitEdit: onCommitEdit,
              onCancelEdit: onCancelEdit,
              onClearReply: onClearReply,
              onAttachMedia: onAttachMedia,
              onAiPressed: () => onAiPressed(context, scheme),
              onVoiceSend: onVoiceSend,
              onCircleSend: onCircleSend,
              hapticsEnabled: hapticsEnabled,
              sendOnEnter: sendOnEnter,
              isSpamBlocked: isSpamBlocked,
              spamBlockUntil: spamBlockUntil,
              spamBlockReason: spamBlockReason,
              onContactSupport: () => context.push('/support'),
              onEditLastMessage: onEditLastMessage,
              onAttachFiles: onAttachFiles,
              onDesktopPaste: onDesktopPaste,
            );
          },
    );
  }
}

// ── Animated message entrance widget ────────────────────────────────────────
class _AnimatedMessage extends StatefulWidget {
  const _AnimatedMessage({
    super.key,
    required this.animate,
    required this.isMine,
    required this.child,
    this.staggerIndex = 0,
  });

  final bool animate;
  final bool isMine;
  final Widget child;

  /// Place in a batch of messages that arrived together; delays the entrance.
  final int staggerIndex;

  @override
  State<_AnimatedMessage> createState() => _AnimatedMessageState();
}

class _AnimatedMessageState extends State<_AnimatedMessage>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fade;
  Animation<double>? _scale;
  Animation<double>? _slideY;
  Timer? _staggerTimer;

  static const Duration _staggerStep = Duration(milliseconds: 40);

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      final ctrl = AnimationController(
        vsync: this,
        duration: M3Durations.spatialFast,
      );
      _controller = ctrl;
      // Position and scale ride the spatial spring; opacity stays on an
      // effects curve so it never overshoots.
      _fade = ctrl.drive(
        CurveTween(
          curve: const Interval(
            0.0,
            0.5,
            curve: M3SpringCurves.effectsDefault,
          ),
        ),
      );
      _scale = ctrl.drive(
        Tween<double>(
          begin: 0.94,
          end: 1.0,
        ).chain(CurveTween(curve: M3SpringCurves.spatialFast)),
      );
      _slideY = ctrl.drive(
        Tween<double>(
          begin: 16.0,
          end: 0.0,
        ).chain(CurveTween(curve: M3SpringCurves.spatialFast)),
      );
      final int stagger = widget.staggerIndex;
      if (stagger > 0) {
        // Until its turn the row stays at the start of the entrance.
        _staggerTimer = Timer(_staggerStep * stagger, () {
          if (mounted) ctrl.forward();
        });
      } else {
        ctrl.forward();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) _controller?.value = 1.0;
  }

  @override
  void dispose() {
    _staggerTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keyed on the controller, not on `animate`: the list stops asking for
    // the entrance one frame after it starts, and it must still play out.
    if (_controller == null) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fade!,
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (BuildContext context, Widget? child) {
          return Transform.translate(
            offset: Offset(0, _slideY!.value),
            child: Transform.scale(
              scale: _scale!.value,
              alignment: widget.isMine
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _TypingSubtitle extends ConsumerWidget {
  const _TypingSubtitle({
    required this.chatId,
    required this.fallback,
    this.isOnline = false,
    this.isDirect = false,
  });
  final int chatId;
  final String fallback;
  final bool isOnline;
  final bool isDirect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count = ref.watch(
      typingProvider(chatId).select((TypingState s) => s.typingUserIds.length),
    );
    final String state = count == 1
        ? 'typing'
        : count > 1
        ? 'typing-many'
        : isDirect && isOnline
        ? 'online'
        : 'idle';

    // Every state is a single bodySmall line, so the cross-fade keeps the
    // header height fixed.
    return AnimatedSwitcher(
      duration: context.motionDuration(M3Durations.short4),
      switchInCurve: M3SpringCurves.effectsDefault,
      switchOutCurve: M3SpringCurves.effectsFast,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) =>
          Stack(
            alignment: AlignmentDirectional.centerStart,
            children: <Widget>[...previousChildren, ?currentChild],
          ),
      child: KeyedSubtree(
        key: ValueKey<String>(state),
        child: _content(context, count),
      ),
    );
  }

  Widget _content(BuildContext context, int count) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (count == 1) {
      return Text(
        context.l10n.chatTyping,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
          height: 1.05,
        ),
      );
    } else if (count > 1) {
      return Text(
        context.l10n.chatTypingMultiple,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
          height: 1.05,
        ),
      );
    }

    if (isDirect && isOnline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6.5,
            height: 6.5,
            margin: const EdgeInsets.only(right: 5),
            decoration: const BoxDecoration(
              color: AppColors.statusOnline,
              shape: BoxShape.circle,
            ),
          ),
          Flexible(
            child: Text(
              context.l10n.online,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.statusOnline,
                fontWeight: FontWeight.w600,
                height: 1.05,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      fallback,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        height: 1.05,
      ),
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
