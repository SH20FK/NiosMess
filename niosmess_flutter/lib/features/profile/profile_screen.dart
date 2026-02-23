import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';
import '../../core/storage/offline_cache.dart';
import '../../core/settings_provider.dart';
import '../../ui/nios_ui.dart';
import '../chat/chat_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onBack,
    this.targetUsername,
  });

  final VoidCallback onBack;
  final String? targetUsername;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final api = ApiRepository();
  Map<String, dynamic>? info;
  bool loading = true;
  Future<Uint8List?>? _avatarFuture;
  String _customStatus = '';

  String get _username {
    final session = ref.read(sessionProvider);
    final target = widget.targetUsername?.trim();
    if (target == null || target.isEmpty) {
      return session.username ?? '';
    }
    return target;
  }

  bool get _isOwnProfile {
    final session = ref.read(sessionProvider);
    return _username == (session.username ?? '');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) {
      setState(() => loading = false);
      return;
    }
    final cached = await OfflineCache.loadProfile(_username);
    if (mounted) {
      setState(() {
        info = cached;
        _customStatus = cached?['custom_status']?.toString() ?? '';
        _avatarFuture = _loadAvatar(_username);
        loading = false;
      });
    }
    try {
      final data = await api.getUserInfo(_username, session.username!, session.token!);
      await OfflineCache.saveProfile(_username, data);
      setState(() {
        info = data;
        _customStatus = data['custom_status']?.toString() ?? '';
        _avatarFuture = _loadAvatar(_username);
        loading = false;
      });
    } catch (_) {
      // keep cached data if network fails
    }
  }

  Future<Uint8List?> _loadAvatar(String username) async {
    return api.getAvatarBytes(username);
  }

  String _statusText(Map<String, dynamic>? data) {
    final isOnline = data?['isonline'] == true;
    if (isOnline) return 'В сети';

    final lastSeenText = data?['last_seen_text']?.toString();
    if (lastSeenText != null && lastSeenText.isNotEmpty) return lastSeenText;

    final lastSeenRaw = data?['last_seen'];
    if (lastSeenRaw != null) {
      final value = double.tryParse(lastSeenRaw.toString());
      if (value != null && value > 0) {
        final last = DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
        final diff = DateTime.now().difference(last);
        if (diff.inMinutes < 1) return 'был(а) только что';
        if (diff.inHours < 1) return 'был(а) ${diff.inMinutes} мин назад';
        if (diff.inDays < 1) return 'был(а) ${diff.inHours} ч назад';
        return 'был(а) ${diff.inDays} д назад';
      }
    }

    return 'Не в сети';
  }

  void _showSetStatusDialog() {
    final controller = TextEditingController(text: _customStatus);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('?????????? ??????'),
        content: TextField(
          controller: controller,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: '????????: ?? ??????',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('??????'),
          ),
          FilledButton(
            onPressed: () async {
              final newStatus = controller.text.trim();
              setState(() => _customStatus = newStatus);
              if (context.mounted) Navigator.pop(context);

              final session = ref.read(sessionProvider);
              if (!session.isAuthed) return;

              try {
                await api.setCustomStatus(
                  session.username!,
                  session.token!,
                  newStatus,
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('?? ??????? ????????? ??????')),
                );
              }
            },
            child: const Text('?????????'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed || _username.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Заблокировать пользователя?'),
        content: Text('$_username больше не сможет писать вам сообщения.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Заблокировать')),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    try {
      await api.blockUser(session.username!, session.token!, _username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_username заблокирован')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось заблокировать')),
        );
      }
    }
  }

  void _openChat() {
    final username = _username;
    if (username.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: username,
          chatUsername: username,
          chatType: 'user',
          title: info?['name']?.toString() ?? username,
          status: _statusText(info),
          onBack: () => Navigator.of(context).pop(),
          onOpenProfile: (u) {},
        ),
      ),
    );
  }

  Future<void> _requestCall() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    if (_username.isEmpty) return;
    try {
      await api.requestCall(
        caller: session.username!,
        callee: _username,
        token: session.token!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запрос звонка отправлен')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить звонок')),
      );
    }
  }

  void _shareProfile() {
    final username = _username;
    if (username.isEmpty) return;
    final text = 'NiosMess: @$username\nniosmess://user/$username';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final settings = ref.watch(settingsProvider);
    final fallbackName = _isOwnProfile
        ? (session.name ?? 'Пользователь')
        : (_username.isEmpty ? 'Пользователь' : _username);
    final name = info?['name']?.toString() ?? fallbackName;
    final username = info?['username']?.toString() ?? _username;
    final email = (info?['email'] ?? info?['mail'] ?? info?['e_mail'])?.toString() ?? '';
    final about = (info?['about'] ?? info?['bio'] ?? info?['desc'] ?? info?['about_me'])?.toString() ?? '';
    final reg = (info?['regdate'] ?? info?['reg_date'] ?? info?['created_at'])?.toString() ?? '';
    final status = _statusText(info);
    final reduceMotion = (settings['reduce_motion'] as bool?) ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(_isOwnProfile ? 'Профиль' : 'Профиль пользователя'),
        bottom: loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: NiosMotionWrap(
        enableMotion: !reduceMotion,
        blurSigma: 12,
        offset: const Offset(0, 18),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Hero(
                          tag: 'avatar_$_username',
                          child: FutureBuilder<Uint8List?>(
                            future: _avatarFuture,
                            builder: (context, snapshot) {
                              final bytes = snapshot.data;
                              return CircleAvatar(
                                radius: 48,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                backgroundImage: bytes != null && bytes.isNotEmpty ? MemoryImage(bytes) : null,
                                child: bytes != null && bytes.isNotEmpty
                                    ? null
                                    : Text(
                                        name.characters.first.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(name, style: Theme.of(context).textTheme.titleLarge),
                        if (username.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('@$username', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          status,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (_customStatus.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _customStatus,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (_isOwnProfile)
                          FilledButton.icon(
                            onPressed: _showSetStatusDialog,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Установить статус'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Информация', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: Text(email.isNotEmpty ? email : 'Не указан'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('О себе'),
                        subtitle: Text(about.isNotEmpty ? about : 'Не указано'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: const Text('Дата регистрации'),
                        subtitle: Text(reg.isNotEmpty ? reg : '—'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Действия', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: const Text('Написать сообщение'),
                        onTap: _openChat,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.call_outlined),
                        title: const Text('Позвонить'),
                        onTap: _requestCall,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.share_outlined),
                        title: const Text('Поделиться профилем'),
                        onTap: _shareProfile,
                      ),
                      if (!_isOwnProfile) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.block,
                              color: Theme.of(context).colorScheme.error),
                          title: Text(
                            'Заблокировать',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                          onTap: _blockUser,
                        ),
                      ],
                    ],
                  ),
                ),
                if (reduceMotion) const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

}
