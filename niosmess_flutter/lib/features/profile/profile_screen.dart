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
      final cached = await OfflineCache.loadProfile(_username);
      setState(() {
        info = cached;
        _customStatus = cached?['custom_status']?.toString() ?? '';
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

  void _showSetStatusDialog() {
    final controller = TextEditingController(text: _customStatus);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Установить статус'),
        content: TextField(
          controller: controller,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: 'Например: На работе',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final newStatus = controller.text.trim();
              // TODO: Save status to API
              setState(() => _customStatus = newStatus);
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
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
          // Header with back button
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
                      // Large Profile Header
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: NiosPalette.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: NiosPalette.borderLight),
                        ),
                        child: Column(
                          children: [
                            // Large Avatar
                            Hero(
                              tag: 'avatar_$_username',
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: NiosPalette.accent.withOpacity(0.3),
                                    width: 3,
                                  ),
                                  color: NiosPalette.surfaceHover,
                                  boxShadow: [
                                    BoxShadow(
                                      color: NiosPalette.shadow.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: username.isEmpty
                                      ? Center(
                                          child: Text(
                                            name.characters.first.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 48,
                                              fontWeight: FontWeight.bold,
                                            ),
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
                                                style: const TextStyle(
                                                  fontSize: 48,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Name with badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if ((badgeText ?? '').isNotEmpty || (badgeIcon ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: NiosBadge(
                                      tooltip: badgeText ??
                                          'Этот человек связан с разработкой напрямую или является спонсором NiosMess',
                                      icon: badgeIcon ?? '🦊',
                                      reduceMotion: reduceMotion,
                                      size: 24,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            
                            // Username
                            Text(
                              '@$username',
                              style: TextStyle(
                                color: NiosPalette.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // Online status
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: info?['isonline'] == true
                                    ? Colors.green.withOpacity(0.1)
                                    : NiosPalette.surfaceHover,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: info?['isonline'] == true
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    status,
                                    style: TextStyle(
                                      color: NiosPalette.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Custom Status
                            if (_customStatus.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: NiosPalette.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: NiosPalette.accent.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  _customStatus,
                                  style: TextStyle(
                                    color: NiosPalette.accent,
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                            
                            // Set Status Button (only for own profile)
                            if (_isOwnProfile) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _showSetStatusDialog,
                                  icon: Icon(Icons.edit, size: 18, color: NiosPalette.accent),
                                  label: Text(
                                    _customStatus.isEmpty ? 'Установить статус' : 'Изменить статус',
                                    style: TextStyle(color: NiosPalette.accent),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: NiosPalette.accent.withOpacity(0.5)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Account Info Card
                      NiosCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const NiosSectionTitle('Информация'),
                            const SizedBox(height: 16),
                            
                            _buildInfoRow(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: email.isEmpty ? '—' : email,
                            ),
                            const SizedBox(height: 16),
                            
                            _buildInfoRow(
                              icon: Icons.info_outline,
                              label: 'О себе',
                              value: about.isEmpty ? '—' : about,
                            ),
                            
                            if (reg.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                icon: Icons.calendar_today_outlined,
                                label: 'Дата регистрации',
                                value: reg,
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Actions (only for own profile)
                      if (_isOwnProfile) ...[
                        const SizedBox(height: 16),
                        NiosCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const NiosSectionTitle('Действия'),
                              const SizedBox(height: 12),
                              _buildActionTile(
                                icon: Icons.edit,
                                title: 'Изменить имя',
                                onTap: () {
                                  // TODO: Navigate to edit name
                                },
                              ),
                              const Divider(height: 1),
                              _buildActionTile(
                                icon: Icons.photo_camera,
                                title: 'Сменить фото',
                                onTap: () {
                                  // TODO: Change avatar
                                },
                              ),
                              const Divider(height: 1),
                              _buildActionTile(
                                icon: Icons.share,
                                title: 'Поделиться профилем',
                                onTap: () {
                                  // TODO: Share profile
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: NiosPalette.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: NiosPalette.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: NiosPalette.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: NiosPalette.surfaceHover,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: NiosPalette.text, size: 20),
      ),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, color: NiosPalette.textSecondary),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
