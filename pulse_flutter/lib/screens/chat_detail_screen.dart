import 'package:pulse_flutter/widgets/chat/chat_detail_app_bar.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_fab.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_input_area.dart';
import 'package:pulse_flutter/widgets/chat/e2ee_verification_sheet.dart';
import 'dart:async';
import 'dart:math';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/theme/app_colors.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/bot_detector.dart';
import 'package:pulse_flutter/core/theme/nios_chroma.dart';
import 'package:pulse_flutter/providers/chat_wallpaper_provider.dart';
import 'package:pulse_flutter/widgets/wallpaper/chat_wallpaper_background.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulse_flutter/widgets/chat/chat_message_list.dart';
import 'package:pulse_flutter/widgets/empty_feed_widget.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/core/utils/e2ee_file_crypto.dart';
import 'package:pulse_flutter/core/utils/file_opener.dart';
import 'package:pulse_flutter/screens/media_viewer_screen.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
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
import 'package:pulse_flutter/repositories/support_repository.dart';
import 'package:pulse_flutter/widgets/m3_file_picker_bottom_sheet.dart';
import 'package:pulse_flutter/widgets/m3_file_preview_bottom_sheet.dart';
import 'package:pulse_flutter/widgets/message_context_menu_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';
import 'package:pulse_flutter/core/utils/screen_security_service.dart';
import 'package:pulse_flutter/widgets/offline_banner.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/core/services/push_notification_service.dart';
import 'package:pulse_flutter/repositories/ai_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/screens/calls/outgoing_call_screen.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';

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
    with WidgetsBindingObserver {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final FocusNode _inputFocusNode;

  // Cache providers that may be needed in dispose()
  late DraftStorage _draftStorage;

  Timer? _draftSaveTimer;
  bool _showDraftRestoredBanner = false;

  int? _replyToMessageId;
  String? _replyPreviewText;

  // Inline edit mode
  int? _editingMessageId;
  String? _editingOriginalText;

  // Scroll-to-bottom FAB
  final ValueNotifier<bool> _showScrollToBottomNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _unreadWhileScrolledNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _loadingOlderNotifier = ValueNotifier<bool>(false);

  bool _isInputEmpty = true;
  bool _isAiProcessing = false;

  // Secret chat polling
  Timer? _secretPollTimer;

  // Screenshot protection overlay
  OverlayEntry? _screenshotOverlay;

  int? get _chatId => int.tryParse(widget.chatId);

  String _chatSubtitle(
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

  void _goBack() {
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

  String? _resolveDirectUsername(
    ApiChatSummary? chat,
    List<ApiMessage> messages,
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

    for (final ApiMessage message in messages.reversed) {
      if (message.senderId != myUserId &&
          message.senderUsername.trim().isNotEmpty) {
        return message.senderUsername.trim();
      }
    }

    return null;
  }

  IconData _chatHeaderIcon(bool isChannel, bool isGroup) {
    if (isChannel) return Icons.campaign_rounded;
    if (isGroup) return Icons.groups_rounded;
    return Icons.person_rounded;
  }

  String _resolveDirectDisplayName(
    ApiChatSummary? chat,
    List<ApiMessage> messages,
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

    for (final ApiMessage message in messages.reversed) {
      if (message.senderId != myUserId &&
          message.senderDisplayName.trim().isNotEmpty) {
        return message.senderDisplayName.trim();
      }
    }

    return context.l10n.chatTitleFallback(chatId);
  }

  String _dateSeparatorLabel(DateTime resolvedDate, DateTime now) {
    final bool sameDay =
        resolvedDate.year == now.year &&
        resolvedDate.month == now.month &&
        resolvedDate.day == now.day;
    if (sameDay) return context.l10n.chatToday;
    final DateTime yesterday = now.subtract(const Duration(days: 1));
    if (resolvedDate.year == yesterday.year &&
        resolvedDate.month == yesterday.month &&
        resolvedDate.day == yesterday.day) {
      return context.l10n.chatYesterday;
    }
    return formatFullDateTime(resolvedDate);
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
            _dateSeparatorLabel(resolvedDate, now),
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
    _draftStorage = ref.read(draftStorageProvider); // cache before dispose
    _scrollController.addListener(_onScroll);
    _inputController.addListener(_onInputChanged);
    _inputFocusNode = FocusNode()..addListener(() {
      if (mounted) setState(() {});
    });
    final int? cid = _chatId;
    if (cid != null) PushNotificationService.setCurrentChat(cid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreDraft();
      _applySecureFlag();
      final routeAnim = ModalRoute.of(context)?.animation;
      if (routeAnim != null && !routeAnim.isCompleted) {
        void onAnimEnd(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            routeAnim.removeStatusListener(onAnimEnd);
            if (mounted) _refreshNow();
          }
        }
        routeAnim.addStatusListener(onAnimEnd);
      } else {
        _refreshNow();
      }
    });
  }

  bool _isSecret = false;

  void _applySecureFlag() {
    final int? chatId = _chatId;
    if (chatId == null) return;
    final ApiChatSummary? chat = ref.read(chatByIdProvider(chatId));
    if (chat?.isSecret == true) {
      _isSecret = true;
      ScreenSecurityService.setSecureFlag(enabled: true);
      _startSecretPollTimer();
    }
  }

  void _startSecretPollTimer() {
    _secretPollTimer?.cancel();
    _secretPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollSecretChat();
    });
  }

  Future<void> _pollSecretChat() async {
    final int? chatId = _chatId;
    if (chatId == null || !mounted) return;
    try {
      await ref.read(chatMessagesProvider(chatId).notifier).refresh();
    } catch (_) {}
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double offset = _scrollController.offset;
    final double maxExtent = _scrollController.position.maxScrollExtent;
    // Since list is reversed, offset > threshold means scrolled UP (away from latest)
    final bool shouldShow = offset > 300;
    if (shouldShow != _showScrollToBottomNotifier.value) {
      _showScrollToBottomNotifier.value = shouldShow;
    }
    if (offset <= 60 && _unreadWhileScrolledNotifier.value != 0) {
      _unreadWhileScrolledNotifier.value = 0;
      final int? cid = _chatId;
      if (cid != null) {
        unawaited(ref.read(chatMessagesProvider(cid).notifier).markRead());
        ref.read(chatsProvider.notifier).markChatAsRead(cid);
      }
    }
    // Auto-load older messages when near the top (end of reversed list)
    if (offset > maxExtent - 400 && !_loadingOlderNotifier.value) {
      _autoLoadOlderMessages();
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
    _unreadWhileScrolledNotifier.value = 0;
    final int? cid = _chatId;
    if (cid != null) {
      unawaited(ref.read(chatMessagesProvider(cid).notifier).markRead());
      ref.read(chatsProvider.notifier).markChatAsRead(cid);
    }
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    final int? cid = _chatId;
    if (cid != null) {
      try {
        unawaited(ref.read(chatMessagesProvider(cid).notifier).markRead());
        ref.read(chatsProvider.notifier).markChatAsRead(cid);
      } catch (_) {}
    }
    PushNotificationService.setCurrentChat(null);
    WidgetsBinding.instance.removeObserver(this);
    _secretPollTimer?.cancel();
    _removeScreenshotOverlay();
    _showScrollToBottomNotifier.dispose();
    _unreadWhileScrolledNotifier.dispose();
    _loadingOlderNotifier.dispose();
    _draftSaveTimer?.cancel();
    _saveDraft();
    _scrollController.removeListener(_onScroll);
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    ref.read(inlineQueryProvider.notifier).clear();
    if (_isSecret) {
      ScreenSecurityService.setSecureFlag(enabled: false);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isSecret) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _showScreenshotOverlay();
    } else if (state == AppLifecycleState.resumed) {
      _removeScreenshotOverlay();
    }
  }

  void _showE2eeVerification() {
    final int? chatId = _chatId;
    if (chatId == null) return;
    AppBottomSheets.show(
      context: context,
      showDragHandle: false,
      builder: (_) => E2eeVerificationSheet(
        chatId: chatId,
        onInitiateHandshake: () => _initiateE2eeHandshake(chatId),
      ),
    );
  }

  Future<void> _initiateE2eeHandshake(int chatId) async {
    try {
      final e2ee = ref.read(e2eeServiceProvider);
      final chat = ref.read(chatByIdProvider(chatId));
      if (chat?.partnerPublicKey == null || chat!.partnerPublicKey!.isEmpty) {
        AppToast.showError(context, context.l10n.e2eeHandshakeNoPeerKey);
        return;
      }
      final edPubB64 = await e2ee.getEdPublicKeyBase64();
      await e2ee.initiateHandshake(
        chatId: chatId,
        theirPublicKeyBase64: chat.partnerPublicKey!,
        theirEdPublicKeyBase64: edPubB64,
      );
      final msg = await e2ee.createHandshakeMessage(chatId);
      await ref.read(chatMessagesProvider(chatId).notifier).sendHandshakeMessage(
        dhPubB64: msg.dhPubB64,
        edPubB64: msg.edPubB64,
        signature: msg.signature,
      );
      if (!mounted) return;
      AppToast.showSuccess(context, context.l10n.e2eeHandshakeInitiated);
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, context.l10n.e2eeHandshakeFailed(e));
    }
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
    final bool isEmpty = _inputController.text.trim().isEmpty;
    _scheduleDraftSave();
    if (_isInputEmpty != isEmpty) {
      setState(() {
        _isInputEmpty = isEmpty;
      });
    }
    ref.read(inlineQueryProvider.notifier).onInputChanged(
      chatId: _chatId,
      text: _inputController.text,
    );
    if (!isEmpty) {
      final int? chatId = _chatId;
      if (chatId != null) {
        ref.read(typingProvider(chatId).notifier).sendTyping();
      }
    }
  }

  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), _saveDraft);
  }

  Future<void> _processTextWithAi(String action, {String? targetLanguage}) async {
    final String currentText = _inputController.text.trim();
    if (currentText.isEmpty) return;

    setState(() {
      _isAiProcessing = true;
    });

    try {
      final String resultText = await ref.read(aiRepositoryProvider).processText(
        text: currentText,
        action: action,
        targetLanguage: targetLanguage,
      );

      if (mounted) {
        _inputController.text = resultText;
        _inputController.selection = TextSelection.fromPosition(
          TextPosition(offset: resultText.length),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAiProcessing = false;
        });
      }
    }
  }

  void _showAiBottomSheet(BuildContext context, ColorScheme scheme) {
    if (_isInputEmpty) return;
    AppBottomSheets.show<void>(
      context: context,
      
      builder: (BuildContext ctx) {
        final TextTheme tt = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header
                Row(
                  children: <Widget>[
                    Icon(Icons.auto_awesome_rounded, color: scheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.chatAiAssistant,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Consumer(
                      builder: (BuildContext context, WidgetRef ref, _) {
                        final usage = ref.watch(
                          authProvider.select((a) => a.profile?.aiUsage),
                        );
                        if (usage == null) return const SizedBox.shrink();
                        final double remainingPercent =
                            (100.0 - usage.usedPercent).clamp(0.0, 100.0);
                        final String pctStr = remainingPercent.toStringAsFixed(
                          remainingPercent.truncateToDouble() == remainingPercent ? 0 : 1,
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, size: 14, color: scheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                '$pctStr% токенов',
                                style: tt.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 2-column action cards
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _AiActionCard(
                        icon: Icons.spellcheck_rounded,
                        label: context.l10n.chatAiFixErrors,
                        scheme: scheme,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _processTextWithAi('correct');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AiActionCard(
                        icon: Icons.business_center_rounded,
                        label: context.l10n.chatAiFormal,
                        scheme: scheme,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _processTextWithAi('formalize');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.chatAiTranslate,
                  style: tt.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ActionChip(
                      label: const Text('🇬🇧 English'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _processTextWithAi('translate', targetLanguage: 'English');
                      },
                    ),
                    ActionChip(
                      label: const Text('🇪🇸 Español'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _processTextWithAi('translate', targetLanguage: 'Spanish');
                      },
                    ),
                    ActionChip(
                      label: const Text('🇨🇳 中文'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _processTextWithAi('translate', targetLanguage: 'Chinese');
                      },
                    ),
                    ActionChip(
                      label: const Text('🇷🇺 Русский'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _processTextWithAi('translate', targetLanguage: 'Russian');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshNow() async {
    final int? chatId = _chatId;
    if (chatId == null) return;
    try {
      await ref.read(chatMessagesProvider(chatId).notifier).refresh();
      await ref.read(chatMessagesProvider(chatId).notifier).markRead();
      ref.read(chatsProvider.notifier).markChatAsRead(chatId);
      final ApiChatSummary? freshChat =
          await ref.read(chatRepositoryProvider).getChat(chatId);
      if (freshChat != null && mounted) {
        ref.read(chatsProvider.notifier).upsertChat(freshChat.copyWith(unreadCount: 0));
      }
    } catch (e) {
      debugPrint('Failed to refresh: $e');
    }
  }

  Future<void> _restoreDraft() async {
    final int? chatId = _chatId;
    if (chatId == null) return;
    final String? draft = await ref.read(draftStorageProvider).get(chatId);
    if (draft != null && draft.isNotEmpty && _inputController.text.isEmpty) {
      _inputController.text = draft;
      _showDraftRestoredBanner = true;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _saveDraft() {
    final int? chatId = _chatId;
    if (chatId == null) return;
    final String text = _inputController.text.trim();
    _draftStorage.set(chatId, text); // use cached ref — safe in dispose()
  }

  Future<void> _sendMessage() async {
    if (ref.read(uiSettingsProvider).haptics) HapticService.confirm();
    final int? chatId = _chatId;
    if (chatId == null) {
      return;
    }

    final myProfile = ref.read(authProvider).profile;
    if (myProfile?.isRestrictedBySpamBlock == true) {
      AppToast.showError(context, context.l10n.chatAccountRestricted);
      return;
    }

    final String text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final ApiChatSummary? currentChat = ref.read(chatByIdProvider(chatId));
    if (currentChat != null && currentChat.chatType == 'direct') {
      final int? partnerId = currentChat.partnerUserId;
      final bool isBlockedByMe = (partnerId != null && ref.read(privacyProvider).isUserBlocked(partnerId)) || currentChat.isBlockedByMe;
      if (isBlockedByMe) {
        AppToast.showError(context, context.l10n.chatUnblockToSend);
        return;
      }
    }

    final bool isSupportChat =
        currentChat?.username?.toLowerCase() == 'support' ||
        currentChat?.name.toLowerCase() == 'support';
    if (isSupportChat && text.startsWith('/copyright')) {
      final String body = text.substring('/copyright'.length).trim();
      unawaited(
        ref.read(supportRepositoryProvider).createTicket(
          ticketType: 'copyright',
          subject: 'Авторская жалоба',
          body: body.isNotEmpty ? body : 'Обращение по авторскому праву',
        ),
      );
    }

    final int? replyId = _replyToMessageId;
    final String originalText = _inputController.text;
    final String? originalReplyPreview = _replyPreviewText;

    _inputController.clear();
    _clearReply();
    _scrollToBottom();

    unawaited(
      ref
          .read(chatMessagesProvider(chatId).notifier)
          .send(text, replyToId: replyId)
          .catchError((error) {
        if (!mounted) {
          return;
        }
        _inputController.text = originalText;
        _inputController.selection = TextSelection.fromPosition(
          TextPosition(offset: originalText.length),
        );
        if (replyId != null && originalReplyPreview != null) {
          setState(() {
            _replyToMessageId = replyId;
            _replyPreviewText = originalReplyPreview;
          });
        }
        final String errorStr = error.toString().toLowerCase();
        if (errorStr.contains('not accept direct messages') ||
            errorStr.contains('unavailable between these users') ||
            errorStr.contains('restricted by user')) {
          ref.read(chatsProvider.notifier).setChatBlockedByUser(chatId, true);
          AppToast.showError(context, context.l10n.chatMessagesRestrictedByUser);
        } else {
          AppToast.showError(context, error);
        }
      }),
    );
  }

  Future<void> _uploadAndSend({
    required int chatId,
    String? filePath,
    Uint8List? bytes,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    String text = '',
    bool showSentSnackBar = false,
  }) async {
    final String defaultSenderYou = context.l10n.chatSenderYou;
    final String localId = (-(DateTime.now().millisecondsSinceEpoch + Random().nextInt(1000))).toString();
    final int tempIntId = int.parse(localId);

    final int? replyToId = _replyToMessageId;

    // Secret chats: encrypt the payload locally; the per-file key travels in
    // the Double-Ratchet message envelope and never reaches the server.
    Uint8List? effectiveBytes = (bytes != null && bytes.isNotEmpty) ? bytes : null;
    String effectiveFilePath = filePath ?? '';
    Uint8List? e2eeFileKey;
    if (ref.read(chatByIdProvider(chatId))?.isSecret == true) {
      try {
        final Uint8List plain = effectiveBytes ??
            (filePath != null && filePath.isNotEmpty ? await File(filePath).readAsBytes() : Uint8List(0));
        if (plain.isNotEmpty) {
          e2eeFileKey = E2eeFileCrypto.generateFileKey();
          effectiveBytes = await E2eeFileCrypto.encrypt(plain, e2eeFileKey);
          effectiveFilePath = ''; // upload ciphertext bytes instead of the file
        }
      } catch (e) {
        debugPrint('[chat_detail] E2EE file encrypt failed: $e');
      }
    }

    final authState = ref.read(authProvider);
    final int myUserId = authState.session?.userId ?? -1;
    final String myUsername = authState.session?.username ?? '';
    final String myDisplayName = authState.profile?.displayName.trim() ?? '';
    final String effectiveDisplayName = myDisplayName.isNotEmpty
        ? myDisplayName
        : (myUsername.isNotEmpty ? myUsername : defaultSenderYou);
    final optimisticMessage = ApiMessage(
      id: tempIntId,
      chatId: chatId,
      senderId: myUserId,
      senderUsername: myUsername,
      senderDisplayName: effectiveDisplayName,
      senderBadges: const [],
      content: text,
      msgType: mediaSubtype == 'voice' 
          ? 'voice' 
          : (mediaSubtype == 'circle' ? 'circle' : 'media'),
      replyToId: replyToId,
      mediaUrl: filePath ?? 'local://$localId',
      mediaType: 'file',
      mediaName: filename,
      mediaSize: fileSize,
      mediaDuration: null,
      commentsCount: 0,
      reactions: const {},
      sentAt: DateTime.now(),
      editedAt: null,
      isDeleted: false,
      isSending: true,
      isFailed: false,
    );

    ref.read(chatMessagesProvider(chatId).notifier).addOptimisticLocalMessage(optimisticMessage);
    _clearReply();
    _scrollToBottom();

    ref.read(uploadQueueProvider.notifier).enqueue(
      localId: localId,
      chatId: chatId,
      filePath: effectiveFilePath,
      bytes: effectiveBytes,
      filename: filename,
      mediaSubtype: mediaSubtype,
      fileSize: fileSize,
      text: text,
      replyToId: replyToId,
      e2eeFileKey: e2eeFileKey,
    );
  }

  Future<void> _sendVoiceMessage(String filePath) async {
    final int? chatId = _chatId;
    if (chatId == null) return;

    final File file = File(filePath);
    final int fileSize = await file.length();
    final String filename = filePath.split('/').last;

    await _uploadAndSend(
      chatId: chatId,
      filePath: filePath,
      filename: filename,
      mediaSubtype: 'voice',
      fileSize: fileSize,
    );
  }

  Future<void> _sendCircleVideo(String filePath) async {
    final int? chatId = _chatId;
    if (chatId == null) return;

    final File file = File(filePath);
    final int fileSize = await file.length();
    final String filename = filePath.split('/').last;

    await _uploadAndSend(
      chatId: chatId,
      filePath: filePath,
      filename: filename,
      mediaSubtype: 'circle',
      fileSize: fileSize,
    );
  }

  Future<void> _sendSticker(ApiSticker sticker) async {
    final int? cid = _chatId;
    if (cid == null) return;
    try {
      await ref
          .read(chatMessagesProvider(cid).notifier)
          .sendSticker(sticker.id, replyToId: _replyToMessageId);
      _clearReply();
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, context.l10n.chatStickerSendFailed(e));
      }
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

  Future<void> _pickAndUploadMedia() async {
    final int? chatId = _chatId;
    if (chatId == null) {
      return;
    }

    final List<M3FilePickerResult>? results = await showM3FilePicker(context);
    if (results == null || results.isEmpty || !mounted) {
      return;
    }

    final String initialText = _inputController.text;
    if (mounted) _inputController.clear();

    for (int i = 0; i < results.length; i++) {
      final M3FilePickerResult result = results[i];
      final String filename = result.fileName;
      final String mediaSubtype =
          result.sendAsDocument ? 'document' : result.mediaSubtype;

      final String? uploadFilePath = result.filePath;
      final Uint8List? uploadBytes = result.fileBytes;
      final int uploadFileSize = result.fileSize;
      final String caption =
          (result.caption != null && result.caption!.isNotEmpty)
              ? result.caption!
              : (i == 0 ? initialText : '');

      _uploadAndSend(
        chatId: chatId,
        filePath: uploadFilePath,
        bytes: uploadBytes,
        filename: filename,
        mediaSubtype: mediaSubtype,
        fileSize: uploadFileSize,
        text: caption,
        showSentSnackBar: false,
      );
    }
  }

  Future<void> _editMessage(ApiMessage message) async {
    final int? chatId = _chatId;
    if (chatId == null) return;
    // Enter inline edit mode instead of showing AlertDialog
    setState(() {
      _editingMessageId = message.id;
      _editingOriginalText = message.content;
      _inputController.text = message.content;
    });
    // Put cursor at end
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
  }

  Future<void> _commitEdit() async {
    if (ref.read(uiSettingsProvider).haptics) HapticService.confirm();
    final int? chatId = _chatId;
    final int? editId = _editingMessageId;
    if (chatId == null || editId == null) return;
    final String edited = _inputController.text.trim();
    final String originalDraft = _inputController.text;
    final String? originalText = _editingOriginalText;
    if (edited.isEmpty || edited == (originalText ?? '').trim()) {
      _cancelEdit();
      return;
    }
    _cancelEdit();
    try {
      await ref
          .read(chatMessagesProvider(chatId).notifier)
          .editMessage(editId, edited);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _editingMessageId = editId;
        _editingOriginalText = originalText;
        _inputController.text = originalDraft;
        _inputController.selection = TextSelection.fromPosition(
          TextPosition(offset: originalDraft.length),
        );
      });
      AppToast.showError(context, error);
    }
  }

  void _cancelEdit() {
    if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
    setState(() {
      _editingMessageId = null;
      _editingOriginalText = null;
      _inputController.clear();
    });
  }

  Future<void> _deleteMessage(ApiMessage message) async {
    final int? chatId = _chatId;
    if (chatId == null) {
      return;
    }

    final bool confirmed =
        await showAppConfirmDialog(
          context: context,
          title: context.l10n.chatDeleteMessageTitle,
          subtitle: context.l10n.chatDeleteMessageBody,
          confirmLabel: context.l10n.commonDelete,
          cancelLabel: context.l10n.commonCancel,
          destructive: true,
          icon: Icons.delete_outline_rounded,
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(chatMessagesProvider(chatId).notifier)
          .deleteMessage(message.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.showError(context, error);
    }
  }

  Future<void> _react(ApiMessage message, String emoji) async {
    final int? chatId = _chatId;
    if (chatId == null) {
      return;
    }
    try {
      await ref
          .read(chatMessagesProvider(chatId).notifier)
          .toggleReaction(message.id, emoji);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.showError(context, error);
    }
  }

  void _setReply(ApiMessage message) {
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final String author = _resolveReplyAuthor(message, myUserId);
    final String snippet = _resolveReplySnippet(message);
    setState(() {
      _replyToMessageId = message.id;
      _replyPreviewText =
          '$author: ${snippet.length > 80 ? "${snippet.substring(0, 80)}..." : snippet}';
    });
  }

  void _clearReply() {
    if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
    setState(() {
      _replyToMessageId = null;
      _replyPreviewText = null;
    });
  }

  Future<void> _forwardMessage(ApiMessage message) async {
    final AsyncValue<List<ApiChatSummary>> chatsAsync = ref.read(chatsProvider);
    final List<ApiChatSummary> chats =
        chatsAsync.value ?? const <ApiChatSummary>[];
    if (chats.isEmpty) return;

    final ApiChatSummary? target = await AppBottomSheets.show<ApiChatSummary>(
      context: context,
      builder: (BuildContext ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              context.l10n.chatForwardTo,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...chats.map(
              (ApiChatSummary c) => ListTile(
                leading: PulseAvatar(
                  radius: 18,
                  name: c.name,
                  avatarUrl: c.avatarUrl,
                ),
                title: Text(c.name),
                onTap: () => Navigator.of(ctx).pop(c),
              ),
            ),
          ],
        );
      },
    );

    if (target == null || !mounted) return;

    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final bool hideMyAuthor = message.senderId == myUserId &&
        ref.read(privacyProvider).policyFor('forwards') == PrivacyPolicy.nobody;
    final String forwardText = hideMyAuthor || message.senderDisplayName.isEmpty
        ? '_fwd: ${message.content}'
        : '_fwd from ${message.senderDisplayName}: ${message.content}';
    try {
      await ref
          .read(chatMessagesProvider(target.id).notifier)
          .send(forwardText);
      if (!mounted) return;
      AppToast.showSuccess(context, context.l10n.chatMessageForwarded);
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e);
    }
  }

  Future<void> _showMessageActions(
    ApiMessage message,
    bool isMine, {
    required bool isChannel,
    required bool amAdminOrOwner,
  }) async {
    await AppBottomSheets.show<void>(
      context: context,
      isScrollControlled: true,
      
      builder: (BuildContext ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: MessageContextMenuSheet(
            message: message,
            isMine: isMine,
            isChannel: isChannel,
            amAdminOrOwner: amAdminOrOwner,
            isSecret: ref.read(chatByIdProvider(_chatId ?? 0))?.isSecret == true,
            onReact: (String emoji) => _react(message, emoji),
            onShowAllReactions: () => _showAllReactionsPicker(message),
            onReply: () => _setReply(message),
            onCopy: () {
              Clipboard.setData(ClipboardData(text: message.content));
              AppToast.showInfo(context, context.l10n.chatMessageTextCopied);
            },
            onForward: () => _forwardMessage(message),
            onComments: () {
              final int? chatId = _chatId;
              if (chatId == null) return;
              context.push('/channel/$chatId/post/${message.id}/comments');
            },
            onEdit: () => _editMessage(message),
            onDelete: () => _deleteMessage(message),
            onReport: () => _showReportMessageDialog(message),
          ),
        ),
      ),
    );
  }

  void _showReportMessageDialog(ApiMessage message) {
    AppBottomSheets.show<void>(
      context: context,
      
      builder: (BuildContext ctx) {
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        final TextTheme textTheme = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  context.l10n.reportSelectReason,
                  style: textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: Icon(Icons.report_gmailerrorred_rounded, color: scheme.error),
                title: Text(context.l10n.reportReasonSpam),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitReport(message, 'spam');
                },
              ),
              ListTile(
                leading: Icon(Icons.report_problem_rounded, color: scheme.error),
                title: Text(context.l10n.reportReasonScam),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitReport(message, 'scam');
                },
              ),
              ListTile(
                leading: Icon(Icons.gavel_rounded, color: scheme.error),
                title: Text(context.l10n.reportReasonIllegal),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitReport(message, 'illegal');
                },
              ),
              ListTile(
                leading: Icon(Icons.copyright_rounded, color: scheme.error),
                title: const Text('Нарушение авторских прав (copyright)'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitReport(message, 'copyright');
                },
              ),
              ListTile(
                leading: Icon(Icons.privacy_tip_rounded, color: scheme.error),
                title: const Text('Доксинг (личные данные)'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitReport(message, 'doxing');
                },
              ),
              ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: scheme.error),
                title: const Text('Сваттинг / угрозы безопасности'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitReport(message, 'swatting');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitReport(ApiMessage message, String reason) async {
    try {
      await ref.read(reportRepositoryProvider).report(
        chatId: message.chatId,
        reportedUserId: message.senderId,
        messageIds: <int>[message.id],
        reason: reason,
      );
      if (!mounted) return;
      AppToast.showSuccess(context, context.l10n.reportSent);
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e);
    }
  }

  static const List<String> _allReactionEmojis = <String>[
    '👍', '👎', '❤️', '🔥', '😂', '🎉', '😮', '😢', '😍', '🤔',
    '😎', '🫡', '🙏', '👏', '💪', '🤝', '💯', '✨', '⭐', '⚡',
    '☕', '🍕', '🎮', '❌', '✅',
  ];

  Future<void> _showAllReactionsPicker(ApiMessage message) async {
    final int? chatId = _chatId;
    if (chatId == null) return;

    final String? emoji = await AppBottomSheets.show<String>(
      context: context,
      builder: (BuildContext ctx) {
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        final TextTheme tt = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    ctx.l10n.chatReactionsPickerTitle,
                    style: tt.titleMedium,
                  ),
                ),
                GridView.count(
                  crossAxisCount: 8,
                  shrinkWrap: true,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.1,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _allReactionEmojis.map((String emoji) {
                    return InkWell(
                      onTap: () => Navigator.of(ctx).pop(emoji),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: (message.reactions[emoji] ?? 0) > 0
                              ? scheme.primaryContainer.withValues(alpha: 0.6)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (emoji == null) return;
    if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
    await ref
        .read(chatMessagesProvider(chatId).notifier)
        .toggleReaction(message.id, emoji);
  }

  void _openMedia(ApiMessage message) {
    final String? mediaUrl = message.mediaUrl;
    if (mediaUrl == null || mediaUrl.trim().isEmpty) return;

    final String fileName = (message.mediaName ?? '').trim().isNotEmpty
        ? message.mediaName!.trim()
        : _mediaLabel(message, mediaUrl);

    final bool isImg = _isImageMedia(message, mediaUrl);
    final bool isVid = _isVideoMedia(message, mediaUrl);

    if (isImg || isVid) {
      final int? chatId = _chatId;
      final List<ApiMessage> allMessages = chatId != null
          ? (ref.read(chatMessagesProvider(chatId)).value ?? const <ApiMessage>[])
          : const <ApiMessage>[];

      final List<MediaViewerItem> playlist = <MediaViewerItem>[];
      int initialIndex = 0;

      for (final ApiMessage msg in allMessages) {
        final String? u = msg.mediaUrl;
        if (u == null || u.trim().isEmpty) continue;
        final bool mIsImg = _isImageMedia(msg, u);
        final bool mIsVid = _isVideoMedia(msg, u);
        if (mIsImg || mIsVid) {
          if (msg.id == message.id) {
            initialIndex = playlist.length;
          }
          playlist.add(MediaViewerItem(
            url: u,
            mediaType: mIsImg ? MediaType.image : MediaType.video,
            title: (msg.mediaName ?? '').trim().isNotEmpty
                ? msg.mediaName!.trim()
                : _mediaLabel(msg, u),
            e2eeFileKey: msg.e2eeFileKey,
            filePath: msg.mediaUrl,
            mediaName: msg.mediaName,
          ));
        }
      }

      context.push(
        '/media-viewer?url=${Uri.encodeComponent(mediaUrl)}'
        '&type=${isImg ? 'image' : 'video'}&title=${Uri.encodeComponent(fileName)}',
        extra: <String, dynamic>{
          'e2eeKey': message.e2eeFileKey,
          'playlist': playlist.isNotEmpty ? playlist : null,
          'initialIndex': initialIndex,
        },
      );
      return;
    }

    showM3FilePreview(
      context: context,
      fileName: fileName,
      fileSize: message.mediaSize ?? 0,
      mediaUrl: mediaUrl,
      e2eeFileKey: message.e2eeFileKey,
      onForward: () async {
        if (!context.mounted) return;
        await _forwardMessage(message);
      },
    );
  }

  bool _isVideoMedia(ApiMessage message, String mediaUrl) {
    final String mediaType = (message.mediaType ?? '').toLowerCase();
    if (mediaType.startsWith('video/')) {
      return true;
    }

    final String lower = mediaUrl.toLowerCase();
    final String fileName = (message.mediaName ?? '').toLowerCase();
    bool isVideoExt(String s) =>
        s.endsWith('.mp4') ||
        s.endsWith('.mov') ||
        s.endsWith('.mkv') ||
        s.endsWith('.webm') ||
        s.endsWith('.3gp') ||
        s.endsWith('.avi');
    return isVideoExt(lower) || (fileName.isNotEmpty && isVideoExt(fileName));
  }

  String _displayText(ApiMessage message) => message.content;

  Future<void> _showMediaActions(
    ApiMessage message,
    bool isMine, {
    required bool amAdminOrOwner,
  }) async {
    final String? mediaUrl = message.mediaUrl;
    if (mediaUrl == null || mediaUrl.trim().isEmpty) {
      return;
    }
    final String fileName = (message.mediaName ?? '').trim().isNotEmpty
        ? message.mediaName!.trim()
        : _mediaLabel(message, mediaUrl);

    await AppBottomSheets.show<void>(
      context: context,
      
      builder: (BuildContext ctx) {
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.save_alt_rounded),
                  title: Text(context.l10n.mediaActionSave),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    saveM3File(
                      context: context,
                      fileName: fileName,
                      fileSize: message.mediaSize ?? 0,
                      mediaUrl: mediaUrl,
                      e2eeFileKey: message.e2eeFileKey,
                      wsClient: ref.read(webSocketClientProvider),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.forward_rounded),
                  title: Text(context.l10n.chatResendTo),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _forwardMessage(message);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: Text(context.l10n.mediaActionCopy),
                  onTap: () async {
                    final String copyLabel = context.l10n.mediaActionCopy;
                    Navigator.of(ctx).pop();
                    await Clipboard.setData(ClipboardData(text: mediaUrl));
                    if (ctx.mounted) AppToast.showInfo(ctx, copyLabel);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: Text(context.l10n.mediaActionOpenIn),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    FileOpener.openUrl(context, mediaUrl);
                  },
                ),
                if (isMine || amAdminOrOwner)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: scheme.error,
                    ),
                    title: Text(
                      context.l10n.chatDelete,
                      style: TextStyle(color: scheme.error),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _deleteMessage(message);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _mediaLabel(ApiMessage message, String mediaUrl) {
    final String explicit = (message.mediaName ?? '').trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }

    final Uri? uri = Uri.tryParse(mediaUrl);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final String last = uri.pathSegments.last.trim();
      if (last.isNotEmpty) {
        return last;
      }
    }
    return context.l10n.chatAttachment;
  }

  String? _extractUrlFromText(String text) {
    final RegExp rx = RegExp(r'https?://[^\s]+');
    final Match? match = rx.firstMatch(text);
    if (match == null) {
      return null;
    }
    return match.group(0);
  }

  String? _mediaUrlFor(ApiMessage message) {
    final String direct = (message.mediaUrl ?? '').trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    if (message.msgType == 'media') {
      return _extractUrlFromText(message.content.trim());
    }
    return null;
  }

  bool _isImageMedia(ApiMessage message, String mediaUrl) {
    final String mediaType = (message.mediaType ?? '').toLowerCase();
    if (mediaType.startsWith('image/')) {
      return true;
    }

    final String lower = mediaUrl.toLowerCase();
    final String fileName = (message.mediaName ?? '').toLowerCase();
    bool isImageExt(String s) =>
        s.endsWith('.jpg') ||
        s.endsWith('.jpeg') ||
        s.endsWith('.png') ||
        s.endsWith('.webp') ||
        s.endsWith('.gif') ||
        s.endsWith('.bmp') ||
        s.endsWith('.svg');
    return isImageExt(lower) || (fileName.isNotEmpty && isImageExt(fileName));
  }

  String _resolveReplySnippet(ApiMessage message) {
    if (message.isSticker) {
      final String emoji = message.sticker?.emoji.trim() ?? '';
      return emoji.isNotEmpty
          ? context.l10n.chatPreviewStickerWithEmoji(emoji)
          : context.l10n.chatPreviewSticker;
    }

    if (message.msgType == 'voice' ||
        (message.mediaType ?? '').toLowerCase().startsWith('audio/')) {
      final int? duration = message.mediaDuration;
      if (duration != null && duration > 0) {
        final int minutes = duration ~/ 60;
        final int seconds = duration % 60;
        final String formatted =
            '$minutes:${seconds.toString().padLeft(2, '0')}';
        return context.l10n.chatPreviewVoiceWithDuration(formatted);
      }
      return context.l10n.chatPreviewVoice;
    }

    if (message.msgType == 'circle' ||
        message.msgType == 'circle_video' ||
        message.msgType == 'video_note' ||
        message.msgType == 'round_video') {
      return context.l10n.chatPreviewVideoNote;
    }

    final String? mediaUrl = _mediaUrlFor(message);
    if (mediaUrl != null && mediaUrl.trim().isNotEmpty) {
      final String caption = message.content.trim();
      if (_isImageMedia(message, mediaUrl)) {
        return caption.isNotEmpty ? '📷 $caption' : context.l10n.chatPreviewPhoto;
      }
      if (_isVideoMedia(message, mediaUrl)) {
        return caption.isNotEmpty ? '🎥 $caption' : context.l10n.chatPreviewVideo;
      }
      final String name = (message.mediaName ?? '').trim();
      final String label =
          name.isNotEmpty ? name : _mediaLabel(message, mediaUrl);
      return caption.isNotEmpty ? '📎 $label • $caption' : '📎 $label';
    }

    if (message.isCallEvent) {
      return context.l10n.chatPreviewCall;
    }

    final String text = _displayText(message).trim();
    if (text.isNotEmpty) {
      return text;
    }

    if (message.hasMedia) {
      return context.l10n.chatPreviewAttachment;
    }

    return context.l10n.chatPreviewMessage;
  }

  String _resolveReplyAuthor(ApiMessage message, int myUserId) {
    if (message.senderId == myUserId) {
      return context.l10n.chatSenderYou;
    }
    final String name = message.senderDisplayName.trim();
    if (name.isNotEmpty && name.toLowerCase() != 'unknown') {
      return name;
    }
    final String username = message.senderUsername.trim();
    if (username.isNotEmpty && username.toLowerCase() != 'unknown') {
      return username.startsWith('@') ? username : '@$username';
    }
    final int? cid = _chatId;
    if (cid != null) {
      final ApiChatSummary? chat = ref.read(chatByIdProvider(cid));
      final String chatName = (chat?.name ?? '').trim();
      if (chatName.isNotEmpty) {
        return chatName;
      }
    }
    return context.l10n.chatSenderPartner;
  }

  String? _replyPreviewFor(ApiMessage message, Map<int, ApiMessage> byId) {
    final int? replyToId = message.replyToId;
    if (replyToId == null) {
      return null;
    }
    final ApiMessage? target = byId[replyToId];
    if (target == null) {
      return context.l10n.chatReplyToId(replyToId);
    }
    final int myUserId = ref.read(authProvider).session?.userId ?? -1;
    final String author = _resolveReplyAuthor(target, myUserId);
    final String snippet = _resolveReplySnippet(target);
    final String text = '$author: $snippet';
    return text.length > 64 ? '${text.substring(0, 64)}...' : text;
  }

  Future<void> _retrySend(ApiMessage message) async {
    if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
    final int? chatId = _chatId;
    if (chatId == null) return;

    final String localId = message.id.toString();
    final Map<String, UploadTask> uploadTasks = ref.read(uploadQueueProvider);
    if (uploadTasks.containsKey(localId)) {
      // It was an upload task (media/voice/circle/document).
      // Mark local message as sending again and trigger upload retry.
      ref.read(chatMessagesProvider(chatId).notifier).markLocalMessageSending(message.id);
      ref.read(uploadQueueProvider.notifier).retry(localId);
      return;
    }

    // Text message retry: remove optimistic message and resend
    ref.read(chatMessagesProvider(chatId).notifier).removeLocalMessage(message.id);
    await ref.read(chatMessagesProvider(chatId).notifier).send(message.content, replyToId: message.replyToId);
  }

  void _startCall({required bool isVideo}) {
    final int? chatId = _chatId;
    if (chatId == null) return;

    final ApiChatSummary? currentChat = ref.read(chatByIdProvider(chatId));
    if (currentChat != null && currentChat.chatType == 'direct') {
      final int? partnerId = currentChat.partnerUserId;
      final bool isBlockedByMe = (partnerId != null && ref.read(privacyProvider).isUserBlocked(partnerId)) || currentChat.isBlockedByMe;
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
      _openMedia(message);
    }
  }

  void _handleLongPressMediaFor(ApiMessage message, bool isMine, bool amAdminOrOwner) {
    if (message.hasMedia) {
      _showMediaActions(message, isMine, amAdminOrOwner: amAdminOrOwner);
    }
  }

  void _handleLongPressFor(ApiMessage message, bool isMine, bool isChannel, bool amAdminOrOwner) {
    _showMessageActions(message, isMine, isChannel: isChannel, amAdminOrOwner: amAdminOrOwner);
  }

  @override
  Widget build(BuildContext context) {
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

    final int myUserId = ref.watch(
      authProvider.select((a) => a.session?.userId ?? -1),
    );
    final chat = ref.watch(chatByIdProvider(chatId));
    ref.listen<ApiChatSummary?>(chatByIdProvider(chatId), (prev, next) {
      final bool wasSecret = prev?.isSecret == true;
      final bool isSecret = next?.isSecret == true;
      if (isSecret != wasSecret) {
        _isSecret = isSecret;
        ScreenSecurityService.setSecureFlag(enabled: isSecret);
        if (isSecret) {
          _startSecretPollTimer();
        } else {
          _secretPollTimer?.cancel();
        }
      }
    });
    if (chat?.isSecret == true && !_isSecret) {
      _isSecret = true;
      ScreenSecurityService.setSecureFlag(enabled: true);
      _startSecretPollTimer();
    }
    final bool isChannel = chat?.chatType == 'channel';
    final bool isGroup = chat?.chatType == 'group';

    final String myRole = ref.watch(myChatRoleProvider(chatId));
    final bool amAdminOrOwner = myRole == 'admin' || myRole == 'owner';
    final bool canPostInChannel = !isChannel || amAdminOrOwner;
    final AsyncValue<List<ApiMessage>> messagesAsync = ref.watch(
      chatMessagesProvider(chatId),
    );
    ref.listen<AsyncValue<List<ApiMessage>>>(chatMessagesProvider(chatId), (previous, next) {
      final List<ApiMessage>? prevList = previous?.value;
      final List<ApiMessage>? nextList = next.value;
      if (prevList != null && nextList != null && nextList.length > prevList.length) {
        if (_showScrollToBottomNotifier.value) {
          final int added = nextList.length - prevList.length;
          _unreadWhileScrolledNotifier.value += added;
        }
      }
    });
    final List<ApiMessage> currentMessages =
        messagesAsync.value ?? const <ApiMessage>[];
    final List<ApiChatMember> members =
        ref.watch(chatMembersProvider(chatId)).value ?? const <ApiChatMember>[];

    final ColorScheme baseScheme = Theme.of(context).colorScheme;
    final wallpaperState = ref.watch(chatWallpaperProvider);
    final chatWallpaper = wallpaperState.forChat(chatId.toString());
    final bool hasCustomWallpaper = chatWallpaper != wallpaperState.global ||
        chatWallpaper.imagePath != null;

    final bool isDirect = chat?.chatType == 'direct' && !isGroup && !isChannel;
    final ColorScheme scheme = (isDirect && NiosChroma.shouldApply(hasCustomWallpaper: hasCustomWallpaper))
        ? NiosChroma.resolveChromaScheme(
            userScheme: baseScheme,
            partnerId: chat?.name.isNotEmpty == true ? chat!.name : chatId.toString(),
            chatId: chatId,
          )
        : baseScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? directUsername = _resolveDirectUsername(
      chat,
      currentMessages,
      members,
      myUserId,
    );
    final String title = chat?.chatType == 'direct'
        ? _resolveDirectDisplayName(
            chat,
            currentMessages,
            members,
            myUserId,
            chatId,
          )
        : ((chat?.name ?? '').trim().isNotEmpty
              ? chat!.name.trim()
              : context.l10n.chatTitleFallback(chatId));

    final bool canRoutePop = ModalRoute.of(context)?.canPop ?? false;
    final Widget content = PopScope(
      canPop: !widget.isDesktopSplit && canRoutePop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        appBar: ChatDetailAppBar(
          chatId: chatId,
          isDesktopSplit: widget.isDesktopSplit,
          title: title,
          avatarUrl: chat?.avatarUrl,
          headerIcon: _chatHeaderIcon(isChannel, isGroup),
          isGroup: isGroup,
          isChannel: isChannel,
          isSecret: chat?.isSecret == true,
          directUsername: directUsername,
          autoDeleteDuration: chat?.formattedAutoDeleteDuration,
          isVerified: chat?.isVerified == true ||
              chat?.username?.toLowerCase() == 'support' ||
              directUsername?.toLowerCase() == 'support',
          isBot: chat?.chatType == 'bot' ||
              BotDetector.isBot(chat?.username) ||
              BotDetector.isBot(directUsername),
          isOnline: chat?.chatType == 'direct' && chat?.isOnline == true,
          onBack: () {
            if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
            _goBack();
          },
          onVoiceCall: _startVoiceCall,
          onVideoCall: _startVideoCall,
          onSecurityTap: _showE2eeVerification,
          typingSubtitle: _TypingSubtitle(
            chatId: chatId,
            isOnline: chat?.isOnline == true,
            isDirect: chat?.chatType == 'direct' && !isGroup && !isChannel,
            fallback: _chatSubtitle(
              chat,
              isChannel,
              isGroup,
              directUsername: directUsername,
            ),
          ),
        ),
      body: PulseScaffoldBody(
        animatedBackdrop: false,
        expand: true,
        bottomSafe: false,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ChatWallpaperBackground(
                chatId: widget.chatId.toString(),
              ),
            ),
            Column(
              children: <Widget>[
                Consumer(
                  builder: (BuildContext context, WidgetRef ref, _) {
                    final bool isOffline =
                        !(ref.watch(connectivityProvider).value ?? true);
                    return OfflineBanner(isOffline: isOffline);
                  },
                ),
                if (chat?.isSecret == true)
                  GestureDetector(
                    onTap: _showE2eeVerification,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: scheme.primaryContainer.withValues(alpha: 0.35),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.lock_rounded, size: 14, color: scheme.primary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              context.l10n.chatE2eeBanner,
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded, size: 14, color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                // Loading older messages indicator at top
                ValueListenableBuilder<bool>(
                  valueListenable: _loadingOlderNotifier,
                  builder: (context, isLoading, _) => AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: isLoading
                        ? const AppLoadingIndicator(size: 24)
                        : const SizedBox.shrink(),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      messagesAsync.when(
                    data: (List<ApiMessage> messages) {
                      if (messages.isEmpty) {
                        final bool isSecretChat = chat?.isSecret == true || _isSecret;
                        if (isSecretChat) {
                          return EmptyFeedWidget(
                            icon: Icons.lock_rounded,
                            title: context.l10n.secretChatTitle,
                            description: context.l10n.secretChatDesc,
                            features: [
                              context.l10n.secretChatFeature1,
                              context.l10n.secretChatFeature2,
                              context.l10n.secretChatFeature3,
                              context.l10n.secretChatFeature4,
                            ],
                            actionLabel: context.l10n.chatSendFirst,
                            onAction: () => _inputFocusNode.requestFocus(),
                          );
                        }

                        return EmptyFeedWidget(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: context.l10n.chatNoMessages,
                          description: context.l10n.chatSendFirst,
                          actionLabel: context.l10n.chatSendFirst,
                          onAction: () => _inputFocusNode.requestFocus(),
                        );
                      }

                      return ChatMessageList(
                        messages: messages,
                        scrollController: _scrollController,
                        authUserId: myUserId,
                        amAdminOrOwner: amAdminOrOwner,
                        isChannel: isChannel,
                        isGroup: isGroup,
                        onOpenComments: (ApiMessage msg) {
                          context.push('/channel/$chatId/post/${msg.id}/comments');
                        },
                        onReactionTap: (ApiMessage msg, String emoji) =>
                            _react(msg, emoji),
                        onOpenMedia: _handleOpenMediaFor,
                        onLongPressMedia: _handleLongPressMediaFor,
                        onLongPress: _handleLongPressFor,
                        onSwipeToReply: _setReply,
                        onCallbackQuery: (ApiMessage message, String data) {
                          final int? cid = _chatId;
                          if (cid == null) return;
                          ref.read(chatMessagesProvider(cid).notifier).sendCallbackQuery(message.id, data);
                        },
                        onRetrySend: _retrySend,
                        displayTextBuilder: _displayText,
                        mediaUrlBuilder: _mediaUrlFor,
                        isImageMediaBuilder: _isImageMedia,
                        mediaLabelBuilder: _mediaLabel,
                        replyPreviewBuilder: _replyPreviewFor,
                        dateSeparatorBuilder: _dateSeparator,
                        animatedMessageBuilder: ({required int messageId, required bool animate, required bool isMine, required Widget child}) {
                          return _AnimatedMessage(
                            key: ValueKey<int>(messageId),
                            animate: animate,
                            isMine: isMine,
                            child: child,
                          );
                        },
                      );
                    },
                    loading: () => const MessageListSkeleton(),
                    error: (Object error, StackTrace trace) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.sync_rounded,
                                    color: scheme.primary,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.l10n.chatConnecting,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.chatReconnecting,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.tonalIcon(
                                onPressed: () => ref.invalidate(
                                  chatMessagesProvider(chatId),
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: Text(context.l10n.refreshAction),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Scroll-to-bottom FAB overlay
                  ValueListenableBuilder<bool>(
                    valueListenable: _showScrollToBottomNotifier,
                    builder: (context, showScroll, child) {
                      return ValueListenableBuilder<int>(
                        valueListenable: _unreadWhileScrolledNotifier,
                        builder: (context, unreadCount, _) {
                          return ChatDetailScrollToBottomFAB(
                            show: showScroll,
                            chatId: chatId,
                            unreadCount: unreadCount,
                            onPressed: _scrollToBottom,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
        Builder(
          builder: (BuildContext ctx) {
            final bool isDirectChat = chat?.chatType == 'direct';
            final int? partnerId = chat?.partnerUserId ??
                (directUsername != null ? members.where((m) => m.userId != myUserId).firstOrNull?.userId : null);
            final bool isBlockedByMe = isDirectChat && partnerId != null &&
                (ref.watch(privacyProvider).isUserBlocked(partnerId) || (chat?.isBlockedByMe ?? false));
            final bool isBlockedByUser = isDirectChat && (chat?.isBlockedByUser ?? false);

            return ChatDetailInputArea(
              chatId: chatId,
              isBlockedByMe: isBlockedByMe,
              isBlockedByUser: isBlockedByUser,
              onUnblockUser: partnerId != null
                  ? () async {
                      HapticService.confirm();
                      final bool success = await ref
                          .read(privacyProvider.notifier)
                          .unblockUser(partnerId);
                      if (!context.mounted) return;
                      if (success) {
                        AppToast.showSuccess(context, context.l10n.userUnblockedSuccess);
                      }
                    }
                  : null,
              onSendSticker: _sendSticker,
              onSendInlineResult: (InlineQueryResult result) {
                _inputController.text = result.messageText;
                _sendMessage();
              },
              canPostInChannel: canPostInChannel,
              showDraftRestoredBanner: _showDraftRestoredBanner,
              onClearDraft: () {
                final int? cid = _chatId;
                if (cid != null) {
                  _draftStorage.remove(cid);
                }
                _inputController.clear();
                setState(() {
                  _showDraftRestoredBanner = false;
                });
              },
              uploadingMedia:
                  ref.watch(activeChatUploadsProvider(chatId)).isNotEmpty,
              inputController: _inputController,
              inputFocusNode: _inputFocusNode,
              isAiProcessing: _isAiProcessing,
              editingMessageId: _editingMessageId,
              editingOriginalText: _editingOriginalText,
              replyToMessageId: _replyToMessageId,
              replyPreviewText: _replyPreviewText,
              onSend: _sendMessage,
              onCommitEdit: _commitEdit,
              onCancelEdit: _cancelEdit,
              onClearReply: _clearReply,
              onAttachMedia: _pickAndUploadMedia,
              onAiPressed: () => _showAiBottomSheet(context, scheme),
              onVoiceSend: _sendVoiceMessage,
              onCircleSend: _sendCircleVideo,
              hapticsEnabled:
                  ref.watch(uiSettingsProvider.select((s) => s.haptics)),
              sendOnEnter:
                  ref.watch(uiSettingsProvider.select((s) => s.sendOnEnter)),
              isSpamBlocked: ref.watch(authProvider
                  .select((a) => a.profile?.isRestrictedBySpamBlock ?? false)),
              spamBlockUntil: ref.watch(
                  authProvider.select((a) => a.profile?.spamBlockUntil)),
              spamBlockReason: ref.watch(
                  authProvider.select((a) => a.profile?.spamBlockReason)),
              onContactSupport: () => context.push('/chat/support'),
            );
          },
        ),
      ],
            ),
          ],
        ),
      ),
      backgroundColor: scheme.surface,
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

// ── Animated message entrance widget ────────────────────────────────────────
class _AnimatedMessage extends StatefulWidget {
  const _AnimatedMessage({
    super.key,
    required this.animate,
    required this.isMine,
    required this.child,
  });

  final bool animate;
  final bool isMine;
  final Widget child;

  @override
  State<_AnimatedMessage> createState() => _AnimatedMessageState();
}

class _AnimatedMessageState extends State<_AnimatedMessage>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fade;
  Animation<double>? _scale;
  Animation<Offset>? _slide;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      final ctrl = AnimationController(
        vsync: this,
        duration: M3Durations.medium3,
      );
      _controller = ctrl;
      _fade = CurvedAnimation(
        parent: ctrl,
        curve: const Interval(0.0, 0.65, curve: M3SpringCurves.gentle),
      );

      // MOM-1: Physical spring entrance from composer / origin
      if (widget.isMine) {
        _scale = Tween<double>(begin: 0.35, end: 1.0).animate(
          CurvedAnimation(parent: ctrl, curve: M3SpringCurves.emphasized),
        );
        _slide = Tween<Offset>(
          begin: const Offset(0.10, 0.35),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: ctrl, curve: M3SpringCurves.emphasized));
        TriSync.pop(context: context);
      } else {
        _scale = Tween<double>(begin: 0.55, end: 1.0).animate(
          CurvedAnimation(parent: ctrl, curve: M3SpringCurves.spatial),
        );
        _slide = Tween<Offset>(
          begin: const Offset(-0.06, 0.20),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: ctrl, curve: M3SpringCurves.spatial));
      }
      ctrl.forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || _controller == null) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fade!,
      child: SlideTransition(
        position: _slide!,
        child: ScaleTransition(
          scale: _scale!,
          alignment: widget.isMine ? Alignment.bottomRight : Alignment.bottomLeft,
          child: widget.child,
        ),
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
    final TypingState typing = ref.watch(typingProvider(chatId));
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int count = typing.typingUserIds.length;

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

// Helper widget for AI bottom sheet action cards
class _AiActionCard extends StatelessWidget {
  const _AiActionCard({
    required this.icon,
    required this.label,
    required this.scheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: <Widget>[
              Icon(icon, color: scheme.primary, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

