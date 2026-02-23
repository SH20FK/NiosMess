import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animations/animations.dart';
import '../../core/session_provider.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/storage/offline_cache.dart';
import '../../core/settings_provider.dart';
import '../../core/theme_provider.dart';
import '../../ui/nios_ui.dart';
import '../../ui/widgets/animated_list_item.dart';
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
    if (!session.isAuthed) {
      setState(() => _loading = false);
      return;
    }
    final cached = await OfflineCache.loadProfile(session.username!);
    if (mounted) {
      setState(() {
        _profileData = cached;
        _loading = cached == null;
      });
    }
    try {
      final data = await api.getUserInfo(
          session.username!, session.username!, session.token!);
      await OfflineCache.saveProfile(session.username!, data);
      if (!mounted) return;
      setState(() {
        _profileData = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted && cached == null) {
        setState(() => _loading = false);
      }
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

  void _navigateWithAnimation(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _popWithAnimation() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
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
        title: Text(
          'Настройки',
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
              key: const ValueKey('settings_list'),
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
                      child: _buildProfileCard(context),
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
                      child: _buildQuickToggles(context),
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
                      child: _buildSettingsSection(context),
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
                      child: _buildVersionInfo(context),
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

  Widget _buildProfileCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 100, 16, 8),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _navigateWithAnimation(
            context,
            SettingsProfileScreen(onBack: _popWithAnimation),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Hero(
                  tag: 'profile_avatar',
                  child: Material(
                    elevation: 1,
                    shape: const CircleBorder(),
                    shadowColor: colorScheme.primary.withOpacity(0.2),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        _name.isNotEmpty ? _name.characters.first.toUpperCase() : '?',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_username.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@$_username',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickToggles(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final settings = ref.watch(settingsProvider);
    final isDarkMode = themeState.mode == ThemeMode.dark;
    final soundEnabled = settings['notify_sound'] as bool? ?? true;
    final vibrationEnabled = settings['notify_vibrate'] as bool? ?? true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickToggle(
                context,
                icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
                label: isDarkMode ? 'Темная' : 'Светлая',
                isActive: isDarkMode,
                onTap: () {
                  final targetMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
                  ref.read(themeProvider.notifier).setThemeMode(targetMode);
                },
              ),
              Container(
                width: 1,
                height: 40,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              _buildQuickToggle(
                context,
                icon: soundEnabled ? Icons.volume_up : Icons.volume_off,
                label: 'Звук',
                isActive: soundEnabled,
                onTap: () {
                  ref.read(settingsProvider.notifier).setSetting('notify_sound', !soundEnabled);
                },
              ),
              Container(
                width: 1,
                height: 40,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              _buildQuickToggle(
                context,
                icon: vibrationEnabled ? Icons.vibration : Icons.smartphone,
                label: 'Вибро',
                isActive: vibrationEnabled,
                onTap: () {
                  ref.read(settingsProvider.notifier).setSetting('notify_vibrate', !vibrationEnabled);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickToggle(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
            child: Text(
              'Основное',
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
                _buildSettingsTile(
                  context,
                  icon: Icons.person_outline,
                  title: 'Профиль',
                  subtitle: 'Имя, фото, о себе',
                  onTap: () => _navigateWithAnimation(
                    context,
                    SettingsProfileScreen(onBack: _popWithAnimation),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingsTile(
                  context,
                  icon: Icons.palette_outlined,
                  title: 'Внешний вид',
                  subtitle: 'Тема, цвета, стиль чата',
                  onTap: () => _navigateWithAnimation(
                    context,
                    SettingsAppearanceScreen(onBack: _popWithAnimation),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingsTile(
                  context,
                  icon: Icons.chat_bubble_outline,
                  title: 'Чаты',
                  subtitle: 'Черновики, отправка, отображение',
                  onTap: () => _navigateWithAnimation(
                    context,
                    SettingsChatScreen(onBack: _popWithAnimation),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingsTile(
                  context,
                  icon: Icons.notifications_outlined,
                  title: 'Уведомления',
                  subtitle: 'Звуки, предпросмотр, упоминания',
                  onTap: () => _navigateWithAnimation(
                    context,
                    SettingsNotificationsScreen(onBack: _popWithAnimation),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingsTile(
                  context,
                  icon: Icons.lock_outline,
                  title: 'Конфиденциальность',
                  subtitle: 'Видимость, безопасность, режимы',
                  onTap: () => _navigateWithAnimation(
                    context,
                    SettingsPrivacyScreen(onBack: _popWithAnimation),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingsTile(
                  context,
                  icon: Icons.storage_outlined,
                  title: 'Данные и память',
                  subtitle: 'Кэш, автозагрузка',
                  onTap: () => _navigateWithAnimation(
                    context,
                    SettingsDataScreen(onBack: _popWithAnimation),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingsTile(
                  context,
                  icon: Icons.tune_outlined,
                  title: 'Дополнительно',
                  subtitle: 'Анимации, эксперименты',
                  onTap: () => _navigateWithAnimation(
                    context,
                    SettingsAdvancedScreen(onBack: _popWithAnimation),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      child: Center(
        child: Column(
          children: [
            Text(
              'NiosMess v2.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Made with ❤️ by Nios Team',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
