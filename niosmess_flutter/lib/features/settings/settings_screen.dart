import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';
import '../../core/storage/offline_cache.dart';
import '../../core/settings_provider.dart';
import '../../core/theme_provider.dart';
import '../../ui/nios_ui.dart';

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
    _controller = TabController(length: 5, vsync: this);
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
                Tab(text: 'Персонализация'),
                Tab(text: 'Уведомления'),
                Tab(text: 'Конфиденциальность'),
                Tab(text: 'Дополнительно'),
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
                      _buildPersonalization(),
                      _buildNotifications(),
                      _buildPrivacy(),
                      _buildExtra(),
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

  Widget _buildPersonalization() {
    final themeState = ref.watch(themeProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NiosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NiosSectionTitle('Внешний вид'),
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
        const SizedBox(height: 12),
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

  Widget _buildExtra() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _toggleTile('Автосохранение черновиков', 'Сохранять неотправленные сообщения', _getBool('autosave_drafts', true),
            (v) => _updateSetting('autosave_drafts', v)),
        const SizedBox(height: 12),
        _toggleTile('Сокращать пробелы', 'Убирать лишние пробелы в сообщениях', _getBool('trim_spaces', false),
            (v) => _updateSetting('trim_spaces', v)),
        const SizedBox(height: 12),
        NiosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NiosSectionTitle('Устройства'),
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
