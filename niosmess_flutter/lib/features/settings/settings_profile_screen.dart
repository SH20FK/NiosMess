import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/session_provider.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/storage/offline_cache.dart';
import '../../core/settings_provider.dart';
import '../../core/send_queue_provider.dart';
import '../../ui/nios_ui.dart';
import '../../ui/widgets/animated_list_item.dart';

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
    if (!session.isAuthed) {
      setState(() => _loading = false);
      return;
    }
    final cachedProfile = await OfflineCache.loadProfile(session.username!);
    final cachedSessions = await OfflineCache.loadSessions(session.username!);
    if (mounted) {
      setState(() {
        _profileData = cachedProfile;
        _sessions = cachedSessions;
        _aboutController.text =
            (cachedProfile?['about'] ?? cachedProfile?['bio'] ?? '').toString();
        _loading = false;
      });
    }
    try {
      final profile =
          await api.getUserInfo(session.username!, session.username!, session.token!);
      final sessions = await api.getSessions(session.username!, session.token!);
      await OfflineCache.saveProfile(session.username!, profile);
      await OfflineCache.saveSessions(session.username!, sessions);
      if (!mounted) return;
      setState(() {
        _profileData = profile;
        _sessions = sessions;
        _aboutController.text = (profile['about'] ?? profile['bio'] ?? '').toString();
      });
    } catch (_) {
      // keep cached data if network fails
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
    final session = ref.read(sessionProvider);
    if (session.isAuthed) {
      api.logoutSession(session.username!, session.token!).catchError((e) {
        debugPrint('Logout session error: $e');
      });
    }
    ref.read(sessionProvider.notifier).clear();
    OfflineCache.clearAll();
    ref.read(sendQueueProvider.notifier).clearAll();
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
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = (ref.watch(settingsProvider)['reduce_motion'] as bool?) ?? false;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          onPressed: widget.onBack,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          ),
        ),
        title: Text(
          'Профиль',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: NiosMotionWrap(
                    enableMotion: !reduceMotion,
                    delay: const Duration(milliseconds: 40),
                    blurSigma: 10,
                    offset: const Offset(0, 18),
                    child: AnimatedListItem(
                      index: 0,
                      child: _buildProfileHeader(context),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: NiosMotionWrap(
                    enableMotion: !reduceMotion,
                    delay: const Duration(milliseconds: 70),
                    blurSigma: 10,
                    offset: const Offset(0, 18),
                    child: AnimatedListItem(
                      index: 1,
                      child: _buildActionsSection(context),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: NiosMotionWrap(
                    enableMotion: !reduceMotion,
                    delay: const Duration(milliseconds: 100),
                    blurSigma: 10,
                    offset: const Offset(0, 18),
                    child: AnimatedListItem(
                      index: 2,
                      child: _buildAboutSection(context),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: NiosMotionWrap(
                    enableMotion: !reduceMotion,
                    delay: const Duration(milliseconds: 130),
                    blurSigma: 10,
                    offset: const Offset(0, 18),
                    child: AnimatedListItem(
                      index: 3,
                      child: _buildInfoSection(context),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: NiosMotionWrap(
                    enableMotion: !reduceMotion,
                    delay: const Duration(milliseconds: 160),
                    blurSigma: 10,
                    offset: const Offset(0, 18),
                    child: AnimatedListItem(
                      index: 4,
                      child: _buildLogoutButton(context),
                    ),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 100, 16, 16),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Hero(
                tag: 'profile_avatar',
                child: Material(
                  elevation: 2,
                  shape: const CircleBorder(),
                  shadowColor: colorScheme.primary.withOpacity(0.2),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      _name.isNotEmpty ? _name.characters.first.toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _name,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              if (_username.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '@$_username',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Действия',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                _buildAnimatedTile(
                  context,
                  icon: Icons.camera_alt_outlined,
                  title: 'Изменить фото',
                  onTap: _changeAvatar,
                ),
                const Divider(height: 1, indent: 56),
                _buildAnimatedTile(
                  context,
                  icon: Icons.edit_outlined,
                  title: 'Изменить имя',
                  onTap: _changeName,
                ),
                const Divider(height: 1, indent: 56),
                _buildAnimatedTile(
                  context,
                  icon: Icons.alternate_email_outlined,
                  title: 'Изменить username',
                  onTap: _changeUsername,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'О себе',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _aboutController,
                    maxLines: 3,
                    style: textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Расскажите о себе...',
                      hintStyle: textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveAbout,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Сохранить'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Информация',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                _buildInfoTile(
                  context,
                  icon: Icons.email_outlined,
                  title: 'Email',
                  subtitle: _email.isNotEmpty ? _email : 'Не указан',
                ),
                const Divider(height: 1, indent: 56),
                _buildInfoTile(
                  context,
                  icon: Icons.devices_outlined,
                  title: 'Активные сессии',
                  subtitle: '${_sessions.length} устройств',
                  onTap: _showDevicesSheet,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap != null
          ? Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: FilledButton.tonalIcon(
        onPressed: _logout,
        icon: const Icon(Icons.logout),
        label: const Text('Выйти из аккаунта'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
