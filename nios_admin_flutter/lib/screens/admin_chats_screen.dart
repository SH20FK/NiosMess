import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nios_admin_flutter/core/localization/l10n.dart';
import 'package:nios_admin_flutter/core/network/api_exception.dart';
import 'package:nios_admin_flutter/models/admin_chat.dart';
import 'package:nios_admin_flutter/providers/admin_session_provider.dart';
import 'package:nios_admin_flutter/widgets/admin_panel.dart';

class AdminChatsScreen extends ConsumerStatefulWidget {
  const AdminChatsScreen({super.key});

  @override
  ConsumerState<AdminChatsScreen> createState() => _AdminChatsScreenState();
}

class _AdminChatsScreenState extends ConsumerState<AdminChatsScreen> {
  int _page = 1;
  String _query = '';
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<AdminChat> _chats = const <AdminChat>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chats = await ref
          .read(adminRepositoryProvider)
          .getChats(page: _page);
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : '$error';
      });
    }
  }

  List<AdminChat> get _filtered {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return _chats;
    return _chats
        .where((AdminChat chat) {
          final String hay = '${chat.name} ${chat.username ?? ''}'
              .toLowerCase();
          return hay.contains(q);
        })
        .toList(growable: false);
  }

  Future<void> _toggleBan(AdminChat chat) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setChatBanned(chatId: chat.id, banned: !chat.isBanned);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.moderationSuccess)));
    } catch (error) {
      if (!mounted) return;
      final String message = error is ApiException ? error.message : '$error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(context.l10n.retry)),
          ],
        ),
      );
    }

    final List<AdminChat> chats = _filtered;

    return ListView(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(context.l10n.chatsTitle, style: textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.chatsSubtitle,
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdminPanel(
          child: Column(
            children: <Widget>[
              TextField(
                onChanged: (String value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: context.l10n.chatsSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Text(context.l10n.usersPage(_page)),
                  const Spacer(),
                  IconButton(
                    onPressed: _page <= 1
                        ? null
                        : () {
                            setState(() => _page -= 1);
                            _load();
                          },
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    onPressed: _chats.length < 25
                        ? null
                        : () {
                            setState(() => _page += 1);
                            _load();
                          },
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (chats.isEmpty)
          AdminPanel(child: Text(context.l10n.chatsNoResults))
        else
          ...chats.map((AdminChat chat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AdminPanel(
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        chat.chatType == 'channel'
                            ? Icons.campaign_rounded
                            : Icons.group_rounded,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  chat.name,
                                  style: textTheme.titleLarge,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'dd.MM.yyyy',
                                ).format(chat.createdAt.toLocal()),
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${chat.username ?? '-'} • ${chat.chatType}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${context.l10n.membersCount}: ${chat.membersCount}',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : () => _toggleBan(chat),
                      icon: Icon(
                        chat.isBanned
                            ? Icons.lock_open_rounded
                            : Icons.block_rounded,
                      ),
                      label: Text(
                        chat.isBanned
                            ? context.l10n.chatsUnban
                            : context.l10n.chatsBan,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
