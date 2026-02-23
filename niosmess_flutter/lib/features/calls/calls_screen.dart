import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/api_repository.dart';
import '../../ui/nios_ui.dart';
import '../../core/session_provider.dart';
import '../../core/settings_provider.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';

class CallsScreen extends ConsumerStatefulWidget {
  final void Function(String chatId)? onSelectChat;

  const CallsScreen({super.key, this.onSelectChat});

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> with AutomaticKeepAliveClientMixin {
  final api = ApiRepository();
  bool loading = true;
  List<Map<String, dynamic>> logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) {
      if (mounted) {
        setState(() => loading = false);
      }
      return;
    }
    if (mounted) {
      setState(() => loading = true);
    }
    try {
      final data = await api.getCallLogs(session.username!, session.token!);
      if (!mounted) return;
      setState(() {
        logs = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String _formatTime(dynamic raw) {
    final value = double.tryParse(raw?.toString() ?? '');
    if (value == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _openChat(String username) {
    if (widget.onSelectChat != null) {
      widget.onSelectChat!(username);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: username,
          chatUsername: username,
          chatType: 'user',
          title: username,
          status: '',
          onBack: () => Navigator.of(context).pop(),
          onOpenProfile: (u) => _openProfile(u),
        ),
      ),
    );
  }

  void _openProfile(String username) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          targetUsername: username,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final session = ref.watch(sessionProvider);
    final reduceMotion = (ref.watch(settingsProvider)['reduce_motion'] as bool?) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Звонки'),
        bottom: loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !session.isAuthed
          ? const Center(child: Text('Войдите в аккаунт'))
          : logs.isEmpty
              ? Center(
                  child: NiosMotionWrap(
                    enableMotion: !reduceMotion,
                    blurSigma: 10,
                    offset: const Offset(0, 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        const Text('Нет звонков'),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      cacheExtent: 1200,
                      physics: const BouncingScrollPhysics(),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 72,
                        endIndent: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withOpacity(0.4),
                      ),
                      itemBuilder: (_, i) {
                        final item = logs[i];
                        final caller = item['caller']?.toString() ?? '';
                        final callee = item['callee']?.toString() ?? '';
                        final isOutgoing = caller == session.username;
                        final other = isOutgoing ? callee : caller;
                        final status = item['status']?.toString() ?? 'requested';
                        final time = _formatTime(item['started_at']);
                        final directionLabel = isOutgoing ? 'Исходящий' : 'Входящий';
                        final statusLabel = switch (status) {
                          'accepted' => 'Принято',
                          'declined' => 'Отклонено',
                          'ended' => 'Завершено',
                          'missed' => 'Пропущено',
                          _ => 'В ожидании',
                        };
                        final icon = isOutgoing ? Icons.call_made : Icons.call_received;

                        return NiosMotionWrap(
                          enableMotion: !reduceMotion,
                          delay: Duration(milliseconds: 25 * i),
                          blurSigma: 8,
                          offset: const Offset(0, 12),
                          child: RepaintBoundary(
                            child: ListTile(
                              leading: Icon(icon),
                              title: Text(other.isEmpty ? 'Неизвестно' : other),
                              subtitle: Text('$directionLabel · $statusLabel'),
                              trailing: Text(time),
                              onTap: () => _openChat(other),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
