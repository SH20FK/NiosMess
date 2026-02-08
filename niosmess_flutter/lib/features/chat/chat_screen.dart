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
import '../../core/constants.dart';
import '../../core/models/message_item.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/settings_provider.dart';
import '../../core/session_provider.dart';
import '../../ui/nios_ui.dart';

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
  String? _recordPath;
  String? _currentAudioUrl;
  bool _autoPlayed = false;
  Future<Uint8List?>? _headerAvatar;

  final Map<String, PollState> _polls = {};
  final Map<String, Map<String, int>> _reactionCounts = {};
  final Map<String, Set<String>> _myReactions = {};
  final Set<String> _favorites = {};
  MessageItem? _replyTo;
  String? _pinnedMessageId;
  bool _searchOpen = false;
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    _loadPollCache();
    _loadFavorites();
    _loadDraft();
    _load();
    _loadHeaderAvatar();
  }


  Future<void> _loadHeaderAvatar() async {
    if (widget.chatType != 'user') return;
    final username = (widget.chatUsername ?? widget.chatId).trim();
    if (username.isEmpty) return;
    _headerAvatar = api.getAvatarBytes(username);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.dispose();
    _searchController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
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
          ? await api.getCollectiveMessages(widget.chatId, session.username!, session.token!)
          : await api.getMessagesUser(session.username!, widget.chatId, session.token!);
      setState(() {
        messages = data;
        _updatePinnedFromMessages(data);
        loading = false;
      });
      _autoPlayFirstVoice();
    } catch (_) {
      final cached = await api.getCachedMessages(widget.chatId);
      setState(() {
        messages = cached;
        _updatePinnedFromMessages(cached);
        loading = false;
      });
    }
  }

  bool _isCollective(String chatId) =>
      widget.chatType == 'group' || widget.chatType == 'channel' || chatId.startsWith('group_') || chatId.startsWith('channel_');

  Future<void> _send({String? overrideText}) async {
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
        await api.sendCollective(widget.chatId, session.username!, text, session.token!, replyTo: replyId);
      } else {
        await api.sendMessageUser(session.username!, widget.chatId, text, session.token!, replyTo: replyId);
      }
      _replyTo = null;
      await _load();
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _isAudioFile(String filename) {
    final ext = filename.toLowerCase();
    return ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.ogg') || ext.endsWith('.m4a') || ext.endsWith('.aac');
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
      final payload = _parsePayload(msg.text);
      if (payload.type == 'file' || payload.type == 'media') {
        final filename = payload.type == 'file' ? payload.data : _extractFilename(payload.data);
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
        _reactionCounts[message.id] = countsRaw.map((key, value) => MapEntry(key.toString(), (value as num).toInt()));
      }
      if (mineRaw is Map) {
        _myReactions[message.id] = mineRaw.keys.map((e) => e.toString()).toSet();
      }
      if (mounted) setState(() {});
    } catch (_) {
      // ignore network errors, keep optimistic state
    }
  }

  void _showMessageMenu(MessageItem message) {
    final session = ref.read(sessionProvider);
    final isOwn = session.username == message.sender;
    final isFavorite = _favorites.contains(message.id);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReactionRow(message),
              const SizedBox(height: 12),
              _menuButton('Ответить', Icons.reply, () {
                Navigator.pop(context);
                setState(() => _replyTo = message);
              }),
              if (isOwn)
                _menuButton('Редактировать', Icons.edit, () {
                  Navigator.pop(context);
                  _editMessage(message);
                }),
              _menuButton('Копировать', Icons.copy, () async {
                Navigator.pop(context);
                await Clipboard.setData(ClipboardData(text: message.text));
              }),
              _menuButton('Переслать', Icons.forward, () {
                Navigator.pop(context);
                _openForwardModal(message);
              }),
              _menuButton(isFavorite ? 'Убрать из избранного' : 'В избранное', Icons.star_border, () {
                Navigator.pop(context);
                _toggleFavorite(message);
              }),
              _menuButton(message.isPinned == true ? 'Открепить' : 'Закрепить', Icons.push_pin_outlined, () {
                Navigator.pop(context);
                _togglePinMessage(message);
              }),
              _menuButton('Удалить', Icons.delete_outline, () {
                Navigator.pop(context);
                _deleteMessage(message);
              }),
            ],
          ),
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
        title: Text('Редактировать', style: TextStyle(color: NiosPalette.text)),
        content: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 4,
          decoration: niosInputDecoration('Текст сообщения'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Сохранить')),
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
        title: Text('Удалить сообщение?', style: TextStyle(color: NiosPalette.text)),
        content: Text('Сообщение будет удалено только у вас, если это позволяет сервер.', style: TextStyle(color: NiosPalette.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
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
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '😡'];
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
          title: Text('Переслать', style: TextStyle(color: NiosPalette.text)),
          content: TextField(
            controller: controller,
            decoration: niosInputDecoration('chat_id'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            TextButton(
              onPressed: () async {
                final session = ref.read(sessionProvider);
                if (!session.isAuthed) return;
                final target = controller.text.trim();
                if (target.isEmpty) return;
                await api.sendMessageUser(session.username!, target, message.text, session.token!);
                Navigator.pop(context);
              },
              child: const Text('Отправить'),
            ),
          ],
        );
      },
    );
  }

  void _openAttachMenu() {
    final reduceMotion = (ref.read(settingsProvider)['reduce_motion'] as bool?) ?? false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final items = [
          _AttachItem('Опрос', Icons.poll, _openPollModal),
          _AttachItem('Геометка', Icons.place, _sendLocation),
          _AttachItem('Файл', Icons.insert_drive_file, _pickAndUploadFile),
          _AttachItem('Контакт', Icons.person, _sendContact),
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
                    duration: Duration(milliseconds: reduceMotion ? 0 : 220 + (index * 40)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
                              style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12),
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
      '😀','😅','😂','🤣','😊','😍','😘','😎','🤔','😴',
      '👍','👎','👏','🙏','💪','🔥','🎉','✨','💯','✅',
      '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔',
      '😢','😭','😡','🤬','😱','😇','🤗','😜','🤩','🥳',
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
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
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
    controller.selection = TextSelection.collapsed(offset: start + value.length);
  }

  Future<void> _scheduleSend() async {
    if (controller.text.trim().isEmpty) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    final delay = target.difference(now);
    final scheduledText = controller.text;
    controller.clear();
    _saveDraft();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Сообщение будет отправлено в ${picked.format(context)}')),
    );
    Timer(delay, () {
      if (!mounted) return;
      _send(overrideText: scheduledText);
    });
  }

  void _showSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature скоро будет доступна')),
    );
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
    final options = <TextEditingController>[TextEditingController(), TextEditingController()];
    bool multiple = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: NiosPalette.surface,
            title: Text('Новый опрос', style: TextStyle(color: NiosPalette.text)),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: questionController,
                    decoration: niosInputDecoration('Вопрос'),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: List.generate(options.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: options[i],
                          decoration: niosInputDecoration('Вариант'),
                        ),
                      );
                    }),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setStateDialog(() => options.add(TextEditingController())),
                      child: const Text('Добавить вариант'),
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: multiple,
                        onChanged: (val) => setStateDialog(() => multiple = val ?? false),
                      ),
                      Text('Можно несколько', style: TextStyle(color: NiosPalette.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              TextButton(
                onPressed: () async {
                  final question = questionController.text.trim();
                  final opts = options.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();
                  if (question.isEmpty || opts.length < 2) return;
                  final payload = {
                    'id': 'poll_${DateTime.now().millisecondsSinceEpoch}',
                    'question': question,
                    'options': opts
                        .map((e) => {
                              'id': 'opt_${DateTime.now().microsecondsSinceEpoch}_${opts.indexOf(e)}',
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
                child: const Text('Создать'),
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
      _showSoon('Геолокация');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _showSoon('Геолокация');
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    final payload = {
      'lat': position.latitude,
      'lon': position.longitude,
      'label': 'Моя геопозиция',
    };
    controller.text = 'LOCATION:${jsonEncode(payload)}';
    await _send();
  }

  Future<void> _sendContact() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    if (!await FlutterContacts.requestPermission()) {
      _showSoon('Контакты');
      return;
    }
    final contact = await FlutterContacts.openExternalPick();
    if (contact == null) return;
    final payload = {
      'name': contact.displayName,
      'phones': contact.phones.map((e) => e.number).toList(),
      'emails': contact.emails.map((e) => e.address).toList(),
    };
    controller.text = 'CONTACT:${jsonEncode(payload)}';
    await _send();
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
    final filePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
    final reduceMotion = (settings['reduce_motion'] as bool?) ?? false;
    final compactMessages = (settings['compact_messages'] as bool?) ?? false;
    final linkPreview = (settings['link_preview'] as bool?) ?? true;
    final visibleMessages = _visibleMessages();
    return NiosScaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(reduceMotion: reduceMotion),
          _buildPinnedBar(),
          Expanded(
              child: AnimatedSwitcher(
              duration: Duration(milliseconds: reduceMotion ? 0 : 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: loading
                  ? const Center(key: ValueKey('loading'), child: CircularProgressIndicator())
                  : ListView.builder(
                      key: const ValueKey('messages'),
                      padding: EdgeInsets.symmetric(horizontal: compactMessages ? 12 : 16, vertical: compactMessages ? 8 : 12),
                      itemCount: visibleMessages.length,
                      itemBuilder: (_, i) {
                        final m = visibleMessages[i];
                        final isOwn = m.sender == session.username;
                        return Align(
                          alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () => _showMessageMenu(m),
                            child: Column(
                              crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                _buildMessageBubble(m, isOwn, compact: compactMessages, linkPreview: linkPreview),
                                _buildReactions(m),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  List<MessageItem> _visibleMessages() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return messages;
    return messages.where((m) => m.text.toLowerCase().contains(query)).toList();
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
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
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
        _searchController.selection = TextSelection.collapsed(offset: _searchController.text.length);
      }
    });
  }

  Widget _buildSearchBar({required bool reduceMotion}) {
    if (!_searchOpen) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: Duration(milliseconds: reduceMotion ? 0 : 220),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: niosInputDecoration('Поиск в чате', icon: Icons.search),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
                _searchOpen = false;
              });
            },
            icon: Icon(Icons.close, color: NiosPalette.textSecondary),
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

  void _openChatMenu() {
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
              _menuButton('Открыть профиль', Icons.account_circle_outlined, () {
                Navigator.pop(context);
                widget.onOpenProfile(widget.chatUsername ?? widget.chatId);
              }),
            _menuButton('Обновить чат', Icons.refresh, () async {
              Navigator.pop(context);
              await _load();
            }),
            _menuButton('Сбросить поиск', Icons.search_off, () {
              Navigator.pop(context);
              setState(() => _searchQuery = '');
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
      final showAvatar = widget.chatType == 'user';
      final settings = ref.watch(settingsProvider);
      final reduceMotion = (settings['reduce_motion'] as bool?) ?? false;
      final showStatus = (settings['show_status'] as bool?) ?? true;
      final showLastSeen = (settings['show_last_seen'] as bool?) ?? true;
      final statusText = (showStatus && showLastSeen) ? (widget.status ?? ' ') : ' ';
      return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: NiosPalette.surface,
        border: Border(bottom: BorderSide(color: NiosPalette.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: Icon(Icons.arrow_back, color: NiosPalette.text),
          ),
          GestureDetector(
            onTap: showAvatar ? () => widget.onOpenProfile(widget.chatUsername ?? widget.chatId) : null,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: NiosPalette.surfaceHover,
                shape: BoxShape.circle,
                border: Border.all(color: NiosPalette.borderLight),
              ),
              clipBehavior: Clip.antiAlias,
              child: showAvatar
                  ? FutureBuilder<Uint8List?>(
                      future: _headerAvatar,
                      builder: (context, snapshot) {
                        final bytes = snapshot.data;
                        if (bytes != null && bytes.isNotEmpty) {
                          return Image.memory(bytes, fit: BoxFit.cover);
                        }
                        return Center(child: Text(widget.title?.characters.first.toUpperCase() ?? '?'));
                      },
                    )
                  : Text(widget.title?.characters.first.toUpperCase() ?? '?'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(widget.title ?? widget.chatId, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    if ((widget.badgeText ?? '').isNotEmpty || (widget.badgeIcon ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: NiosBadge(
                          tooltip: widget.badgeText ??
                              'Этот человек связан с разработкой напрямую или является спонсором NiosMess',
                          icon: widget.badgeIcon ?? '\u{1F98A}',
                          reduceMotion: reduceMotion,
                        ),
                      ),
                  ],
                ),
                Text(statusText, style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: _toggleSearchBar,
            icon: Icon(Icons.search, color: NiosPalette.textSecondary),
          ),
          IconButton(
            onPressed: _openChatMenu,
            icon: Icon(Icons.more_vert, color: NiosPalette.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageItem m, bool isOwn, {required bool compact, required bool linkPreview}) {
    final payload = _parsePayload(m.text);
    final content = _buildMessageContent(m, payload, isOwn, linkPreview: linkPreview);
    final maxWidth = MediaQuery.of(context).size.width * 0.86;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth < 420 ? maxWidth : 420),
      margin: EdgeInsets.symmetric(vertical: compact ? 3 : 6),
      padding: EdgeInsets.all(compact ? 9 : 12),
      decoration: BoxDecoration(
        color: isOwn ? NiosPalette.messageOut : NiosPalette.messageIn,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NiosPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.replyToId != null) _buildReplyPreview(m.replyToId!),
          content,
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
      child: Text(text, style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  MessagePayload _parsePayload(String raw) {
    if (raw.startsWith('POLL:')) return MessagePayload('poll', raw.substring(5).trim());
    if (raw.startsWith('LOCATION:')) return MessagePayload('location', raw.substring(9).trim());
    if (raw.startsWith('CONTACT:')) return MessagePayload('contact', raw.substring(8).trim());
    if (raw.startsWith('MEDIA:')) return MessagePayload('media', raw.substring(6).trim());
    if (raw.startsWith('FILE:')) return MessagePayload('file', raw.substring(5).trim());
    return MessagePayload('text', raw);
  }

  Widget _buildMessageContent(MessageItem message, MessagePayload payload, bool isOwn, {required bool linkPreview}) {
    switch (payload.type) {
      case 'poll':
        return _buildPoll(payload.data, message);
      case 'location':
        return _buildLocation(payload.data);
      case 'media':
        return _buildMedia(payload.data);
      case 'file':
        return _buildFile(payload.data);
      default:
        return _buildTextMessage(payload.data, isOwn, linkPreview: linkPreview);
    }
  }

  Widget _buildTextMessage(String text, bool isOwn, {required bool linkPreview}) {
    final link = linkPreview ? _extractFirstLink(text) : null;
    if (link == null) {
      return Text(text, style: TextStyle(color: isOwn ? Colors.white : NiosPalette.text));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: TextStyle(color: isOwn ? Colors.white : NiosPalette.text)),
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
                    style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12),
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
        Text(label ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: NiosPalette.text)),
        const SizedBox(height: 4),
        Text(coords, style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () {
            if (lat == null || lon == null) return;
            _openUrl('https://maps.google.com/?q=$lat,$lon');
          },
          child: const Text('Открыть карту'),
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
    final filename = parsed['filename']?.toString() ?? parsed['file']?.toString() ?? '';
    final mime = parsed['mime']?.toString() ?? '';
    return _buildFile(filename, mime: mime);
  }

  Widget _buildFile(String filename, {String? mime}) {
    final ext = filename.toLowerCase();
    final url = _mediaUrl(filename);
    if (ext.endsWith('.png') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.webp') || ext.endsWith('.gif')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
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
    }
    final isAudio = _isAudioFile(ext);
    final isVideo = ext.endsWith('.mp4') || ext.endsWith('.webm');
    if (isAudio) {
      final playing = _currentAudioUrl == url && _audioPlayer.playing;
      return Container(
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
              icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: NiosPalette.textSecondary),
            ),
            Expanded(
              child: Text(filename, style: TextStyle(color: NiosPalette.text), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => _openUrl(url),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NiosPalette.surfaceHover,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NiosPalette.borderLight),
        ),
        child: Row(
          children: [
            Icon(isAudio ? Icons.graphic_eq : isVideo ? Icons.play_circle : Icons.insert_drive_file, color: NiosPalette.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(filename, style: TextStyle(color: NiosPalette.text, fontSize: 13), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(mime ?? (isAudio ? '' : isVideo ? '' : ''), style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
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
              color: active ? NiosPalette.accent.withOpacity(0.18) : NiosPalette.surfaceHover,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? NiosPalette.accent : NiosPalette.borderLight),
            ),
            child: Text('${entry.key} ${entry.value}', style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildComposer() {
    final settings = ref.watch(settingsProvider);
    final compact = (settings['compact_messages'] as bool?) ?? false;
    return Container(
      padding: EdgeInsets.fromLTRB(12, compact ? 6 : 8, 12, compact ? 8 : 12),
      decoration: BoxDecoration(
        color: NiosPalette.surface,
        border: Border(top: BorderSide(color: NiosPalette.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_recording)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NiosPalette.surfaceHover,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NiosPalette.borderLight),
              ),
              child: Row(
                children: [
                  Icon(Icons.mic, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Запись', style: TextStyle(color: NiosPalette.text, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (_recordDuration.inSeconds % 120) / 120,
                          minHeight: 6,
                          backgroundColor: NiosPalette.surface,
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_formatDuration(_recordDuration), style: TextStyle(color: NiosPalette.textSecondary)),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _cancelRecording,
                    icon: Icon(Icons.close, color: NiosPalette.textSecondary),
                  ),
                ],
              ),
            ),
          if (_replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NiosPalette.surfaceHover,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NiosPalette.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(_replyTo!.text, style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  IconButton(
                    onPressed: () => setState(() => _replyTo = null),
                    icon: Icon(Icons.close, color: NiosPalette.textSecondary, size: 18),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: niosInputDecoration('Сообщение'),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: NiosPalette.surfaceHover,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: NiosPalette.borderLight),
                ),
                child: IconButton(
                  onPressed: _openEmojiPicker,
                  icon: Icon(Icons.emoji_emotions_outlined, color: NiosPalette.textSecondary),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: NiosPalette.surfaceHover,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: NiosPalette.borderLight),
                ),
                child: IconButton(
                  onPressed: _openAttachMenu,
                  icon: Icon(Icons.attach_file, color: NiosPalette.textSecondary),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: NiosPalette.surfaceHover,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: NiosPalette.borderLight),
                ),
                child: IconButton(
                  onPressed: _toggleRecord,
                  icon: Icon(
                    _recording ? Icons.stop_circle : Icons.mic,
                    color: _recording ? Colors.redAccent : NiosPalette.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onLongPress: _scheduleSend,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: NiosPalette.surfaceHover,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NiosPalette.borderLight),
                  ),
                  child: IconButton(
                    onPressed: sending ? null : _send,
                    icon: Icon(Icons.send, color: NiosPalette.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
            (key, value) => MapEntry(key, (value as List<dynamic>).map((e) => e.toString()).toList()),
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
          Text(poll.question, style: TextStyle(color: NiosPalette.text, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...poll.options.map((opt) {
            final votes = poll.optionVotes(opt.id);
            final percent = total == 0 ? 0 : ((votes / total) * 100).round();
            return GestureDetector(
              onTap: () => onVote(opt.id),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: NiosPalette.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NiosPalette.borderLight),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(opt.text, style: TextStyle(color: NiosPalette.text))),
                    Text('$percent%', style: TextStyle(color: NiosPalette.textSecondary)),
                  ],
                ),
              ),
            );
          }),
          Text('$total голосов', style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}










