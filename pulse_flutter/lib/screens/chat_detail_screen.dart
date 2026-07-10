import 'package:pulse_flutter/widgets/chat/chat_detail_app_bar.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_fab.dart';
import 'package:pulse_flutter/widgets/chat/chat_detail_input_area.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:pulse_flutter/widgets/chat/chat_message_list.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/core/utils/draft_storage.dart';
import 'package:pulse_flutter/core/utils/file_opener.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';
import 'package:pulse_flutter/core/utils/image_compressor.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/desktop_chat_provider.dart';
import 'package:pulse_flutter/providers/typing_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/screens/media_viewer_screen.dart';
import 'package:pulse_flutter/widgets/m3_file_picker_bottom_sheet.dart';
import 'package:pulse_flutter/widgets/m3_file_preview_bottom_sheet.dart';
import 'package:pulse_flutter/widgets/message_context_menu_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';
import 'package:pulse_flutter/core/utils/screen_security_service.dart';
import 'package:pulse_flutter/widgets/offline_banner.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
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
    with WidgetsBindingObserver {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final FocusNode _inputFocusNode;

  // Cache providers that may be needed in dispose()
  late DraftStorage _draftStorage;

  Timer? _draftSaveTimer;
  String? _lastAiOriginalText;
  bool _showDraftRestoredBanner = false;

  bool _uploadingMedia = false;
  double _uploadProgress = 0;
  String? _uploadFileName;
  int? _uploadFileSize;

  int? _replyToMessageId;
  String? _replyPreviewText;

  // Inline edit mode
  int? _editingMessageId;
  String? _editingOriginalText;

  // Scroll-to-bottom FAB
  final ValueNotifier<bool> _showScrollToBottomNotifier = ValueNotifier<bool>(false);
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
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/main/chats');
  }

  String? _resolveDirectUsername(
    ApiChatSummary? chat,
    List<ApiMessage> messages,
    List<ApiChatMember> members,
    int myUserId,
  ) {
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _dateSeparatorLabel(resolvedDate, now),
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreDraft();
      _refreshNow();
      _applySecureFlag();
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
    WidgetsBinding.instance.removeObserver(this);
    _secretPollTimer?.cancel();
    _removeScreenshotOverlay();
    _showScrollToBottomNotifier.dispose();
    _loadingOlderNotifier.dispose();
    _draftSaveTimer?.cancel();
    _saveDraft();
    _scrollController.removeListener(_onScroll);
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
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

  void _showScreenshotOverlay() {
    if (_screenshotOverlay != null) return;
    _screenshotOverlay = OverlayEntry(
      builder: (_) => Container(
        color: Colors.black,
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

    _lastAiOriginalText = _inputController.text;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatAiProcessed),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: context.l10n.chatAiUndo,
              onPressed: _undoLastAiTransform,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatAiError('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAiProcessing = false;
        });
      }
    }
  }

  void _undoLastAiTransform() {
    final String? previous = _lastAiOriginalText;
    if (previous == null) return;
    _inputController.text = previous;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: previous.length),
    );
    _lastAiOriginalText = null;
  }

  void _showAiBottomSheet(BuildContext context, ColorScheme scheme) {
    if (_isInputEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
                  children: <(String, String, String)>[
                    ('translate:English', '🇬🇧', context.l10n.chatAiLangEn),
                    ('translate:Russian', '🇷🇺', context.l10n.chatAiLangRu),
                    ('translate:German', '🇩🇪', context.l10n.chatAiLangDe),
                    ('translate:French', '🇫🇷', context.l10n.chatAiLangFr),
                    ('translate:Spanish', '🇪🇸', context.l10n.chatAiLangEs),
                    ('translate:Chinese', '🇨🇳', context.l10n.chatAiLangZh),
                  ].map(
                    ((String, String, String) item) => ActionChip(
                      avatar: Text(item.$2, style: const TextStyle(fontSize: 16)),
                      label: Text(item.$3),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _processTextWithAi('translate', targetLanguage: item.$1.split(':')[1]);
                      },
                    ),
                  ).toList(),
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
      await ref.read(chatsProvider.notifier).refresh();
      await ref.read(chatMessagesProvider(chatId).notifier).refresh();
      await ref.read(chatMessagesProvider(chatId).notifier).markRead();
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

    final String text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
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
        final String message = error is ApiException
            ? error.message
            : context.l10n.commonFailed('$error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }),
    );
  }

  Future<void> _uploadAndSend({
    required int chatId,
    String? filePath,
    Stream<List<int>>? readStream,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    String text = '',
    bool showSentSnackBar = false,
  }) async {
    setState(() {
      _uploadingMedia = true;
      _uploadProgress = 0;
      _uploadFileName = filename;
      _uploadFileSize = fileSize;
    });

    try {
      final String uploadId = await ref
          .read(chatRepositoryProvider)
          .uploadStreamInChunks(
            readStream: readStream,
            filePath: filePath,
            filename: filename,
            mediaSubtype: mediaSubtype,
            fileSize: fileSize,
            onProgress: (int sent, int total) {
              if (!mounted || total <= 0) return;
              setState(() => _uploadProgress = sent / total);
            },
          );

      await ref
          .read(chatMessagesProvider(chatId).notifier)
          .send(text, replyToId: _replyToMessageId, uploadId: uploadId);

      _clearReply();
      _scrollToBottom();

      if (showSentSnackBar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatMediaSent)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final String message = error is ApiException
          ? error.message
          : context.l10n.commonFailed('$error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingMedia = false;
          _uploadProgress = 0;
          _uploadFileName = null;
          _uploadFileSize = null;
        });
      }
    }
  }

  Future<void> _sendVoiceMessage(String filePath) async {
    final int? chatId = _chatId;
    if (chatId == null || _uploadingMedia) return;

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
    if (chatId == null || _uploadingMedia) return;

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
      if (!mounted) {
        return false;
      }
      final String text = error is ApiException
          ? error.message
          : context.l10n.commonFailed('$error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } finally {
    }
    return true;
  }

  Future<void> _pickAndUploadMedia() async {
    final int? chatId = _chatId;
    if (chatId == null || _uploadingMedia) {
      return;
    }

    final M3FilePickerResult? result = await showM3FilePicker(context);
    if (result == null || !mounted) {
      return;
    }

    final String filename = result.fileName;
    final String mediaSubtype = result.mediaSubtype;

    String? uploadFilePath = result.filePath;
    Stream<List<int>>? uploadStream = result.readStream;
    int uploadFileSize = result.fileSize;

    if (uploadFilePath != null) {
      try {
        final File originalFile = File(uploadFilePath);
        final File? compressed = await ImageCompressor.compressImageFile(
          file: originalFile,
          fileName: filename,
        );
        if (compressed != null) {
          uploadFilePath = compressed.path;
          uploadFileSize = await compressed.length();
        }
      } catch (e, st) {
        debugPrint('Image compression failed: $e\n$st');
      }
    }

    await _uploadAndSend(
      chatId: chatId,
      filePath: uploadFilePath,
      readStream: uploadStream,
      filename: filename,
      mediaSubtype: mediaSubtype,
      fileSize: uploadFileSize,
      text: _inputController.text,
      showSentSnackBar: true,
    );

    if (mounted) _inputController.clear();
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
      final String text = error is ApiException
          ? error.message
          : context.l10n.commonFailed('$error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
      final String text = error is ApiException
          ? error.message
          : context.l10n.commonFailed('$error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
      final String text = error is ApiException
          ? error.message
          : context.l10n.commonFailed('$error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _setReply(ApiMessage message) {
    final String text = _displayText(message);
    setState(() {
      _replyToMessageId = message.id;
      _replyPreviewText =
          '${message.senderDisplayName}: ${text.length > 80 ? '${text.substring(0, 80)}...' : text}';
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

    final ApiChatSummary? target = await showModalBottomSheet<ApiChatSummary>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                context.l10n.chatForwardTo,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
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
          ),
        );
      },
    );

    if (target == null || !mounted) return;

    final String forwardText =
        '_fwd from ${message.senderDisplayName}: ${message.content}';
    try {
      await ref
          .read(chatMessagesProvider(target.id).notifier)
          .send(forwardText);
      await ref.read(chatsProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatMessageForwarded)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
    }
  }

  Future<void> _showMessageActions(
    ApiMessage message,
    bool isMine, {
    required bool isChannel,
    required bool amAdminOrOwner,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext ctx) => Padding(
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.chatMessageTextCopied)),
          );
        },
        onForward: () => _forwardMessage(message),
        onComments: () {
          final int? chatId = _chatId;
          if (chatId == null) return;
          context.push('/channel/$chatId/post/${message.id}/comments');
        },
        onEdit: () => _editMessage(message),
        onDelete: () => _deleteMessage(message),
      ),
      ),
    );
  }

  void _showAllReactionsPicker(ApiMessage message) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: EmojiPicker(
              onEmojiSelected: (Category? category, Emoji emoji) {
                Navigator.of(ctx).pop();
                _react(message, emoji.emoji);
              },
              config: Config(
                height: 320,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: scheme.surfaceContainerLow,
                  columns: 7,
                  emojiSizeMax: 28 * (Platform.isIOS ? 1.20 : 1.0),
                  verticalSpacing: 0,
                  horizontalSpacing: 0,
                  gridPadding: EdgeInsets.zero,
                  buttonMode: ButtonMode.MATERIAL,
                ),
                skinToneConfig: const SkinToneConfig(),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: scheme.surfaceContainerLow,
                  indicatorColor: scheme.primary,
                  iconColor: scheme.onSurfaceVariant,
                  iconColorSelected: scheme.primary,
                  backspaceColor: scheme.primary,
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  backgroundColor: scheme.surfaceContainerLow,
                  buttonIconColor: scheme.onSurfaceVariant,
                  buttonColor: scheme.surfaceContainerHigh,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: scheme.surfaceContainerLow,
                  buttonIconColor: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _displayText(ApiMessage message) {
    if (message.isDeleted) return context.l10n.chatMessageDeleted;
    if (message.msgType == 'call_log') return '';
    final String text = message.content.trim();
    final String? mediaUrl = _mediaUrlFor(message);
    if (text.isNotEmpty) {
      if (mediaUrl != null && text == mediaUrl) {
        return '';
      }
      if (mediaUrl != null && text.contains(mediaUrl)) {
        final String cleaned = text.replaceAll(mediaUrl, '').trim();
        return cleaned;
      }
      return text;
    }
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      return '';
    }
    if (message.isE2ee && message.content.isEmpty) {
      return '🔒 ${context.l10n.chatEncryptedMessage}';
    }
    return '[${message.msgType}]';
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
    return _extractUrlFromText(message.content.trim());
  }

  bool _isImageMedia(ApiMessage message, String mediaUrl) {
    final String mediaType = (message.mediaType ?? '').toLowerCase();
    if (mediaType.startsWith('image/')) {
      return true;
    }

    final String lower = mediaUrl.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp');
  }

  void _openMedia(ApiMessage message) {
    final String? mediaUrl = _mediaUrlFor(message);
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return;
    }

    final FileTypeInfo typeInfo = FileTypeDetector.detect(
      fileName: message.mediaName ?? 'file',
      mimeType: message.mediaType,
    );

    final String title = (message.mediaName ?? '').trim().isNotEmpty
        ? message.mediaName!.trim()
        : typeInfo.label;

    final int fileSize = message.mediaSize ?? 0;

    final MediaType mt = _detectMediaType(message, mediaUrl, typeInfo);
    if (mt == MediaType.image || mt == MediaType.video) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MediaViewerScreen(
            url: mediaUrl,
            title: title,
            mediaType: mt,
          ),
        ),
      );
      return;
    }

    showM3FilePreview(
      context: context,
      fileName: title,
      fileSize: fileSize,
      mediaUrl: mediaUrl,
      onForward: () => _forwardMessage(message),
    );
  }

  MediaType _detectMediaType(
    ApiMessage message,
    String url,
    FileTypeInfo typeInfo,
  ) {
    final String? mt = message.mediaType;
    if (mt != null) {
      if (mt.startsWith('image/')) return MediaType.image;
      if (mt.startsWith('video/')) return MediaType.video;
      if (mt == 'application/pdf') return MediaType.pdf;
    }

    final String ext = url.contains('.')
        ? '.${url.split('.').last.toLowerCase()}'
        : '';
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg']
        .contains(ext)) return MediaType.image;
    if (['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v']
        .contains(ext)) return MediaType.video;
    if (ext == '.pdf') return MediaType.pdf;

    if (_isImageMedia(message, url)) return MediaType.image;
    return MediaType.other;
  }

  Future<void> _showMediaActions(
    ApiMessage message,
    bool isMine, {
    required bool amAdminOrOwner,
  }) async {
    final String? mediaUrl = _mediaUrlFor(message);
    if (mediaUrl == null || mediaUrl.trim().isEmpty) {
      return;
    }
    final String fileName = (message.mediaName ?? '').trim().isNotEmpty
        ? message.mediaName!.trim()
        : _mediaLabel(message, mediaUrl);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
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
                    final ScaffoldMessengerState messenger =
                        ScaffoldMessenger.of(context);
                    final String copyLabel = context.l10n.mediaActionCopy;
                    Navigator.of(ctx).pop();
                    await Clipboard.setData(ClipboardData(text: mediaUrl));
                    messenger.showSnackBar(
                      SnackBar(content: Text(copyLabel)),
                    );
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

  String? _replyPreviewFor(ApiMessage message, Map<int, ApiMessage> byId) {
    final int? replyToId = message.replyToId;
    if (replyToId == null) {
      return null;
    }
    final ApiMessage? target = byId[replyToId];
    if (target == null) {
      return context.l10n.chatReplyToId(replyToId);
    }
    final String text = _displayText(target);
    return '${target.senderDisplayName}: ${text.length > 64 ? '${text.substring(0, 64)}...' : text}';
  }

  Future<void> _retrySend(ApiMessage message) async {
    if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
    final int? chatId = _chatId;
    if (chatId == null) return;
    ref.read(chatMessagesProvider(chatId).notifier).removeLocalMessage(message.id);
    await ref.read(chatMessagesProvider(chatId).notifier).send(message.content, replyToId: message.replyToId);
  }

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
          maxWidth: 1560,
          child: Center(child: Text(context.l10n.chatInvalidId)),
        ),
      );
    }

    final AuthState auth = ref.watch(authProvider);
    final chat = ref.watch(chatByIdProvider(chatId));
    final bool isChannel = chat?.chatType == 'channel';
    final bool isGroup = chat?.chatType == 'group';
    final bool showManage = isChannel || isGroup;
    final String myRole = ref.watch(myChatRoleProvider(chatId));
    final bool amAdminOrOwner = myRole == 'admin' || myRole == 'owner';
    final bool canPostInChannel = !isChannel || amAdminOrOwner;
    final AsyncValue<List<ApiMessage>> messagesAsync = ref.watch(
      chatMessagesProvider(chatId),
    );
    final List<ApiMessage> currentMessages =
        messagesAsync.value ?? const <ApiMessage>[];
    final List<ApiChatMember> members =
        ref.watch(chatMembersProvider(chatId)).value ?? const <ApiChatMember>[];

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final int myUserId = auth.session?.userId ?? -1;
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

    return PopScope(
      canPop: !_uploadingMedia,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool? confirm = await showAppConfirmDialog(
          context: context,
          title: context.l10n.dialogCancelChatCreationTitle,
          subtitle: context.l10n.dialogCancelChatCreationBody,
          confirmLabel: context.l10n.commonYes,
          cancelLabel: context.l10n.commonNo,
          icon: Icons.close_rounded,
        );
        if (confirm == true && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: ChatDetailAppBar(
          chatId: chatId,
          isDesktopSplit: widget.isDesktopSplit,
          title: title,
          avatarUrl: chat?.avatarUrl,
          headerIcon: _chatHeaderIcon(isChannel, isGroup),
          showManage: showManage,
          directUsername: directUsername,
          onBack: () {
            if (ref.read(uiSettingsProvider).haptics) HapticService.reaction();
            _goBack();
          },
          typingSubtitle: _TypingSubtitle(
            chatId: chatId,
            fallback: _chatSubtitle(
              chat,
              isChannel,
              isGroup,
              directUsername: directUsername,
            ),
          ),
        ),
      body: PulseScaffoldBody(
        maxWidth: 1560,
        bottomSafe: false,
        child: Column(
          children: <Widget>[
            OfflineBanner(isOffline: !(ref.watch(connectivityProvider).value ?? true)),
            if (chat?.isSecret == true)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: scheme.primaryContainer.withValues(alpha: 0.35),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.lock_rounded, size: 14, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.chatE2eeBanner,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Loading older messages indicator at top
            ValueListenableBuilder<bool>(
              valueListenable: _loadingOlderNotifier,
              builder: (context, isLoading, _) => AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: isLoading
                    ? const LinearProgressIndicator( minHeight: 2)
                    : const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  messagesAsync.when(
                    data: (List<ApiMessage> messages) {
                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 56,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.l10n.chatNoMessages,
                                style: textTheme.titleMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.l10n.chatSendFirst,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ChatMessageList(
                        messages: messages,
                        scrollController: _scrollController,
                        authUserId: auth.session?.userId ?? -1,
                        amAdminOrOwner: amAdminOrOwner,
                        isChannel: isChannel,
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
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            context.l10n.chatFailedLoadMessages('$error'),
                          ),
                        ),
                      );
                    },
                  ),
                  // Scroll-to-bottom FAB overlay
                  ValueListenableBuilder<bool>(
                    valueListenable: _showScrollToBottomNotifier,
                    builder: (context, showScroll, child) {
                      return ChatDetailScrollToBottomFAB(
                        show: showScroll,
                        chatId: chatId,
                        onPressed: _scrollToBottom,
                      );
                    },
                  ),
                ],
              ),
            ),
            ChatDetailInputArea(
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
              uploadingMedia: _uploadingMedia,
              uploadFileName: _uploadFileName,
              uploadFileSize: _uploadFileSize,
              uploadProgress: _uploadProgress,
              onCancelUpload: () {
                setState(() {
                  _uploadingMedia = false;
                  _uploadProgress = 0;
                  _uploadFileName = null;
                  _uploadFileSize = null;
                });
              },
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
              onCircleVideoSend: _sendCircleVideo,
              hapticsEnabled: ref.read(uiSettingsProvider).haptics,
            ),
          ],
        ),
      ),
      backgroundColor: scheme.surface,
    ),
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
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(widget.isMine ? 0.3 : -0.3, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class _TypingSubtitle extends ConsumerWidget {
  const _TypingSubtitle({required this.chatId, required this.fallback});
  final int chatId;
  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TypingState typing = ref.watch(typingProvider(chatId));
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int count = typing.typingUserIds.length;

    String text = fallback;
    if (count == 1) {
      text = context.l10n.chatTyping;
    } else if (count > 1) {
      text = context.l10n.chatTypingMultiple;
    }

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: count > 0 ? scheme.primary : scheme.onSurfaceVariant,
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
