import 'package:flutter/material.dart';

// ─── Mock Data ───────────────────────────────────────────────────────────────

const _seedColor = Color(0xFF6750A4);

final _users = [
  _MockUser('Alina', _c(0xFFE85D75)),
  _MockUser('Mike', _c(0xFF4CAF50)),
  _MockUser('Dmitry', _c(0xFF4F8EF7)),
  _MockUser('Marina', _c(0xFF9B5DE5)),
  _MockUser('Sasha', _c(0xFFFF9100)),
];

const _c = Color.new;

const _chats = [
  ('Alina', 'Привет! Как дела? 😊', '12:45', 2),
  ('Dev Chat', 'Mike: Сделал рефакторинг', '11:30', 5),
  ('Tech News', 'Flutter 4.0 вышел!', '10:15', 0),
  ('Marina', 'Голосовое сообщение', '9:40', 0),
  ('Mike', 'Го завтра встретимся?', 'вчера', 1),
  ('Dmitry', 'Ок, я за', 'вчера', 0),
];

final _messages = [
  ('Привет! Как дела?', false, '12:40'),
  ('Привет! Всё отлично, у тебя как?', true, '12:41'),
  ('Тоже норм! Гулял сегодня в парке, погода супер', true, '12:42'),
  ('Класс! Я тоже хочу выбраться на выходных', false, '12:43'),
  ('Давай сходим куда-нибудь? 🎬', false, '12:44'),
  ('Отличная идея! Давай', true, '12:45'),
];

final _groupMessages = [
  ('Mike', 'Сделал рефакторинг модуля авторизации', _c(0xFF4CAF50)),
  ('Alina', 'Отлично, Mike! Я посмотрю код', _c(0xFFE85D75)),
  ('Dmitry', 'Ребят, кто завтра деплой делает?', _c(0xFF4F8EF7)),
  ('Mike', 'Я могу, если никто не против', _c(0xFF4CAF50)),
  ('Alina', 'Давай, я потом проверю', _c(0xFFE85D75)),
];

final _channelPosts = [
  ('Flutter 4.0 вышел!', 'Новая версия с Impeller на iOS, улучшенным веб-рендерингом и новыми виджетами.', '2.5K', '48'),
  ('Dart 4.0 бета', 'Macros, pattern matching v2 и значительные улучшения производительности.', '1.8K', '32'),
  ('Material You обновление', 'Новые компоненты M3: NavigationBar, SearchBar и DatePicker.', '3.2K', '67'),
];

final _niosgramPosts = [
  _NgPost('Alina', 'alina_dev', 'Запустили новый фидбек-сервис на Go! 🚀 Микросервисы — это любовь', '142', '18', const Color(0xFFE85D75)),
  _NgPost('Mike', 'mike_codes', 'Рефакторинг легаси — это как разминирование поля. Шаг влево, шаг вправо — баг.', '89', '7', const Color(0xFF4CAF50)),
  _NgPost('Tech News', 'tech_news', 'ИИ-ассистенты теперь пишут 40% кода в стартапах. Что думаете? 🤖', '1.2K', '93', const Color(0xFF4F8EF7)),
];

class _NgPost {
  const _NgPost(this.name, this.username, this.text, this.likes, this.comments, this.color);
  final String name;
  final String username;
  final String text;
  final String likes;
  final String comments;
  final Color color;
}

final _profileMenuItems = [
  _SettingsItem(Icons.color_lens_rounded, 'Appearance', 'Theme, colors, density'),
  _SettingsItem(Icons.language_rounded, 'Language & Region', 'English, Russian, time zone'),
  _SettingsItem(Icons.lock_rounded, 'Privacy & Security', 'Encryption, sessions, 2FA'),
  _SettingsItem(Icons.storage_rounded, 'Storage', 'Manage cached data'),
  _SettingsItem(Icons.info_outline_rounded, 'About', 'Version 2.1.0'),
];

// ─── Mock App ────────────────────────────────────────────────────────────────

class MockScreenshotsApp extends StatefulWidget {
  const MockScreenshotsApp({super.key, this.page = 0});
  final int page;

  @override
  State<MockScreenshotsApp> createState() => MockScreenshotsAppState();
}

class MockScreenshotsAppState extends State<MockScreenshotsApp> {
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.page;
  }

  void goToPage(int page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: _seedColor);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
      ),
      home: _MockShell(page: _page),
    );
  }
}

class _MockShell extends StatelessWidget {
  const _MockShell({required this.page});
  final int page;

  static const _screens = [
    _ChatsScreen(),
    _MessagesScreen(),
    _GroupScreen(),
    _ChannelScreen(),
    _NiosgramScreen(),
    _VoiceScreen(),
    _ThemesScreen(),
    _ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: page, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page > 2 ? 0 : page,
        onDestinationSelected: (_) {},
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Gram'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar(this.name, this.color, {this.size = 24});
  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size,
      backgroundColor: color,
      child: Text(name[0], style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.7)),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text('9:41', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
          const Spacer(),
          Row(children: [
            _signalIcon(scheme),
            const SizedBox(width: 4),
            _wifiIcon(scheme),
            const SizedBox(width: 4),
            _batteryIcon(scheme),
          ]),
        ],
      ),
    );
  }

  Widget _signalIcon(ColorScheme s) => Icon(Icons.signal_cellular_alt, size: 14, color: s.onSurfaceVariant);
  Widget _wifiIcon(ColorScheme s) => Icon(Icons.wifi, size: 14, color: s.onSurfaceVariant);
  Widget _batteryIcon(ColorScheme s) => Icon(Icons.battery_full, size: 14, color: s.onSurfaceVariant);
}

// ─── 1. Chats Screen ─────────────────────────────────────────────────────────

class _ChatsScreen extends StatelessWidget {
  const _ChatsScreen();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('NiosMess', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SearchBar(
              leading: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
              hintText: 'Search chats...',
              textStyle: WidgetStatePropertyAll(TextStyle(color: scheme.onSurface)),
              backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHighest.withValues(alpha: 0.5)),
              elevation: const WidgetStatePropertyAll(0),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
            ),
          ),
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(scheme, 'All', true, Icons.inbox_rounded),
                  const SizedBox(width: 8),
                  _filterChip(scheme, 'Unread', false, Icons.mark_chat_unread_rounded),
                  const SizedBox(width: 8),
                  _filterChip(scheme, 'Groups', false, Icons.groups_rounded),
                  const SizedBox(width: 8),
                  _filterChip(scheme, 'Channels', false, Icons.campaign_rounded),
                ],
              ),
            ),
          ),
          // Chat list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _chats.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final chat = _chats[i];
                final user = _users[i < _users.length ? i : 0];
                return _ChatTile(
                  name: chat.$1,
                  lastMessage: chat.$2,
                  time: chat.$3,
                  unread: chat.$4,
                  avatarColor: user.color,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(ColorScheme scheme, String label, bool selected, IconData icon) {
    return FilterChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) {},
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      side: BorderSide.none,
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.name, required this.lastMessage, required this.time, required this.unread, required this.avatarColor});
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final Color avatarColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        _Avatar(name, avatarColor, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(child: Text(name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(time, style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Text(lastMessage, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(999)),
                    alignment: Alignment.center,
                    child: Text('$unread', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── 2. Messages Screen ──────────────────────────────────────────────────────

class _MessagesScreen extends StatelessWidget {
  const _MessagesScreen();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () {}),
        title: Row(children: [
          _Avatar('Alina', _c(0xFFE85D75), size: 19),
          const SizedBox(width: 11),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Alina', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('online', style: TextStyle(fontSize: 12, color: Colors.green)),
          ]),
        ]),
        backgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.92),
        scrolledUnderElevation: 0,
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final msg = _messages[i];
              final isMine = msg.$2;
              return _MessageBubble(text: msg.$1, isMine: isMine, time: msg.$3);
            },
          ),
        ),
        // Input area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3))),
          ),
          child: Row(children: [
            IconButton(icon: Icon(Icons.emoji_emotions_outlined, color: scheme.onSurfaceVariant), onPressed: () {}),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 54),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Message',
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle, boxShadow: [
                BoxShadow(color: scheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ]),
              child: IconButton(icon: Icon(Icons.mic_rounded, color: scheme.onPrimary), onPressed: () {}),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.isMine, required this.time});
  final String text;
  final bool isMine;
  final String time;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              decoration: BoxDecoration(
                color: isMine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: scheme.shadow.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: TextStyle(color: isMine ? scheme.onPrimaryContainer : scheme.onSurface, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(time, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withValues(alpha: 0.7))),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_rounded, size: 13, color: scheme.primary.withValues(alpha: 0.8)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 3. Group Screen ─────────────────────────────────────────────────────────

class _GroupScreen extends StatelessWidget {
  const _GroupScreen();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () {}),
        title: Row(children: [
          _Avatar('D', _c(0xFF00BCD4), size: 19),
          const SizedBox(width: 11),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dev Chat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('8 members, 3 online', style: TextStyle(fontSize: 12)),
          ]),
        ]),
        backgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.92),
        scrolledUnderElevation: 0,
        actions: [
          PopupMenuButton(itemBuilder: (_) => []),
        ],
      ),
      body: Column(children: [
        // Group info header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(children: [
            SizedBox(
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < _users.take(5).length; i++)
                    Positioned(
                      left: i * 16.0,
                      child: _Avatar(_users[i].name, _users[i].color, size: 22),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Dev Chat', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text('8 members, 3 online', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
        const Divider(indent: 16, endIndent: 16),
        // Group messages
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _groupMessages.length,
            itemBuilder: (context, i) {
              final msg = _groupMessages[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(msg.$1, msg.$3, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(msg.$1, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: scheme.primary)),
                          const SizedBox(height: 2),
                          Text(msg.$2, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─── 4. Channel Screen ───────────────────────────────────────────────────────

class _ChannelScreen extends StatelessWidget {
  const _ChannelScreen();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () {}),
        title: Row(children: [
          _Avatar('T', _c(0xFFFF9100), size: 19),
          const SizedBox(width: 11),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tech News', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('1.2K subscribers', style: TextStyle(fontSize: 12)),
          ]),
        ]),
        backgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.92),
        scrolledUnderElevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _channelPosts.length,
        itemBuilder: (context, i) {
          final p = _channelPosts[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.$1, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(p.$2, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.4)),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.visibility_outlined, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(p.$3, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 16),
                  Icon(Icons.chat_bubble_outline_rounded, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(p.$4, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  const Spacer(),
                  Text('2h ago', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── 5. NiosGram Screen ──────────────────────────────────────────────────────

class _NiosgramScreen extends StatelessWidget {
  const _NiosgramScreen();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('NiosGram', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.add_circle_outline_rounded, color: scheme.primary), onPressed: () {}),
          IconButton(icon: Stack(children: [
            Icon(Icons.notifications_outlined, color: scheme.onSurfaceVariant),
            Positioned(
              right: 2, top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(8)),
                child: const Text('3', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]), onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 80),
        itemCount: _niosgramPosts.length,
        itemBuilder: (context, i) {
          final p = _niosgramPosts[i];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
                  child: Row(children: [
                    _Avatar(p.name, p.color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          Text('@${p.username} · 2h', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ]),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Text(p.text, style: const TextStyle(fontSize: 14, height: 1.4)),
                ),
                // Action bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                  child: Row(children: [
                    _actionChip(scheme, Icons.favorite_border_rounded, p.likes, scheme.error),
                    const SizedBox(width: 4),
                    _actionChip(scheme, Icons.chat_bubble_outline_rounded, p.comments, scheme.primary),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _actionChip(ColorScheme scheme, IconData icon, String count, Color activeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(count, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ─── 6. Voice Screen ─────────────────────────────────────────────────────────

class _VoiceScreen extends StatelessWidget {
  const _VoiceScreen();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () {}),
        title: Row(children: [
          _Avatar('Marina', _c(0xFF9B5DE5), size: 19),
          const SizedBox(width: 11),
          const Text('Marina', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        backgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.92),
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar('Marina', _c(0xFF9B5DE5), size: 32),
            const SizedBox(height: 16),
            const Text('Voice message', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('0:24 / 1:12', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            // Waveform
            SizedBox(
              width: 240,
              height: 40,
              child: CustomPaint(
                painter: _WaveformPainter(progress: 0.33, color: scheme.primary),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: Icon(Icons.skip_previous_rounded, color: scheme.onSurfaceVariant), onPressed: () {}),
                const SizedBox(width: 8),
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle, boxShadow: [
                    BoxShadow(color: scheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                  ]),
                  child: IconButton(icon: Icon(Icons.play_arrow_rounded, color: scheme.onPrimary, size: 32), onPressed: () {}),
                ),
                const SizedBox(width: 8),
                IconButton(icon: Icon(Icons.skip_next_rounded, color: scheme.onSurfaceVariant), onPressed: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 40;
    final barWidth = (size.width - (barCount - 1) * 2) / barCount;
    final halfH = size.height / 2;
    final playedPaint = Paint()..color = color;
    final unplayedPaint = Paint()..color = color.withValues(alpha: 0.18);

    for (int i = 0; i < barCount; i++) {
      final h = 2.0 + (i * 131 % 17) * 2.2;
      final x = i * (barWidth + 2);
      final paint = i / barCount < progress ? playedPaint : unplayedPaint;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, halfH - h / 2, barWidth, h), const Radius.circular(2)), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}

// ─── 7. Themes Screen ────────────────────────────────────────────────────────

class _ThemesScreen extends StatefulWidget {
  const _ThemesScreen();
  @override
  State<_ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<_ThemesScreen> {
  int _selectedPalette = 0;
  int _selectedTheme = 0;
  int _selectedDensity = 1;

  static const _palettes = [
    Color(0xFF9C27B0), // Amethyst
    Color(0xFF00897B), // Lagoon
    Color(0xFF558B2F), // Meadow
    Color(0xFFD84315), // Ember
    Color(0xFFC2185B), // Orchid
    Color(0xFF546E7A), // Slate
    Color(0xFF2F6FED), // Sky
    Color(0xFFB3265F), // Rose
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final orbSize = (screenWidth - 32) / 8 - 12;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () {}),
        title: const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color palette
            Text('Color palette', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _palettes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final selected = i == _selectedPalette;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPalette = i),
                    child: Container(
                      width: orbSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _palettes[i],
                        border: selected ? Border.all(color: scheme.primary, width: 3.5) : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Theme mode
            Text('Theme mode', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: scheme.surface,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('System')),
                        ButtonSegment(value: 1, label: Text('Light')),
                        ButtonSegment(value: 2, label: Text('Dark')),
                      ],
                      selected: {_selectedTheme},
                      onSelectionChanged: (v) => setState(() => _selectedTheme = v.first),
                      style: ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder())),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Density
            Text('Density', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: scheme.surface,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  children: ['Soft', 'Rich', 'Expressive'].asMap().entries.map((e) {
                    return ChoiceChip(
                      label: Text(e.value),
                      selected: e.key == _selectedDensity,
                      onSelected: (_) => setState(() => _selectedDensity = e.key),
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Preview
            Text('Preview', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _Avatar('A', scheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 60, height: 6, decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(height: 4),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.onSurfaceVariant, borderRadius: BorderRadius.circular(2))),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                    child: Text('Hello!', style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 12)),
                  )),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Hi there!', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 8. Profile Screen ──────────────────────────────────────────────────────

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // Profile header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40, bottom: 24),
              child: Column(children: [
                _Avatar('Sasha', _c(0xFFFF9100), size: 38),
                const SizedBox(height: 12),
                const Text('Sasha', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                const SizedBox(height: 4),
                Text('@sasha_dev', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
              ]),
            ),
          ),
          // Settings sections
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                _SettingsSection(scheme, _profileMenuItems.sublist(0, 2)),
                const SizedBox(height: 16),
                _SettingsSection(scheme, _profileMenuItems.sublist(2, 4)),
                const SizedBox(height: 16),
                _SettingsSection(scheme, _profileMenuItems.sublist(4, 5)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem {
  const _SettingsItem(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

class _SettingsSection extends StatelessWidget {
  _SettingsSection(this.scheme, this.items);
  final ColorScheme scheme;
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Material(
        color: scheme.surfaceContainer.withValues(alpha: 0.72),
        child: Column(children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 68, endIndent: 16, color: scheme.outlineVariant.withValues(alpha: 0.16)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                  child: Icon(items[i].icon, size: 20, color: scheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[i].title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(items[i].subtitle, style: TextStyle(fontSize: 13, height: 1.3, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: scheme.onSurfaceVariant),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Utilities ───────────────────────────────────────────────────────────────

class _MockUser {
  const _MockUser(this.name, this.color);
  final String name;
  final Color color;
}
