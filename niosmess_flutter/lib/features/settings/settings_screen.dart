import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';
import '../../core/storage/offline_cache.dart';
import '../../core/settings_provider.dart';
import '../../core/theme_provider.dart';
import '../../core/bubble_style_provider.dart';
import '../../core/wallpaper_provider.dart';
import '../../ui/nios_ui.dart';
import '../../ui/widgets/bubble_style_preview.dart';
import '../../ui/widgets/wallpaper_selector.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _controller;
  final api = ApiRepository();
  final nameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final aboutCtrl = TextEditingController();
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String _whoCanWrite = 'all';
  ProviderSubscription? _settingsSub;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 6, vsync: this);

    final current = ref.read(settingsProvider);
    _whoCanWrite = current['who_can_write']?.toString() ?? 'all';
    _settingsSub = ref.listenManual(settingsProvider, (previous, next) {
      if (!mounted) return;
      final updated = next['who_can_write']?.toString() ?? 'all';
      if (updated != _whoCanWrite) {
        setState(() => _whoCanWrite = updated);
      }
    });
    _loadAll();
  }

  @override
  void dispose() {
    _controller.dispose();
    nameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    aboutCtrl.dispose();
    _settingsSub?.close();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadUser();
    await _loadSessions();
  }

  Future<void> _loadUser() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    try {
      final data = await api.getUserInfo(session.username!, session.username!, session.token!);
      await OfflineCache.saveProfile(session.username!, data);
      _applyProfile(data);
    } catch (_) {
      final cached = await OfflineCache.loadProfile(session.username!);
      if (cached != null) _applyProfile(cached);
    }
    setState(() => _loading = false);
  }

  void _applyProfile(Map<String, dynamic> data) {
    nameCtrl.text = (data['name'] ?? data['display_name'] ?? data['username'] ?? '').toString();
    usernameCtrl.text = (data['username'] ?? '').toString();
    emailCtrl.text = (data['email'] ?? data['mail'] ?? data['e_mail'] ?? '').toString();
    aboutCtrl.text = (data['about'] ?? data['bio'] ?? data['desc'] ?? data['about_me'] ?? '').toString();
  }

  Future<void> _loadSessions() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    try {
      final data = await api.getSessions(session.username!, session.token!);
      await OfflineCache.saveSessions(session.username!, data);
      setState(() => _sessions = data);
    } catch (_) {
      final cached = await OfflineCache.loadSessions(session.username!);
      setState(() => _sessions = cached);
    }
  }

  Future<void> _saveAbout() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    try {
      await api.setAbout(session.username!, session.token!, aboutCtrl.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Профиль обновлен')));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось сохранить')));
    }
  }

  void _updateSetting(String key, dynamic value) {
    ref.read(settingsProvider.notifier).setSetting(key, value);
  }

  bool _getBool(String key, bool fallback) => (ref.watch(settingsProvider)[key] as bool?) ?? fallback;

  @override
  Widget build(BuildContext context) {
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
                const Text('Настройки', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
            TabBar(
              controller: _controller,
              isScrollable: true,
              labelColor: NiosPalette.text,
              unselectedLabelColor: NiosPalette.textSecondary,
              labelPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              indicator: BoxDecoration(
                color: NiosPalette.surfaceHover,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: NiosPalette.borderLight),
              ),
              tabs: const [
                Tab(text: 'Аккаунт'),
                Tab(text: 'Внешний вид'),
                Tab(text: 'Уведомления'),
                Tab(text: 'Конфиденциальность'),
                Tab(text: 'Данные'),
                Tab(text: 'О приложении'),
              ],

            ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _controller,
                    children: [
                      _buildAccount(),
                      _buildAppearance(),
                      _buildNotifications(),
                      _buildPrivacy(),
                      _buildData(),
                      _buildAbout(),
                    ],

                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccount() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NiosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NiosSectionTitle('Мой аккаунт'),
              const SizedBox(height: 12),
              _inputTile('Имя', nameCtrl, readOnly: true),
              const SizedBox(height: 12),
              _inputTile('Имя пользователя', usernameCtrl, readOnly: true),
              const SizedBox(height: 12),
              _inputTile('Email', emailCtrl, readOnly: true),
              const SizedBox(height: 12),
              _inputTile('О себе', aboutCtrl, multiline: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        NiosPrimaryButton(label: 'Сохранить изменения', onTap: _saveAbout),
      ],
    );
  }

  Widget _buildAppearance() {
    final themeState = ref.watch(themeProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Theme Selection
        NiosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NiosSectionTitle('Тема оформления'),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: niosThemePresets.map((preset) {
                    final active = preset.id == themeState.preset.id;
                    return _themeTile(preset, active);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Bubble Style Customization
        NiosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NiosSectionTitle('Стиль сообщений'),
              const SizedBox(height: 4),
              Text(
                'Настройте внешний вид пузырей сообщений',
                style: TextStyle(
                  fontSize: 13,
                  color: NiosPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const BubbleStyleCustomizer(),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Chat Wallpaper
        NiosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NiosSectionTitle('Фон чата'),
              const SizedBox(height: 4),
              Text(
                'Выберите обои для фона переписки',
                style: TextStyle(
                  fontSize: 13,
                  color: NiosPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const WallpaperSelector(),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Text Size Slider
        NiosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NiosSectionTitle('Размер текста'),
              const SizedBox(height: 12),
              _buildSliderSection(
                title: 'Масштаб текста',
                value: ref.watch(settingsProvider)['text_scale']?.toDouble() ?? 1.0,
                min: 0.8,
                max: 1.3,
                onChanged: (value) => _updateSetting('text_scale', value),
                displayValue: '${((ref.watch(settingsProvider)['text_scale']?.toDouble() ?? 1.0) * 100).toInt()}%',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NiosPalette.surfaceHover,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Пример текста в чате',
                  style: TextStyle(
                    fontSize: (16 * (ref.watch(settingsProvider)['text_scale']?.toDouble() ?? 1.0)).toDouble(),
                    color: NiosPalette.text,
                  ),
                ),

              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // App Icon Selector
        NiosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NiosSectionTitle('Иконка приложения'),
              const SizedBox(height: 12),
              _buildAppIconGrid(),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // General Appearance Settings
        _toggleTile('Снизить анимации', 'Меньше эффектов в интерфейсе', _getBool('reduce_motion', false),
            (v) => _updateSetting('reduce_motion', v)),
        const SizedBox(height: 12),
        _toggleTile('Компактные сообщения', 'Меньше отступов в чате', _getBool('compact_messages', false),
            (v) => _updateSetting('compact_messages', v)),
        const SizedBox(height: 12),
        _toggleTile('Превью ссылок', 'Карточки для ссылок в чате', _getBool('link_preview', true),
            (v) => _updateSetting('link_preview', v)),
      ],
    );
  }

  Widget _buildSliderSection({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String displayValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: NiosPalette.surfaceHover,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayValue,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 10,
          label: displayValue,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildAppIconGrid() {
    final icons = [
      _AppIconOption('Классика', Icons.message, Colors.blue),
      _AppIconOption('Неон', Icons.chat_bubble, Colors.cyan),
      _AppIconOption('Стелс', Icons.chat_bubble_outline, Colors.grey),
      _AppIconOption('Огонь', Icons.local_fire_department, Colors.orange),
      _AppIconOption('VIP', Icons.workspace_premium, Colors.amber),
      _AppIconOption('Ночь', Icons.dark_mode, Colors.indigo),
    ];
    
    final currentIcon = ref.watch(settingsProvider)['app_icon']?.toString() ?? 'Классика';

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: icons.length,
      itemBuilder: (context, index) {
        final icon = icons[index];
        final isSelected = icon.name == currentIcon;
        
        return GestureDetector(
          onTap: () => _updateSetting('app_icon', icon.name),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? icon.color.withOpacity(0.15) : NiosPalette.surfaceHover,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? icon.color : NiosPalette.borderLight,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: icon.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon.icon,
                    color: icon.color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  icon.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? icon.color : NiosPalette.text,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildNotifications() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _toggleTile('Звуки сообщений', 'Звук при новых сообщениях', _getBool('notify_sound', true),
            (v) => _updateSetting('notify_sound', v)),
        const SizedBox(height: 12),
        _toggleTile('Превью текста', 'Показывать текст сообщений', _getBool('notify_preview', false),
            (v) => _updateSetting('notify_preview', v)),
      ],
    );
  }

  Widget _buildPrivacy() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _toggleTile('Показывать статус', 'Когда вы в сети', _getBool('show_status', true),
            (v) => _updateSetting('show_status', v)),
        const SizedBox(height: 12),
        _toggleTile('Последний раз в сети', 'Время последнего входа', _getBool('show_last_seen', true),
            (v) => _updateSetting('show_last_seen', v)),
        const SizedBox(height: 12),
        _toggleTile('Индикатор набора', 'Когда вы печатаете', _getBool('show_typing', true),
            (v) => _updateSetting('show_typing', v)),
        const SizedBox(height: 12),
        NiosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NiosSectionTitle('Кто может писать мне'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _whoCanWrite,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Все')),
                  DropdownMenuItem(value: 'contacts', child: Text('Контакты')),
                  DropdownMenuItem(value: 'nobody', child: Text('Никто')),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _whoCanWrite = val);
                  _updateSetting('who_can_write', val);
                },
                decoration: niosInputDecoration('Кто может писать'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildData() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Storage Usage
        NiosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NiosSectionTitle('Хранилище'),
              const SizedBox(height: 16),
              _buildStorageBar(),
              const SizedBox(height: 16),
              _buildStorageItem(
                icon: Icons.image,
                color: Colors.blue,
                label: 'Фото и видео',
                size: '245 MB',
              ),
              const Divider(height: 24),
              _buildStorageItem(
                icon: Icons.music_note,
                color: Colors.purple,
                label: 'Аудио сообщения',
                size: '128 MB',
              ),
              const Divider(height: 24),
              _buildStorageItem(
                icon: Icons.insert_drive_file,
                color: Colors.orange,
                label: 'Файлы и документы',
                size: '56 MB',
              ),
              const Divider(height: 24),
              _buildStorageItem(
                icon: Icons.chat_bubble,
                color: Colors.green,
                label: 'Сообщения и кэш',
                size: '32 MB',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Очистить кэш'),
                        content: const Text('Удалить все временные файлы?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Отмена'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Кэш очищен')),
                              );
                            },
                            child: const Text('Очистить'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Очистить кэш'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Data Usage Settings
        _toggleTile('Автосохранение медиа', 'Сохранять фото и видео в галерею', _getBool('autosave_media', false),
            (v) => _updateSetting('autosave_media', v)),
        const SizedBox(height: 12),
        _toggleTile('Экономия трафика', 'Сжимать изображения при отправке', _getBool('data_saver', false),
            (v) => _updateSetting('data_saver', v)),
        const SizedBox(height: 12),
        _toggleTile('Автосохранение черновиков', 'Сохранять неотправленные сообщения', _getBool('autosave_drafts', true),
            (v) => _updateSetting('autosave_drafts', v)),
      ],
    );
  }

  Widget _buildStorageBar() {
    final total = 461.0;
    final segments = [
      _StorageSegment(Colors.blue, 245 / total, 'Фото'),
      _StorageSegment(Colors.purple, 128 / total, 'Аудио'),
      _StorageSegment(Colors.orange, 56 / total, 'Файлы'),
      _StorageSegment(Colors.green, 32 / total, 'Кэш'),
    ];

    return Column(
      children: [
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: Colors.grey.withOpacity(0.2),
          ),
          child: Row(
            children: segments.map((s) {
              return Expanded(
                flex: (s.percent * 100).round(),
                child: Container(
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Всего: ${total.toStringAsFixed(0)} MB',
              style: TextStyle(
                fontSize: 13,
                color: NiosPalette.textSecondary,
              ),
            ),
            Text(
              'Свободно: 12.4 GB',
              style: TextStyle(
                fontSize: 13,
                color: NiosPalette.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStorageItem({
    required IconData icon,
    required Color color,
    required String label,
    required String size,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          size,
          style: TextStyle(
            fontSize: 14,
            color: NiosPalette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAbout() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // App Info
        NiosCard(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: NiosPalette.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.message,
                  size: 40,
                  color: NiosPalette.accent,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'NiosMess',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Версия 2.0.0 (Telegram Edition)',
                style: TextStyle(
                  fontSize: 14,
                  color: NiosPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Современный мессенджер с расширенной кастомизацией',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: NiosPalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Sessions
        NiosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NiosSectionTitle('Активные сессии'),
              const SizedBox(height: 12),
              if (_sessions.isEmpty)
                Text('Сессий нет', style: TextStyle(color: NiosPalette.textSecondary))
              else
                Column(
                  children: _sessions.map((s) {
                    final device = (s['device'] ?? s['user_agent'] ?? s['ua'] ?? '').toString();
                    final ip = (s['ip'] ?? '').toString();
                    final last = (s['last_activity'] ?? s['last_seen'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(device, style: TextStyle(color: NiosPalette.text))),
                          if (ip.isNotEmpty) Text(ip, style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
                          if (last.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(last, style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loadSessions,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NiosPalette.text,
                        side: BorderSide(color: NiosPalette.border),
                      ),
                      child: const Text('Обновить'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final session = ref.read(sessionProvider);
                        if (!session.isAuthed) return;
                        await api.logoutOtherSessions(session.username!, session.token!);
                        await _loadSessions();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF04444)),
                      child: const Text('Выйти на других'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(sessionProvider.notifier).clear();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD64545)),
                  child: const Text('Выйти из аккаунта'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _toggleTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return NiosCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _inputTile(String label, TextEditingController controller, {bool multiline = false, bool readOnly = false}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: multiline ? 3 : 1,
      decoration: niosInputDecoration(label),
    );
  }

  Widget _themeTile(NiosThemePreset preset, bool active) {
    return InkWell(
      onTap: () => ref.read(themeProvider.notifier).setTheme(preset.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: preset.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? NiosPalette.accent : NiosPalette.border),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: NiosPalette.shadowGlow,
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(preset.label, style: TextStyle(color: preset.text)),
          ),
        ),
      ),
    );
  }
}

class _StorageSegment {
  final Color color;
  final double percent;
  final String label;

  _StorageSegment(this.color, this.percent, this.label);
}

class _AppIconOption {
  final String name;
  final IconData icon;
  final Color color;

  _AppIconOption(this.name, this.icon, this.color);
}
