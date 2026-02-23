import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/session_provider.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/storage/offline_cache.dart';

class SettingsProfileScreen extends ConsumerStatefulWidget {
  const SettingsProfileScreen({
    super.key,
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  ConsumerState<SettingsProfileScreen> createState() => _SettingsProfileScreenState();
}

class _SettingsProfileScreenState extends ConsumerState<SettingsProfileScreen> {
  final api = ApiRepository();
  final _picker = ImagePicker();
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  final _aboutController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    try {
      final profile = await api.getUserInfo(session.username!, session.username!, session.token!);
      final sessions = await api.getSessions(session.username!, session.token!);
      setState(() {
        _profileData = profile;
        _sessions = sessions;
        _aboutController.text = (profile['about'] ?? profile['bio'] ?? '').toString();
        _loading = false;
      });
    } catch (_) {
      final cached = await OfflineCache.loadProfile(session.username!);
      setState(() {
        _profileData = cached;
        _loading = false;
      });
    }
  }

  String get _name => (_profileData?['name'] ??
          _profileData?['display_name'] ??
          _profileData?['username'] ??
          'Пользователь')
      .toString();

  String get _username => (_profileData?['username'] ?? '').toString();

  String get _email => (_profileData?['email'] ?? _profileData?['mail'] ?? '').toString();

  Future<void> _changeAvatar() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    try {
      await api.setAvatar(session.username!, session.token!, file.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фото обновлено')),
      );
      await _loadData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить фото')),
      );
    }
  }

  Future<void> _changeName() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    final controller = TextEditingController(text: _name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Изменить имя'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Имя'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await api.setName(session.username!, session.token!, name);
      final updated = {...?_profileData, 'name': name};
      await OfflineCache.saveProfile(session.username!, updated);
      await ref.read(sessionProvider.notifier).setSession(
            SessionState(token: session.token, username: session.username, name: name),
          );
      if (!mounted) return;
      setState(() => _profileData = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Имя обновлено')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить имя')),
      );
    }
  }

  Future<void> _changeUsername() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    final controller = TextEditingController(text: _username);
    final newUsername = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Изменить username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (newUsername == null || newUsername.isEmpty) return;
    try {
      await api.setUsername(session.username!, session.token!, newUsername);
      final updated = {...?_profileData, 'username': newUsername};
      await OfflineCache.saveProfile(newUsername, updated);
      await ref.read(sessionProvider.notifier).setSession(
            SessionState(token: session.token, username: newUsername, name: session.name),
          );
      if (!mounted) return;
      setState(() => _profileData = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username обновлен')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить username')),
      );
    }
  }

  Future<void> _saveAbout() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    try {
      await api.setAbout(session.username!, session.token!, _aboutController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль обновлен')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить')),
      );
    }
  }

  void _logout() {
    ref.read(sessionProvider.notifier).clear();
  }

  void _showDevicesSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Активные сессии', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (_sessions.isEmpty)
                Text('Нет активных сессий', style: Theme.of(context).textTheme.bodyMedium)
              else
                ..._sessions.map((s) {
                  final device = (s['device'] ?? s['user_agent'] ?? 'Неизвестно').toString();
                  return ListTile(
                    leading: const Icon(Icons.phone_iphone),
                    title: Text(device),
                    dense: true,
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Профиль'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            _name.isNotEmpty ? _name.characters.first.toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (_username.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('@$_username', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Действия', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.camera_alt_outlined),
                        title: const Text('Изменить фото'),
                        onTap: _changeAvatar,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Изменить имя'),
                        onTap: _changeName,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.alternate_email_outlined),
                        title: const Text('Изменить username'),
                        onTap: _changeUsername,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('О себе', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _aboutController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Расскажите о себе...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _saveAbout,
                          child: const Text('Сохранить'),
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
                        subtitle: Text(_email.isNotEmpty ? _email : 'Не указан'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.devices_outlined),
                        title: const Text('Активные сессии'),
                        subtitle: Text('${_sessions.length} устройств'),
                        onTap: _showDevicesSheet,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Выйти из аккаунта'),
                ),
              ],
            ),
    );
  }
}
