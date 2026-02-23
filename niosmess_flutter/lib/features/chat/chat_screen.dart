import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/constants.dart';
import '../../core/models/message_item.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/settings_provider.dart';
import '../../core/session_provider.dart';
import '../../core/ai_summary_provider.dart';
import '../../core/bubble_style_provider.dart';
import '../../core/downloads_provider.dart';
import '../../core/obfuscate.dart';
import '../../core/send_queue_provider.dart';
import '../../ui/nios_ui.dart';
import '../../ui/widgets/chat_header_widget.dart';
import '../../ui/widgets/chat_input_widget.dart';
import '../../ui/widgets/ghost_mode_overlay.dart';
import '../../ui/widgets/media_viewer.dart';
import '../../ui/widgets/message_action_sheet.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    this.chatUsername,
    required this.onBack,
    required this.onOpenProfile,
    required this.chatType,
    this.title,
    this.status,
    this.badgeText,
    this.badgeIcon,
  });

  final String chatId;
  final String? chatUsername;
  final String chatType;
  final String? title;
  final String? status;
  final String? badgeText;
  final String? badgeIcon;
  final VoidCallback onBack;
  final void Function(String username) onOpenProfile;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _pollsKey = 'niosmess_polls_v1';
  static const _draftKeyPrefix = 'niosmess_draft_';
  static const _favoritesKeyPrefix = 'niosmess_favorites_';

  final api = ApiRepository();
  final controller = TextEditingController();
  final _searchController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<MessageItem> messages = [];
  String _searchQuery = '';
  bool loading = true;
  bool sending = false;
  bool _recording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  Timer? _networkTimer;
  bool _networkOnline = true;
  String? _recordPath;
  String? _currentAudioUrl;
  bool _autoPlayed = false;
  Uint8List? _headerAvatarBytes;

  final Map<String, PollState> _polls = {};
  final Map<String, Map<String, int>> _reactionCounts = {};
  final Map<String, Set<String>> _myReactions = {};
  final Set<String> _favorites = {};
  MessageItem? _replyTo;
  String? _pinnedMessageId;
  bool _searchOpen = false;
  bool _weeklyMomentLoading = false;
  List<Map<String, dynamic>> _weeklyMomentItems = [];
  bool _searchLoading = false;
  List<MessageItem> _searchResults = [];
  Timer? _searchTimer;
  Timer? _draftTimer;
  bool _weeklyRolesLoading = false;
  Map<String, String> _weeklyRoles = {};

  @override
  void initState() {
    super.initState();
    _loadPollCache();
    _loadFavorites();
    _loadDraft();
    _load();
    _loadHeaderAvatar();
    if (widget.chatType == 'channel') {
      _loadWeeklyMoment();
    }
    if (widget.chatType == 'group') {
      _loadWeeklyRoles();
    }
    _startNetworkWatch();
    // Initialize AI summary for this chat
    ref.read(aiSummaryProvider.notifier).loadForChat(widget.chatId);
  }

  Future<void> _loadHeaderAvatar() async {
    if (widget.chatType != 'user') return;
    final username = (widget.chatUsername ?? widget.chatId).trim();
    if (username.isEmpty) return;
    final bytes = await api.getAvatarBytes(username);
    if (mounted) {
      setState(() => _headerAvatarBytes = bytes);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    _searchController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    _networkTimer?.cancel();
    _searchTimer?.cancel();
    _draftTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPollCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pollsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      data.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          _polls[key] = PollState.fromJson(value);
        }
      });
      setState(() {});
    } catch (_) {}
  }

  Future<void> _savePollCache() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _polls.map((key, value) => MapEntry(key, value.toJson()));
    await prefs.setString(_pollsKey, jsonEncode(data));
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    try {
      final data = _isCollective(widget.chatId)
          ? await api.getCollectiveMessages(
              widget.chatId, session.username!, session.token!)
          : await api.getMessagesUser(
              session.username!, widget.chatId, session.token!);
      setState(() {
        messages = data;
        _updatePinnedFromMessages(data);
        loading = false;
      });
      await _loadReactions(data);
      _autoPlayFirstVoice();
    } catch (_) {
      final cached = await api.getCachedMessages(widget.chatId);
      setState(() {
        messages = cached;
        _updatePinnedFromMessages(cached);
        loading = false;
      });
      await _loadReactions(cached);
    }
  }

  List<MessageItem> _withQueuedMessages(List<MessageItem> base) {
    final queue = ref.read(sendQueueProvider);
    final failed = ref.read(sendQueueProvider.notifier);
    if (queue.isEmpty) return base;
    final session = ref.read(sessionProvider);
    final queued =
        queue.where((item) => item.chatId == widget.chatId).map((item) {
      final localStatus = failed.isFailed(item.id)
          ? MessageLocalStatus.failed
          : MessageLocalStatus.queued;
      return MessageItem(
        id: 'local_${item.id}',
        sender: session.username ?? '',
        text: item.text,
        time: item.createdAt.toString(),
        type: item.msgType,
        lat: item.lat,
        lon: item.lon,
        contactData: item.contactData,
        replyToId: item.replyTo,
        meta: {'outbox_id': item.id},
        localStatus: localStatus,
        isOutgoing: true,
      );
    }).toList();
    return [...queued, ...base];
  }

  bool _isCollective(String chatId) =>
      widget.chatType == 'group' ||
      widget.chatType == 'channel' ||
      chatId.startsWith('group_') ||
      chatId.startsWith('channel_');

  Future<void> _loadReactions(List<MessageItem> items) async {
    if (items.isEmpty) return;
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    try {
      final res = await api.getReactionsBatch(
        username: session.username!,
        token: session.token!,
        messageIds: items.map((m) => m.id).toList(),
        chatId: _isCollective(widget.chatId) ? widget.chatId : null,
        collective: _isCollective(widget.chatId),
      );
      final data = res['data'];
      if (data is Map) {
        data.forEach((messageId, payload) {
          if (payload is Map) {
            final countsRaw = payload['counts'];
            final mineRaw = payload['mine'];
            if (countsRaw is Map) {
              _reactionCounts[messageId.toString()] = countsRaw.map(
                (key, value) =>
                    MapEntry(key.toString(), (value as num).toInt()),
              );
            }
            if (mineRaw is Map) {
              _myReactions[messageId.toString()] =
                  mineRaw.keys.map((e) => e.toString()).toSet();
            }
          }
        });
        if (mounted) setState(() {});
      }
    } catch (_) {
      // ignore, keep existing state
    }
  }

  Future<void> _loadWeeklyMoment() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    setState(() => _weeklyMomentLoading = true);
    try {
      final res = await api.getWeeklyMoment(
        chatId: widget.chatId,
        username: session.username!,
        token: session.token!,
      );
      final raw = res['items'];
      if (!mounted) return;
      if (raw is List) {
        _weeklyMomentItems =
            raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        _weeklyMomentItems = [];
      }
      setState(() => _weeklyMomentLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _weeklyMomentLoading = false);
    }
  }

  Future<void> _loadWeeklyRoles() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    setState(() => _weeklyRolesLoading = true);
    try {
      final res = await api.getWeeklyRoles(
        chatId: widget.chatId,
        username: session.username!,
        token: session.token!,
      );
      final raw = res['roles'];
      if (!mounted) return;
      final roles = <String, String>{};
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final role = item['role']?.toString() ?? '';
            final user = item['username']?.toString() ?? '';
            if (role.isNotEmpty && user.isNotEmpty) {
              roles[role] = user;
            }
          }
        }
      }
      setState(() {
        _weeklyRoles = roles;
        _weeklyRolesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _weeklyRolesLoading = false);
    }
  }

  void _startNetworkWatch() {
    _checkNetwork();
    _networkTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _checkNetwork());
  }

  Future<void> _checkNetwork() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    try {
      await api.checkSession(session.username!, session.token!);
      if (mounted) setState(() => _networkOnline = true);
    } catch (_) {
      if (mounted) setState(() => _networkOnline = false);
    }
  }

  Future<void> _send({
    String? overrideText,
    String? msgType,
    double? lat,
    double? lon,
    String? contactData,
  }) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed || sending) return;
    var text = (overrideText ?? controller.text).trim();
    if (_shouldTrimSpaces(text)) {
      text = _collapseSpaces(text);
    }
    if (text.isEmpty) return;
    final replyId = _replyTo?.id;
    if (overrideText == null) {
      controller.clear();
      _saveDraft();
    }
    setState(() => sending = true);
    try {
      if (_isCollective(widget.chatId)) {
        await api.sendCollective(
          widget.chatId,
          session.username!,
          text,
          session.token!,
          replyTo: replyId,
          msgType: msgType,
          lat: lat,
          lon: lon,
          contactData: contactData,
        );
      } else {
        await api.sendMessageUser(
          session.username!,
          widget.chatId,
          text,
          session.token!,
          replyTo: replyId,
          msgType: msgType,
          lat: lat,
          lon: lon,
          contactData: contactData,
        );
      }
      _replyTo = null;
      await _load();
    } catch (_) {
      final queue = ref.read(sendQueueProvider.notifier);
      final outboxId = DateTime.now().millisecondsSinceEpoch.toString();
      await queue.enqueue(
        OutboxItem(
          id: outboxId,
          chatId: widget.chatId,
          chatType: widget.chatType,
          text: text,
          replyTo: replyId?.toString(),
          msgType: msgType,
          lat: lat,
          lon: lon,
          contactData: contactData,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Сообщение в очереди отправки')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  bool _shouldTrimSpaces(String text) {
    final settings = ref.read(settingsProvider);
    final trimSpaces = (settings['trim_spaces'] as bool?) ?? false;
    if (!trimSpaces) return false;
    final upper = text.toUpperCase();
    return !(upper.startsWith('POLL:') ||
        upper.startsWith('LOCATION:') ||
        upper.startsWith('CONTACT:') ||
        upper.startsWith('MEDIA:') ||
        upper.startsWith('FILE:'));
  }

  String _collapseSpaces(String text) {
    return text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\\s+\\n'), '\n')
        .trim();
  }

  String _mediaUrl(String filename) {
    final base = AppConfig.apiBase;
    return '$base/download/$filename';
  }

  Map<String, String> get _mediaHeaders {
    final session = ref.read(sessionProvider);
    if (session.isAuthed && session.username != null && session.token != null) {
      return {
        'X-Username': session.username!,
        'X-Session-Token': session.token!,
      };
    }
    return {};
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _getLocalDownloadPath(String filename) {
    final local = ref.read(downloadsProvider).local;
    for (final entry in local) {
      if (entry.filename == filename &&
          entry.path != null &&
          entry.path!.isNotEmpty) {
        return entry.path;
      }
    }
    return null;
  }

  bool _isImageFile(String filename) {
    final ext = filename.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.bmp');
  }

  bool _isVideoFile(String filename) {
    final ext = filename.toLowerCase();
    return ext.endsWith('.mp4') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.mkv') ||
        ext.endsWith('.webm');
  }

  MediaViewerType? _getMediaType(String filename) {
    if (_isImageFile(filename)) return MediaViewerType.image;
    if (_isVideoFile(filename)) return MediaViewerType.video;
    if (_isAudioFile(filename)) return MediaViewerType.audio;
    return null;
  }

  Future<void> _openFile(String filename) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;

    final mediaType = _getMediaType(filename);

    // For images, try network URL first (no download needed)
    if (mediaType == MediaViewerType.image) {
      MediaViewer.open(
        context,
        source: _mediaUrl(filename),
        type: MediaViewerType.image,
        title: filename,
      );
      return;
    }

    try {
      var path = _getLocalDownloadPath(filename);
      if (path == null || path.isEmpty || !File(path).existsSync()) {
        path = await api.downloadFile(
          filename: filename,
          username: session.username!,
          token: session.token!,
        );
        final file = File(path);
        final size = await file.length();
        await ref.read(downloadsProvider.notifier).addLocalDownload(
              filename: filename,
              path: path,
              size: size,
            );
      }

      if (!mounted) return;

      // Open in-app viewer for media files
      if (mediaType != null) {
        MediaViewer.open(
          context,
          source: path,
          type: mediaType,
          title: filename,
        );
        return;
      }

      // Fallback to external app for other file types
      final result = await OpenFilex.open(path);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть файл')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть файл')),
      );
    }
  }

  Future<void> _downloadFile(String filename) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    try {
      final path = await api.downloadFile(
        filename: filename,
        username: session.username!,
        token: session.token!,
      );
      final file = File(path);
      final size = await file.length();
      await ref.read(downloadsProvider.notifier).addLocalDownload(
            filename: filename,
            path: path,
            size: size,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Файл сохранен')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Не удалось скачать файл')),
      );
    }
  }

  bool _isAudioFile(String filename) {
    final ext = filename.toLowerCase();
    return ext.endsWith('.mp3') ||
        ext.endsWith('.wav') ||
        ext.endsWith('.ogg') ||
        ext.endsWith('.m4a') ||
        ext.endsWith('.aac');
  }

  Future<void> _playAudio(String url) async {
    try {
      if (_currentAudioUrl == url && _audioPlayer.playing) {
        await _audioPlayer.pause();
        setState(() {});
        return;
      }
      if (_currentAudioUrl != url) {
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(url);
        _currentAudioUrl = url;
      }
      await _audioPlayer.play();
      setState(() {});
    } catch (_) {}
  }

  void _autoPlayFirstVoice() {
    if (_autoPlayed || messages.isEmpty) return;
    for (final msg in messages) {
      final payload = _parsePayload(msg);
      if (payload.type == 'file' || payload.type == 'media') {
        final filename = payload.type == 'file'
            ? payload.data
            : _extractFilename(payload.data);
        if (filename != null && _isAudioFile(filename)) {
          _autoPlayed = true;
          _playAudio(_mediaUrl(filename));
          break;
        }
      }
    }
  }

  String? _extractFilename(String raw) {
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      return parsed['filename']?.toString() ?? parsed['file']?.toString();
    } catch (_) {
      return raw.isEmpty ? null : raw;
    }
  }

  Future<void> _toggleReaction(MessageItem message, String emoji) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    final mine = _myReactions.putIfAbsent(message.id, () => <String>{});
    final active = !mine.contains(emoji);
    if (active) {
      mine.add(emoji);
    } else {
      mine.remove(emoji);
    }
    setState(() {});
    try {
      final res = await api.reactMessage(
        username: session.username!,
        token: session.token!,
        messageId: message.id,
        emoji: emoji,
        active: active,
        chatId: _isCollective(widget.chatId) ? widget.chatId : null,
        collective: _isCollective(widget.chatId),
      );
      final countsRaw = res['counts'];
      final mineRaw = res['mine'];
      if (countsRaw is Map) {
        _reactionCounts[message.id] = countsRaw.map(
            (key, value) => MapEntry(key.toString(), (value as num).toInt()));
      }
      if (mineRaw is Map) {
        _myReactions[message.id] =
            mineRaw.keys.map((e) => e.toString()).toSet();
      }
      if (mounted) setState(() {});
    } catch (_) {
      // ignore network errors, keep optimistic state
    }
  }

  void _showMessageMenu(MessageItem message) {
    final session = ref.read(sessionProvider);
    final reduceMotion =
        (ref.read(settingsProvider)['reduce_motion'] as bool?) ?? false;
    final isOwn = session.username == message.sender;
    final isFavorite = _favorites.contains(message.id);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        final quick = <MessageActionItem>[
          MessageActionItem(
            label: 'Ответить',
            icon: Icons.reply,
            onTap: () {
              Navigator.pop(context);
              setState(() => _replyTo = message);
            },
          ),
          MessageActionItem(
            label: 'Копировать',
            icon: Icons.copy,
            onTap: () async {
              Navigator.pop(context);
              await Clipboard.setData(ClipboardData(text: message.text));
            },
          ),
          MessageActionItem(
            label: 'Переслать',
            icon: Icons.forward,
            onTap: () {
              Navigator.pop(context);
              _openForwardModal(message);
            },
          ),
          MessageActionItem(
            label: isFavorite ? 'Убрать из избранного' : 'В избранное',
            icon: Icons.star_border,
            onTap: () {
              Navigator.pop(context);
              _toggleFavorite(message);
            },
          ),
        ];
        final own = <MessageActionItem>[
          if (isOwn)
            MessageActionItem(
              label: 'Редактировать',
              icon: Icons.edit,
              onTap: () {
                Navigator.pop(context);
                _editMessage(message);
              },
            ),
          MessageActionItem(
            label: message.isPinned == true ? 'Открепить' : 'Закрепить',
            icon: Icons.push_pin_outlined,
            onTap: () {
              Navigator.pop(context);
              _togglePinMessage(message);
            },
          ),
        ];
        final danger = <MessageActionItem>[
          MessageActionItem(
            label: 'Удалить',
            icon: Icons.delete_outline,
            danger: true,
            onTap: () {
              Navigator.pop(context);
              _deleteMessage(message);
            },
          ),
        ];
        return MessageActionSheet(
          preview: message.text,
          reactions: _buildReactionRow(message),
          quickActions: quick,
          ownActions: own,
          dangerActions: danger,
          reduceMotion: reduceMotion,
        );
      },
    );
  }

  Widget _menuButton(String text, IconData icon, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: NiosPalette.textSecondary),
      title: Text(text, style: TextStyle(color: NiosPalette.text)),
      onTap: onTap,
    );
  }

  Future<void> _editMessage(MessageItem message) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    final controller = TextEditingController(text: message.text);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: NiosPalette.surface,
        title: Text(
            'Редактировать',
            style: TextStyle(color: NiosPalette.text)),
        content: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 4,
          decoration: niosInputDecoration(
              'Текст сообщения'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                  'Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text(
                  'Сохранить')),
        ],
      ),
    );
    if (result == null) return;
    final text = result.trim();
    if (text.isEmpty) return;
    await api.editMessage(
      username: session.username!,
      token: session.token!,
      messageId: message.id,
      text: text,
    );
    await _load();
  }

  Future<void> _deleteMessage(MessageItem message) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: NiosPalette.surface,
        title: Text(
            'Удалить сообщение?',
            style: TextStyle(color: NiosPalette.text)),
        content: Text(
            'Сообщение будет удалено только у вас, если это позволяет сервер.',
            style: TextStyle(color: NiosPalette.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                  'Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                  'Удалить')),
        ],
      ),
    );
    if (confirm != true) return;
    await api.deleteMessage(
      username: session.username!,
      token: session.token!,
      messageId: message.id,
    );
    _favorites.remove(message.id);
    await _saveFavorites();
    await _load();
  }

  Future<void> _toggleFavorite(MessageItem message) async {
    if (_favorites.contains(message.id)) {
      _favorites.remove(message.id);
    } else {
      _favorites.add(message.id);
    }
    await _saveFavorites();
    if (mounted) setState(() {});
  }

  Future<void> _togglePinMessage(MessageItem message) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    await api.pinMessage(
      username: session.username!,
      token: session.token!,
      chatId: widget.chatId,
      chatType: widget.chatType,
      messageId: message.id,
      pinned: !(message.isPinned == true),
    );
    await _load();
  }

  Widget _buildReactionRow(MessageItem message) {
    final emojis = [
      '👍',
      '❤️',
      '😂',
      '😮',
      '😢',
      '😡'
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: emojis.map((emoji) {
        return GestureDetector(
          onTap: () async {
            await _toggleReaction(message, emoji);
            if (mounted) Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: NiosPalette.surfaceHover,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
        );
      }).toList(),
    );
  }

  void _openForwardModal(MessageItem message) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: NiosPalette.surface,
          title: Text(
              'Переслать',
              style: TextStyle(color: NiosPalette.text)),
          content: TextField(
            controller: controller,
            decoration: niosInputDecoration('chat_id'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                  'Отмена'),
            ),
            TextButton(
              onPressed: () async {
                final session = ref.read(sessionProvider);
                if (!session.isAuthed) return;
                final target = controller.text.trim();
                if (target.isEmpty) return;
                final targetType = target.startsWith('group_')
                    ? 'group'
                    : target.startsWith('channel_')
                        ? 'channel'
                        : 'user';
                final forwardFrom = _isCollective(widget.chatId)
                    ? widget.chatId
                    : message.sender;
                try {
                  await api.forwardMessage(
                    username: session.username!,
                    token: session.token!,
                    chatId: target,
                    chatType: targetType,
                    forwardFrom: forwardFrom,
                    messageId: message.id,
                    forwardChatType: widget.chatType,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Не удалось переслать сообщение')),
                  );
                }
              },
              child: const Text(
                  'Отправить'),
            ),
          ],
        );
      },
    );
  }

  void _openAttachMenu() {
    final reduceMotion =
        (ref.read(settingsProvider)['reduce_motion'] as bool?) ?? false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final items = [
          _AttachItem(
              'Опрос',
              Icons.poll,
              _openPollModal),
          _AttachItem(
              'Геометка',
              Icons.place,
              _sendLocation),
          _AttachItem(
              'Файл',
              Icons.insert_drive_file,
              _pickAndUploadFile),
          _AttachItem(
              'Контакт',
              Icons.person,
              _sendContact),
        ];
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: NiosPalette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: NiosPalette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.9, end: 1),
                    duration: Duration(
                        milliseconds: reduceMotion ? 0 : 220 + (index * 40)),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Opacity(
                          opacity: value.clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await item.onTap();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          color: NiosPalette.surfaceHover,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: NiosPalette.borderLight),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item.icon, color: NiosPalette.textSecondary),
                            const SizedBox(height: 8),
                            Text(
                              item.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: NiosPalette.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openEmojiPicker() {
    const emojis = [
      '😀',
      '😅',
      '😂',
      '🤣',
      '😊',
      '😍',
      '😘',
      '😎',
      '🤔',
      '😴',
      '👍',
      '👎',
      '👏',
      '🙏',
      '💪',
      '🔥',
      '🎉',
      '✨',
      '💯',
      '✅',
      '❤️',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '🖤',
      '🤍',
      '🤎',
      '💔',
      '😢',
      '😭',
      '😡',
      '🤬',
      '😱',
      '😇',
      '🤗',
      '😜',
      '🤩',
      '🥳',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: NiosPalette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: NiosPalette.border),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: emojis.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (_, index) {
              final emoji = emojis[index];
              return InkWell(
                onTap: () {
                  _insertText(emoji);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(10),
                child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 20))),
              );
            },
          ),
        );
      },
    );
  }

  void _insertText(String value) {
    final selection = controller.selection;
    final text = controller.text;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, value);
    controller.text = newText;
    controller.selection =
        TextSelection.collapsed(offset: start + value.length);
  }

  Future<void> _scheduleSend() async {
    if (controller.text.trim().isEmpty) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    final now = DateTime.now();
    var target =
        DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    final delay = target.difference(now);
    final scheduledText = controller.text;
    controller.clear();
    _saveDraft();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Сообщение будет отправлено в ${picked.format(context)}')),
    );
    Timer(delay, () {
      if (!mounted) return;
      _send(overrideText: scheduledText);
    });
  }

  Future<void> _requestCall() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    if (widget.chatType != 'user') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Звонки доступны только в личных чатах')),
      );
      return;
    }
    try {
      await api.requestCall(
        caller: session.username!,
        callee: widget.chatId,
        token: session.token!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Запрос звонка отправлен')),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Не удалось отправить звонок')),
      );
    }
  }

  Future<void> _pickAndUploadFile() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final path = picked.path;
    if (path == null || path.isEmpty) return;
    setState(() => sending = true);
    try {
      await api.uploadFile(
        sender: session.username!,
        receiver: widget.chatId,
        token: session.token!,
        filePath: path,
        replyTo: _replyTo?.id,
      );
      _replyTo = null;
      await _load();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _openPollModal() async {
    final questionController = TextEditingController();
    final options = <TextEditingController>[
      TextEditingController(),
      TextEditingController()
    ];
    bool multiple = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: NiosPalette.surface,
            title: Text(
                'Новый опрос',
                style: TextStyle(color: NiosPalette.text)),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: questionController,
                    decoration: niosInputDecoration(
                        'Вопрос'),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: List.generate(options.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: options[i],
                          decoration: niosInputDecoration(
                              'Вариант'),
                        ),
                      );
                    }),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setStateDialog(
                          () => options.add(TextEditingController())),
                      child: const Text(
                          'Добавить вариант'),
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: multiple,
                        onChanged: (val) =>
                            setStateDialog(() => multiple = val ?? false),
                      ),
                      Text(
                          'Можно несколько',
                          style: TextStyle(color: NiosPalette.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                      'Отмена')),
              TextButton(
                onPressed: () async {
                  final question = questionController.text.trim();
                  final opts = options
                      .map((e) => e.text.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  if (question.isEmpty || opts.length < 2) return;
                  final payload = {
                    'id': 'poll_${DateTime.now().millisecondsSinceEpoch}',
                    'question': question,
                    'options': opts
                        .map((e) => {
                              'id':
                                  'opt_${DateTime.now().microsecondsSinceEpoch}_${opts.indexOf(e)}',
                              'text': e,
                            })
                        .toList(),
                    'multiple': multiple,
                  };
                  final poll = PollState.fromJson(payload);
                  _polls[poll.id] = poll;
                  await _savePollCache();
                  controller.text = 'POLL:${jsonEncode(payload)}';
                  Navigator.pop(context);
                  await _send();
                },
                child: const Text(
                    'Создать'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _sendLocation() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Сервис геолокации выключен')),
      );
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Нет доступа к геолокации')),
      );
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    final payload = {
      'lat': position.latitude,
      'lon': position.longitude,
      'label':
          'Моя локация',
    };
    await _send(
      overrideText: payload['label'] as String,
      msgType: 'location',
      lat: position.latitude,
      lon: position.longitude,
      contactData: jsonEncode(payload),
    );
  }

  Future<void> _sendContact() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    if (!await FlutterContacts.requestPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Нет доступа к контактам')),
      );
      return;
    }
    final contact = await FlutterContacts.openExternalPick();
    if (contact == null) return;
    final payload = {
      'name': contact.displayName,
      'phones': contact.phones.map((e) => e.number).toList(),
      'emails': contact.emails.map((e) => e.address).toList(),
    };
    await _send(
      overrideText: contact.displayName,
      msgType: 'contact',
      contactData: jsonEncode(payload),
    );
  }

  Future<void> _toggleRecord() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed || sending) return;
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return;

    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      _recordTimer?.cancel();
      if (path == null) return;
      _recordPath = null;
      _recordDuration = Duration.zero;
      await api.uploadFile(
        sender: session.username!,
        receiver: widget.chatId,
        token: session.token!,
        filePath: path,
        replyTo: _replyTo?.id,
      );
      _replyTo = null;
      await _load();
      return;
    }

    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );
    _recordPath = filePath;
    _recordDuration = Duration.zero;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _recordDuration += const Duration(seconds: 1);
      });
    });
    setState(() => _recording = true);
  }

  Future<void> _cancelRecording() async {
    if (!_recording) return;
    final path = await _recorder.stop();
    _recordTimer?.cancel();
    _recordDuration = Duration.zero;
    setState(() => _recording = false);
    final target = path ?? _recordPath;
    _recordPath = null;
    if (target != null) {
      try {
        final file = File(target);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.read(sessionProvider);
    final settings = ref.watch(settingsProvider);
    final bubbleStyle = ref.watch(bubbleStyleProvider);
    final reduceMotion = (settings['reduce_motion'] as bool?) ?? false;
    final compactMessages = (settings['compact_messages'] as bool?) ?? false;
    final linkPreview = (settings['link_preview'] as bool?) ?? true;
    final enterToSend = (settings['enter_to_send'] as bool?) ?? false;
    final visibleMessages = _visibleMessages();
    final outboxCount = ref
        .watch(sendQueueProvider)
        .where((item) => item.chatId == widget.chatId)
        .length;

    // Watch AI summary provider
    final aiSummary = ref.watch(aiSummaryProvider);

    final content = NiosScaffold(
      body: Column(
        children: [
          // New Telegram-style header
          RepaintBoundary(
            child: ChatHeaderWidget(
              title: widget.title ?? widget.chatId,
              status: widget.status,
              chatType: widget.chatType,
              chatUsername: widget.chatUsername,
              avatarBytes: _headerAvatarBytes,
              badgeText: widget.badgeText,
              badgeIcon: widget.badgeIcon,
              heroTag: 'chat_avatar_${widget.chatId}',
              queueCount: outboxCount,
              networkOnline: _networkOnline,
              onBack: widget.onBack,
              onSearch: _toggleSearchBar,
              onCall: _requestCall,
              onMenu: _openChatMenu,
              onAvatarTap: widget.chatType == 'user'
                  ? () =>
                      widget.onOpenProfile(widget.chatUsername ?? widget.chatId)
                  : null,
              reduceMotion: reduceMotion,
            ),
          ),

          _buildSearchBar(reduceMotion: reduceMotion),
          _buildPinnedBar(),
          if (widget.chatType == 'channel') _buildWeeklyMomentCard(),
          if (widget.chatType == 'group') _buildWeeklyRolesCard(),

          if (aiSummary.isExpanded && aiSummary.hasSummary)
            _buildAiSummaryCard(aiSummary),

          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: reduceMotion ? 0 : 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: loading
                  ? const Center(
                      key: ValueKey('loading'),
                      child: CircularProgressIndicator())
                  : ListView.builder(
                      key: const ValueKey('messages'),
                      padding: EdgeInsets.symmetric(
                          horizontal: compactMessages ? 12 : 16,
                          vertical: compactMessages ? 8 : 12),
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      addSemanticIndexes: false,
                      cacheExtent: 1600,
                      physics: const BouncingScrollPhysics(),
                      itemCount: visibleMessages.length,
                      itemBuilder: (_, i) {
                        final m = visibleMessages[i];
                        final isOwn = m.sender == session.username;
                        return RepaintBoundary(
                          child: Align(
                            alignment: isOwn
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () => _retryOutboxMessage(m),
                              onLongPress: () => _showMessageMenu(m),
                              child: Column(
                                crossAxisAlignment: isOwn
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  _buildMessageBubble(
                                    m,
                                    isOwn,
                                    bubbleStyle: bubbleStyle,
                                    compact: compactMessages,
                                    linkPreview: linkPreview,
                                  ),
                                  _buildReactions(m),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // New Telegram-style input
          ChatInputWidget(
            controller: controller,
            isRecording: _recording,
            recordDuration: _recordDuration,
            replyTo: _replyTo,
            onSend: _send,
            onEmoji: _openEmojiPicker,
            onAttach: _openAttachMenu,
            onRecord: _toggleRecord,
            onCancelRecord: _cancelRecording,
            onClearReply: () => setState(() => _replyTo = null),
            sending: sending,
            enterToSend: enterToSend,
          ),
        ],
      ),
    );

    return GhostModeOverlay(
      chatId: widget.chatId,
      child: content,
    );
  }

  List<MessageItem> _visibleMessages() {
    final merged = _withQueuedMessages(messages);
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return merged;
    if (_searchResults.isNotEmpty) return _searchResults;
    return merged.where((m) => m.text.toLowerCase().contains(query)).toList();
  }

  String get _draftKey => '$_draftKeyPrefix${widget.chatId}';
  String get _favoritesKey => '$_favoritesKeyPrefix${widget.chatId}';

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favoritesKey) ?? [];
    _favorites
      ..clear()
      ..addAll(raw);
    if (mounted) setState(() {});
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favorites.toList());
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw != null && raw.isNotEmpty) {
      controller.text = raw;
      controller.selection =
          TextSelection.collapsed(offset: controller.text.length);
    }
    controller.addListener(_scheduleDraftSave);
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _saveDraft);
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = ref.read(settingsProvider);
    final autosave = (settings['autosave_drafts'] as bool?) ?? true;
    if (!autosave) return;
    final text = controller.text;
    if (text.trim().isEmpty) {
      await prefs.remove(_draftKey);
    } else {
      await prefs.setString(_draftKey, text);
    }
  }

  void _updatePinnedFromMessages(List<MessageItem> data) {
    final pinned = data.where((m) => m.isPinned == true).toList();
    _pinnedMessageId = pinned.isNotEmpty ? pinned.first.id : null;
  }

  void _toggleSearchBar() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (_searchOpen) {
        _searchController.text = _searchQuery;
        _searchController.selection =
            TextSelection.collapsed(offset: _searchController.text.length);
      }
    });
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 350), _searchMessages);
  }

  Future<void> _searchMessages() async {
    final session = ref.read(sessionProvider);
    final query = _searchQuery.trim();
    if (!session.isAuthed || query.isEmpty) return;
    setState(() => _searchLoading = true);
    try {
      final results = await api.searchMessages(
        chatId: widget.chatId,
        query: query,
        username: session.username!,
        token: session.token!,
        chatType: widget.chatType,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchLoading = false);
    }
  }

  Widget _buildSearchBar({required bool reduceMotion}) {
    if (!_searchOpen) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: Duration(milliseconds: reduceMotion ? 0 : 220),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: niosInputDecoration(
                      'Поиск в чате',
                      icon: Icons.search),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchResults = [];
                    _searchController.clear();
                    _searchOpen = false;
                    _searchLoading = false;
                  });
                },
                icon: Icon(Icons.close, color: NiosPalette.textSecondary),
              ),
            ],
          ),
          if (_searchLoading)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildPinnedBar() {
    if (_pinnedMessageId == null) return const SizedBox.shrink();
    MessageItem? pinned;
    for (final m in messages) {
      if (m.id == _pinnedMessageId) {
        pinned = m;
        break;
      }
    }
    if (pinned == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NiosPalette.surfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NiosPalette.borderLight),
      ),
      child: Row(
        children: [
          Icon(Icons.push_pin, size: 16, color: NiosPalette.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pinned.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyMomentCard() {
    if (_weeklyMomentLoading) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: NiosPalette.surfaceHover,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NiosPalette.borderLight),
        ),
        child: const LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_weeklyMomentItems.isEmpty) return const SizedBox.shrink();
    final items = _weeklyMomentItems.take(3).toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NiosPalette.surfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NiosPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Момент недели',
            style: TextStyle(
              color: NiosPalette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map((item) {
            final rawText = item['text']?.toString() ?? '';
            final text = Obfuscator.deobfuscate(rawText);
            final type = item['type']?.toString() ?? 'text';
            final reactions = (item['reactions'] as num?)?.toInt() ?? 0;
            final preview = type == 'file'
                ? 'Файл'
                : type == 'media'
                    ? 'Медиа'
                    : type == 'call'
                        ? 'Звонок'
                        : text;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: NiosPalette.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (reactions > 0)
                    Text(
                      '❤ $reactions',
                      style: TextStyle(color: NiosPalette.textSecondary),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildWeeklyRolesCard() {
    if (_weeklyRolesLoading) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: NiosPalette.surfaceHover,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NiosPalette.borderLight),
        ),
        child: const LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_weeklyRoles.isEmpty) return const SizedBox.shrink();
    final editor = _weeklyRoles['editor'];
    final moderator = _weeklyRoles['moderator'];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NiosPalette.surfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NiosPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Роли недели',
            style: TextStyle(
              color: NiosPalette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (editor != null)
            Text(
              'Редактор: $editor',
              style: TextStyle(color: NiosPalette.textSecondary),
            ),
          if (moderator != null)
            Text(
              'Модератор: $moderator',
              style: TextStyle(color: NiosPalette.textSecondary),
            ),
        ],
      ),
    );
  }

  void _openChatMenu() {
    final aiSummary = ref.read(aiSummaryProvider);
    final showAi = messages.length >= 10;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: NiosPalette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: NiosPalette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.chatType == 'user')
              _menuButton(
                  'Открыть профиль',
                  Icons.account_circle_outlined, () {
                Navigator.pop(context);
                widget.onOpenProfile(widget.chatUsername ?? widget.chatId);
              }),
            if (showAi)
              _menuButton(
                  aiSummary.isExpanded
                      ? 'Скрыть AI сводку'
                      : 'AI сводка',
                  Icons.auto_awesome, () {
                Navigator.pop(context);
                if (aiSummary.isExpanded) {
                  ref.read(aiSummaryProvider.notifier).setExpanded(false);
                  return;
                }
                ref.read(aiSummaryProvider.notifier).generateSummary(
                      widget.chatId,
                      messages.map((m) => m.toJson()).toList(),
                    );
              }),
            _menuButton(
                'Обновить чат',
                Icons.refresh, () async {
              Navigator.pop(context);
              await _load();
            }),
            _menuButton(
                'Сбросить поиск',
                Icons.search_off, () {
              Navigator.pop(context);
              setState(() => _searchQuery = '');
            }),
          ],
        ),
      ),
    );
  }

  // Header replaced by ChatHeaderWidget

  Widget _buildMessageBubble(
    MessageItem m,
    bool isOwn, {
    required BubbleStyleState bubbleStyle,
    required bool compact,
    required bool linkPreview,
  }) {
    final payload = _parsePayload(m);
    final content =
        _buildMessageContent(m, payload, isOwn, linkPreview: linkPreview);
    final maxWidth = MediaQuery.of(context).size.width * 0.86;
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isOwn
        ? (bubbleStyle.customOutgoingColor ?? colorScheme.primaryContainer)
        : (bubbleStyle.customIncomingColor ?? colorScheme.surfaceVariant);
    final textColor =
        isOwn ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth < 420 ? maxWidth : 420),
      margin: EdgeInsets.symmetric(vertical: compact ? 3 : 6),
      padding: EdgeInsets.all(compact ? 9 : bubbleStyle.bubblePadding),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(bubbleStyle.cornerRadius),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.replyToId != null) _buildReplyPreview(m.replyToId!),
          DefaultTextStyle.merge(
            style: TextStyle(color: textColor),
            child: content,
          ),
          if (m.localStatus != MessageLocalStatus.sent)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                m.localStatus == MessageLocalStatus.queued
                    ? 'В очереди'
                    : 'Не отправлено',
                style: TextStyle(
                  fontSize: 11,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
    );
    if (!_favorites.contains(m.id)) return bubble;
    return Stack(
      children: [
        bubble,
        Positioned(
          top: 4,
          right: 6,
          child: Icon(Icons.star, size: 14, color: NiosPalette.accentLight),
        ),
      ],
    );
  }

  Future<void> _retryOutboxMessage(MessageItem message) async {
    if (message.localStatus != MessageLocalStatus.failed) return;
    final outboxId = message.meta?['outbox_id']?.toString();
    if (outboxId == null || outboxId.isEmpty) return;
    await ref.read(sendQueueProvider.notifier).retry(outboxId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Повторная отправка...')),
    );
  }

  Widget _buildReplyPreview(String replyId) {
    final target = messages.where((m) => m.id == replyId).toList();
    final text = target.isNotEmpty ? target.first.text : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: NiosPalette.surfaceHover,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NiosPalette.borderLight),
      ),
      child: Text(text,
          style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12),
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
    );
  }

  MessagePayload _parsePayload(MessageItem message) {
    final raw = message.text;
    final msgType = message.type;
    if (msgType == 'poll') return MessagePayload('poll', raw);
    if (msgType == 'location') {
      final payload = jsonEncode({
        'lat': message.lat,
        'lon': message.lon,
        'label': raw,
      });
      return MessagePayload('location', payload);
    }
    if (msgType == 'contact') {
      return MessagePayload('contact', message.contactData ?? raw);
    }
    if (msgType == 'file') return MessagePayload('file', raw);
    if (msgType == 'call') return MessagePayload('call', raw);
    if (raw.startsWith('POLL:'))
      return MessagePayload('poll', raw.substring(5).trim());
    if (raw.startsWith('LOCATION:'))
      return MessagePayload('location', raw.substring(9).trim());
    if (raw.startsWith('CONTACT:'))
      return MessagePayload('contact', raw.substring(8).trim());
    if (raw.startsWith('MEDIA:'))
      return MessagePayload('media', raw.substring(6).trim());
    if (raw.startsWith('FILE:'))
      return MessagePayload('file', raw.substring(5).trim());
    return MessagePayload('text', raw);
  }

  Widget _buildMessageContent(
      MessageItem message, MessagePayload payload, bool isOwn,
      {required bool linkPreview}) {
    switch (payload.type) {
      case 'poll':
        return _buildPoll(payload.data, message);
      case 'location':
        return _buildLocation(payload.data);
      case 'contact':
        return _buildContact(payload.data);
      case 'media':
        return _buildMedia(payload.data);
      case 'file':
        return _buildFile(payload.data);
      case 'call':
        return _buildCall(payload.data, message);
      default:
        return _buildTextMessage(payload.data, isOwn, linkPreview: linkPreview);
    }
  }

  Widget _buildTextMessage(String text, bool isOwn,
      {required bool linkPreview}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor =
        isOwn ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final link = linkPreview ? _extractFirstLink(text) : null;
    if (link == null) {
      return Text(text, style: TextStyle(color: textColor));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: TextStyle(color: textColor)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _openUrl(link),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: NiosPalette.surfaceHover,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: NiosPalette.borderLight),
            ),
            child: Row(
              children: [
                Icon(Icons.link, size: 16, color: NiosPalette.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Uri.tryParse(link)?.host ?? link,
                    style: TextStyle(
                        color: NiosPalette.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _extractFirstLink(String text) {
    final match = RegExp(r'(https?://\\S+)').firstMatch(text);
    return match?.group(0);
  }

  Widget _buildPoll(String raw, MessageItem message) {
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
    if (parsed == null) {
      return Text(raw, style: TextStyle(color: NiosPalette.text));
    }
    final pollId = parsed['id']?.toString() ?? message.id;
    final poll = _polls.putIfAbsent(pollId, () => PollState.fromJson(parsed!));
    return _PollCard(
      poll: poll,
      onVote: (optionId) {
        final session = ref.read(sessionProvider);
        if (!session.isAuthed) return;
        poll.toggleVote(session.username!, optionId);
        _polls[poll.id] = poll;
        _savePollCache();
        setState(() {});
      },
    );
  }

  Widget _buildLocation(String raw) {
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
    final lat = parsed?['lat'] ?? parsed?['latitude'];
    final lon = parsed?['lon'] ?? parsed?['lng'] ?? parsed?['longitude'];
    final label = parsed?['label']?.toString();
    final coords = (lat != null && lon != null) ? '$lat, $lon' : raw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label ?? '',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: NiosPalette.text)),
        const SizedBox(height: 4),
        Text(coords,
            style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () {
            if (lat == null || lon == null) return;
            _openUrl('https://maps.google.com/?q=$lat,$lon');
          },
          child: const Text(
              'Открыть карту'),
        ),
      ],
    );
  }

  Widget _buildContact(String raw) {
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
    final name = parsed?['name']?.toString() ?? raw;
    final phones =
        (parsed?['phones'] as List?)?.map((e) => e.toString()).toList() ??
            const [];
    final emails =
        (parsed?['emails'] as List?)?.map((e) => e.toString()).toList() ??
            const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: NiosPalette.text)),
        if (phones.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(phones.first,
              style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
        ],
        if (emails.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(emails.first,
              style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
        ],
        const SizedBox(height: 6),
        TextButton(
          onPressed: () async {
            if (!await FlutterContacts.requestPermission()) return;
            final contact = Contact()
              ..name.first = name
              ..phones = phones.map((e) => Phone(e)).toList()
              ..emails = emails.map((e) => Email(e)).toList();
            await FlutterContacts.insertContact(contact);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Контакт сохранен')),
            );
          },
          child: const Text(
              'Сохранить контакт'),
        ),
      ],
    );
  }

  Widget _buildMedia(String raw) {
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
    if (parsed == null) return _buildFile(raw);
    final filename =
        parsed['filename']?.toString() ?? parsed['file']?.toString() ?? '';
    final mime = parsed['mime']?.toString() ?? '';
    return _buildFile(filename, mime: mime);
  }

  Widget _buildFile(String filename, {String? mime}) {
    final ext = filename.toLowerCase();
    final url = _mediaUrl(filename);
    final isImage = ext.endsWith('.png') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.gif');
    final isAudio = _isAudioFile(ext);
    final isVideo = ext.endsWith('.mp4') || ext.endsWith('.webm');

    Widget content;
    if (isImage) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          httpHeaders: _mediaHeaders,
          height: 180,
          width: 260,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            height: 180,
            color: NiosPalette.surfaceHover,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 180,
            color: NiosPalette.surfaceHover,
            alignment: Alignment.center,
            child: Icon(Icons.broken_image, color: NiosPalette.textSecondary),
          ),
        ),
      );
    } else if (isAudio) {
      final playing = _currentAudioUrl == url && _audioPlayer.playing;
      content = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NiosPalette.surfaceHover,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NiosPalette.borderLight),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => _playAudio(url),
              icon: Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: NiosPalette.textSecondary),
            ),
            Expanded(
              child: Text(filename,
                  style: TextStyle(color: NiosPalette.text),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
    } else {
      content = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NiosPalette.surfaceHover,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NiosPalette.borderLight),
        ),
        child: Row(
          children: [
            Icon(isVideo ? Icons.play_circle : Icons.insert_drive_file,
                color: NiosPalette.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(filename,
                      style: TextStyle(color: NiosPalette.text, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(mime ?? '',
                      style: TextStyle(
                          color: NiosPalette.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            if (!isAudio)
              TextButton.icon(
                onPressed: () => _openFile(filename),
                icon: const Icon(Icons.open_in_new),
                label: Text(isImage
                    ? 'Открыть'
                    : isVideo
                        ? 'Открыть видео'
                        : 'Открыть файл'),
              ),
            TextButton.icon(
              onPressed: () => _downloadFile(filename),
              icon: const Icon(Icons.download),
              label: const Text(
                  'Скачать'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCall(String raw, MessageItem message) {
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
    if (parsed == null) {
      return Text(raw, style: TextStyle(color: NiosPalette.text));
    }

    final session = ref.read(sessionProvider);
    final status = parsed['status']?.toString() ?? 'requested';
    final caller = parsed['caller']?.toString() ?? '';
    final callee = parsed['callee']?.toString() ?? '';
    final callId = parsed['call_id']?.toString() ?? '';
    final isOutgoing = message.sender == session.username;

    String title;
    if (status == 'requested') {
      title = isOutgoing
          ? 'Исходящий звонок'
          : 'Входящий звонок';
    } else if (status == 'accepted') {
      title =
          'Звонок принят';
    } else if (status == 'declined') {
      title =
          'Звонок отклонен';
    } else if (status == 'ended') {
      title =
          'Звонок завершен';
    } else {
      title =
          'Пропущенный звонок';
    }

    final subtitle = isOutgoing
        ? 'Кому: $callee'
        : 'От: $caller';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NiosPalette.surfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NiosPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: NiosPalette.text, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (status == 'requested' && !isOutgoing)
                FilledButton(
                  onPressed: () async {
                    if (!session.isAuthed) return;
                    await api.respondCall(
                      username: session.username!,
                      token: session.token!,
                      callId: callId,
                      status: 'accepted',
                    );
                    await _load();
                  },
                  child: const Text(
                      'Принять'),
                ),
              if (status == 'requested')
                OutlinedButton(
                  onPressed: () async {
                    if (!session.isAuthed) return;
                    await api.respondCall(
                      username: session.username!,
                      token: session.token!,
                      callId: callId,
                      status: 'declined',
                    );
                    await _load();
                  },
                  child: Text(isOutgoing
                      ? 'Отменить'
                      : 'Отклонить'),
                ),
              if (status == 'accepted')
                OutlinedButton(
                  onPressed: () async {
                    if (!session.isAuthed) return;
                    await api.respondCall(
                      username: session.username!,
                      token: session.token!,
                      callId: callId,
                      status: 'ended',
                    );
                    await _load();
                  },
                  child: const Text(
                      'Завершить'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(MessageItem m) {
    final data = _reactionCounts[m.id];
    if (data == null || data.isEmpty) return const SizedBox(height: 4);
    final mine = _myReactions[m.id] ?? <String>{};
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
      child: Wrap(
        spacing: 6,
        children: data.entries.map((entry) {
          final active = mine.contains(entry.key);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active
                  ? NiosPalette.accent.withValues(alpha: 0.18)
                  : NiosPalette.surfaceHover,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: active ? NiosPalette.accent : NiosPalette.borderLight),
            ),
            child: Text('${entry.key} ${entry.value}',
                style:
                    TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAiSummaryCard(AiSummaryState aiSummary) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.auto_awesome,
                    color: scheme.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI Сводка',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              InkWell(
                onTap: () => ref.read(aiSummaryProvider.notifier).collapse(),
                borderRadius: BorderRadius.circular(12),
                child: Icon(Icons.close, size: 18, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...aiSummary.summaryPoints.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          if (aiSummary.lastUpdated != null) ...[
            const SizedBox(height: 8),
            Text(
              'Обновлено: ${_formatTime(aiSummary.lastUpdated!)}',
              style: TextStyle(
                color: NiosPalette.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // Composer replaced by ChatInputWidget
}

class MessagePayload {
  MessagePayload(this.type, this.data);

  final String type;
  final String data;
}

class _AttachItem {
  const _AttachItem(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final Future<void> Function() onTap;
}

class PollState {
  PollState({
    required this.id,
    required this.question,
    required this.options,
    required this.multiple,
    Map<String, List<String>>? votedBy,
  }) : votedBy = votedBy ?? {};

  final String id;
  final String question;
  final List<PollOption> options;
  final bool multiple;
  final Map<String, List<String>> votedBy;

  factory PollState.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List<dynamic>? ?? []).map((e) {
      if (e is Map<String, dynamic>) {
        return PollOption(
          id: e['id']?.toString() ?? UniqueKey().toString(),
          text: e['text']?.toString() ?? '',
        );
      }
      return PollOption(id: UniqueKey().toString(), text: e.toString());
    }).toList();
    return PollState(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      question: json['question']?.toString() ?? '',
      options: options,
      multiple: json['multiple'] == true,
      votedBy: (json['votedBy'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key,
                (value as List<dynamic>).map((e) => e.toString()).toList()),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'multiple': multiple,
        'options': options.map((e) => e.toJson()).toList(),
        'votedBy': votedBy,
      };

  void toggleVote(String username, String optionId) {
    final current = votedBy[username] ?? [];
    if (multiple) {
      if (current.contains(optionId)) {
        current.remove(optionId);
      } else {
        current.add(optionId);
      }
    } else {
      if (current.contains(optionId)) {
        current.clear();
      } else {
        current
          ..clear()
          ..add(optionId);
      }
    }
    votedBy[username] = current;
  }

  int totalVotes() {
    return votedBy.values.fold(0, (sum, list) => sum + list.length);
  }

  int optionVotes(String optionId) {
    var count = 0;
    for (final list in votedBy.values) {
      if (list.contains(optionId)) count += 1;
    }
    return count;
  }
}

class PollOption {
  PollOption({required this.id, required this.text});

  final String id;
  final String text;

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll, required this.onVote});

  final PollState poll;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final total = poll.totalVotes();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NiosPalette.surfaceHover,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NiosPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(poll.question,
              style: TextStyle(
                  color: NiosPalette.text, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...poll.options.map((opt) {
            final votes = poll.optionVotes(opt.id);
            final percent = total == 0 ? 0 : ((votes / total) * 100).round();
            return GestureDetector(
              onTap: () => onVote(opt.id),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: NiosPalette.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NiosPalette.borderLight),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(opt.text,
                            style: TextStyle(color: NiosPalette.text))),
                    Text('$percent%',
                        style: TextStyle(color: NiosPalette.textSecondary)),
                  ],
                ),
              ),
            );
          }),
          Text(
              '$total голосов',
              style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
