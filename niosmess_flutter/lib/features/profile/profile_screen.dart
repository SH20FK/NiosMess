import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';
import '../../core/storage/offline_cache.dart';
import '../../core/settings_provider.dart';
import '../../ui/nios_ui.dart';

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

    try {
      final data = await api.getUserInfo(_username, session.username!, session.token!);
      await OfflineCache.saveProfile(_username, data);
      setState(() {
        info = data;
        _avatarFuture = _loadAvatar(_username);
        loading = false;
      });
    } catch (_) {
      final cached = await OfflineCache.loadProfile(_username);
      setState(() {
        info = cached;
        _avatarFuture = _loadAvatar(_username);
        loading = false;
      });
    }
  }

  Future<Uint8List?> _loadAvatar(String username) async {
    return api.getAvatarBytes(username);
  }

  String _statusText(Map<String, dynamic>? data) {
    final isOnline = data?['isonline'] == true;
    if (isOnline) return 'в сети';

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

    return 'не в сети';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final settings = ref.watch(settingsProvider);
    final reduceMotion = (settings['reduce_motion'] as bool?) ?? false;
    final fallbackName = _isOwnProfile
        ? (session.name ?? 'Пользователь')
        : (_username.isEmpty ? 'Пользователь' : _username);
    final name = info?['name']?.toString() ?? fallbackName;
    final username = info?['username']?.toString() ?? _username;
    final email = (info?['email'] ?? info?['mail'] ?? info?['e_mail'])?.toString() ?? '';
    final about = (info?['about'] ?? info?['bio'] ?? info?['desc'] ?? info?['about_me'])?.toString() ?? '';
    final reg = (info?['regdate'] ?? info?['reg_date'] ?? info?['created_at'])?.toString() ?? '';
    final badgeText = (info?['badge_text'] ?? info?['badge_title'])?.toString();
    final badgeIcon = info?['badge_icon']?.toString();
    final status = _statusText(info);

    return NiosScaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: Icon(Icons.arrow_back, color: NiosPalette.text),
                ),
                Text(
                  _isOwnProfile ? 'Профиль' : 'Профиль пользователя',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: NiosPalette.text),
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      NiosCard(
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: NiosPalette.borderLight),
                                color: NiosPalette.surfaceHover,
                              ),
                              child: ClipOval(
                                child: username.isEmpty
                                    ? Center(
                                        child: Text(
                                          name.characters.first.toUpperCase(),
                                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    : FutureBuilder<Uint8List?>(
                                        future: _avatarFuture,
                                        builder: (context, snapshot) {
                                          final bytes = snapshot.data;
                                          if (bytes != null && bytes.isNotEmpty) {
                                            return Image.memory(bytes, fit: BoxFit.cover);
                                          }
                                          return Center(
                                            child: Text(
                                              name.characters.first.toUpperCase(),
                                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                      ),
                                      if ((badgeText ?? '').isNotEmpty || (badgeIcon ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 6),
                                          child: NiosBadge(
                                            tooltip: badgeText ??
                                                'Этот человек связан с разработкой напрямую или является спонсором NiosMess',
                                            icon: badgeIcon ?? '🦊',
                                            reduceMotion: reduceMotion,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('@$username', style: TextStyle(color: NiosPalette.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(status, style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      NiosCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const NiosSectionTitle('Аккаунт'),
                            const SizedBox(height: 12),
                            Text('Email', style: TextStyle(color: NiosPalette.textSecondary)),
                            const SizedBox(height: 4),
                            Text(email.isEmpty ? '—' : email),
                            const SizedBox(height: 12),
                            Text('О себе', style: TextStyle(color: NiosPalette.textSecondary)),
                            const SizedBox(height: 4),
                            Text(about.isEmpty ? '—' : about),
                            if (reg.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text('Дата регистрации', style: TextStyle(color: NiosPalette.textSecondary)),
                              const SizedBox(height: 4),
                              Text(reg),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
