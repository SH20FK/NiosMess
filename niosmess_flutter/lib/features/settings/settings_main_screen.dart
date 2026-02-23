import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/session_provider.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/storage/offline_cache.dart';
import '../../core/settings_provider.dart';
import '../../core/theme_provider.dart';
import '../../ui/nios_ui.dart';
import 'settings_profile_screen.dart';
import 'settings_appearance_screen_new.dart';
import 'settings_chat_screen.dart';
import 'settings_notifications_screen.dart';
import 'settings_privacy_screen.dart';
import 'settings_data_screen.dart';
import 'settings_advanced_screen.dart';

class SettingsMainScreen extends ConsumerStatefulWidget {
  const SettingsMainScreen({super.key});

  @override
  ConsumerState<SettingsMainScreen> createState() => _SettingsMainScreenState();
}

class _SettingsMainScreenState extends ConsumerState<SettingsMainScreen> {
  final api = ApiRepository();
  Map<String, dynamic>? _profileData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    try {
      final data = await api.getUserInfo(
          session.username!, session.username!, session.token!);
      await OfflineCache.saveProfile(session.username!, data);
      setState(() {
        _profileData = data;
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

  String get _status => (_profileData?['about'] ??
          _profileData?['bio'] ??
          _profileData?['status'] ??
          'Нет статуса')
      .toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                key: const ValueKey('settings_list'),
                padding: const EdgeInsets.fromLTRB(
                  NiosSpacing.md,
                  NiosSpacing.md,
                  NiosSpacing.md,
                  NiosSpacing.lg,
                ),
                children: [
                  _buildProfileCard(context),
                  const SizedBox(height: NiosSpacing.md),
                  _buildQuickToggles(context),
                  const SizedBox(height: NiosSpacing.md),
                  Text('Основное',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: NiosSpacing.sm),
                  _buildTileGroup(
                    context,
                    children: [
                      _buildTile(
                        context,
                        icon: Icons.person_outline,
                        title: 'Профиль',
                        subtitle: 'Имя, фото, о себе',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingsProfileScreen(
                              onBack: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                      _buildDivider(context),
                      _buildTile(
                        context,
                        icon: Icons.palette_outlined,
                        title: 'Внешний вид',
                        subtitle: 'Тема, цвета, стиль чата',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingsAppearanceScreen(
                              onBack: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                      _buildDivider(context),
                      _buildTile(
                        context,
                        icon: Icons.chat_bubble_outline,
                        title: 'Чаты',
                        subtitle: 'Черновики, отправка, отображение',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingsChatScreen(
                              onBack: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                      _buildDivider(context),
                      _buildTile(
                        context,
                        icon: Icons.notifications_outlined,
                        title: 'Уведомления',
                        subtitle: 'Звуки, предпросмотр, упоминания',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingsNotificationsScreen(
                              onBack: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                      _buildDivider(context),
                      _buildTile(
                        context,
                        icon: Icons.lock_outline,
                        title: 'Конфиденциальность',
                        subtitle: 'Видимость, безопасность, режимы',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingsPrivacyScreen(
                              onBack: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                      _buildDivider(context),
                      _buildTile(
                        context,
                        icon: Icons.storage_outlined,
                        title: 'Данные и память',
                        subtitle: 'Кэш, автозагрузка',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingsDataScreen(
                              onBack: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                      _buildDivider(context),
                      _buildTile(
                        context,
                        icon: Icons.tune_outlined,
                        title: 'Дополнительно',
                        subtitle: 'Анимации, эксперименты',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingsAdvancedScreen(
                              onBack: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NiosSpacing.lg),
                  Center(
                    child: Text(
                      'NiosMess v2.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildTileGroup(
      context,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.all(NiosSpacing.md),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SettingsProfileScreen(
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              _name.isNotEmpty ? _name.characters.first.toUpperCase() : '?',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Text(
            _name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_username.isNotEmpty)
                Text('@$_username', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                _status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildQuickToggles(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final settings = ref.watch(settingsProvider);
    final isDarkMode = themeState.mode == ThemeMode.dark;
    final soundEnabled = settings['notify_sound'] as bool? ?? true;
    final vibrationEnabled = settings['notify_vibrate'] as bool? ?? true;

    return _buildTileGroup(
      context,
      children: [
        SwitchListTile(
          title: const Text('Темная тема'),
          subtitle: const Text('Быстро переключить внешний вид'),
          value: isDarkMode,
          onChanged: (enabled) {
            final targetMode = enabled ? ThemeMode.dark : ThemeMode.light;
            ref.read(themeProvider.notifier).setThemeMode(targetMode);
          },
        ),
        _buildDivider(context),
        SwitchListTile(
          title: const Text('Звук'),
          subtitle: const Text('Сигнал при новых сообщениях'),
          value: soundEnabled,
          onChanged: (enabled) {
            ref
                .read(settingsProvider.notifier)
                .setSetting('notify_sound', enabled);
          },
        ),
        _buildDivider(context),
        SwitchListTile(
          title: const Text('Вибрация'),
          subtitle: const Text('Вибро-отклик для уведомлений'),
          value: vibrationEnabled,
          onChanged: (enabled) {
            ref
                .read(settingsProvider.notifier)
                .setSetting('notify_vibrate', enabled);
          },
        ),
      ],
    );
  }

  Widget _buildTileGroup(BuildContext context, {required List<Widget> children}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
