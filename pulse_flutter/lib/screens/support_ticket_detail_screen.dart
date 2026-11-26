import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/support_ticket_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/support_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class SupportTicketDetailScreen extends ConsumerStatefulWidget {
  const SupportTicketDetailScreen({required this.ticketId, super.key});

  final int ticketId;

  @override
  ConsumerState<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState
    extends ConsumerState<SupportTicketDetailScreen> {
  final TextEditingController _composerCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _loading = true;
  bool _sending = false;
  bool _closing = false;
  String? _error;
  SupportTicket? _ticket;
  StreamSubscription<Map<String, dynamic>>? _pushSub;

  @override
  void initState() {
    super.initState();
    _pushSub = ref.read(webSocketClientProvider).pushStream.listen((event) {
      final act = event['action'] ?? event['event'];
      if (act == 'support_ticket_updated') {
        final payload = event['payload'];
        if (payload is Map &&
            ((payload['id'] as num?)?.toInt() == widget.ticketId)) {
          unawaited(_loadTicket(silent: true));
        }
      }
    });
    unawaited(_loadTicket());
  }

  @override
  void dispose() {
    unawaited(_pushSub?.cancel());
    _composerCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTicket({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final t =
          await ref.read(supportRepositoryProvider).getTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = t;
        _loading = false;
        _error = t == null ? 'Тикет не найден' : null;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        unawaited(
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  Future<void> _sendReply() async {
    final text = _composerCtrl.text.trim();
    if (text.isEmpty || _sending || (_ticket?.isClosed ?? false)) return;
    HapticService.confirm();
    setState(() => _sending = true);
    try {
      final updated = await ref
          .read(supportRepositoryProvider)
          .replyTicket(widget.ticketId, text);
      if (!mounted) return;
      _composerCtrl.clear();
      setState(() {
        _sending = false;
        if (updated != null) _ticket = updated;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.showError(context, e);
    }
  }

  Future<void> _confirmClose() async {
    if (_closing || _ticket == null || _ticket!.isClosed) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Закрыть тикет #${_ticket!.id}?',
      subtitle: 'После закрытия в этот тикет больше нельзя будет отправлять сообщения.',
      confirmLabel: 'Закрыть',
      cancelLabel: 'Отмена',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _closing = true);
    try {
      final updated =
          await ref.read(supportRepositoryProvider).closeTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _closing = false;
        if (updated != null) _ticket = updated;
      });
      AppToast.showSuccess(context, 'Тикет #${widget.ticketId} закрыт');
    } catch (e) {
      if (!mounted) return;
      setState(() => _closing = false);
      AppToast.showError(context, e);
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final l = dt.toLocal();
    final d = l.day.toString().padLeft(2, '0');
    final m = l.month.toString().padLeft(2, '0');
    final h = l.hour.toString().padLeft(2, '0');
    final min = l.minute.toString().padLeft(2, '0');
    return '$d.$m $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ticket = _ticket;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ticket != null ? 'Тикет #${ticket.id}' : 'Тикет #${widget.ticketId}',
        ),
        actions: [
          if (ticket != null && !ticket.isClosed)
            TextButton(
              onPressed: _closing ? null : _confirmClose,
              child: const Text('Закрыть'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : ticket == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error ?? 'Тикет недоступен'),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        border: Border(
                          bottom: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.subject,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Статус: ${ticket.isClosed ? "Закрыт" : "Открыт"} · Категория: ${ticket.category}',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: ticket.messages.length,
                        itemBuilder: (ctx, idx) {
                          final msg = ticket.messages[idx];
                          final isSupport = msg.isSupport;
                          return Align(
                            alignment: isSupport
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: const BoxConstraints(maxWidth: 420),
                              decoration: BoxDecoration(
                                color: isSupport
                                    ? scheme.surfaceContainerHighest
                                    : scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSupport ? 'Поддержка NiosMess' : 'Вы',
                                    style: textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isSupport
                                          ? scheme.primary
                                          : scheme.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg.body,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: isSupport
                                          ? scheme.onSurface
                                          : scheme.onPrimaryContainer,
                                    ),
                                  ),
                                  if (msg.createdAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(msg.createdAt),
                                      style: textTheme.labelSmall?.copyWith(
                                        fontSize: 10,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (ticket.isClosed)
                      SafeArea(
                        top: false,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.45,
                          ),
                          child: Text(
                            'Тикет закрыт. Если появился новый вопрос, создайте новое обращение.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _composerCtrl,
                                  enabled: !_sending,
                                  minLines: 1,
                                  maxLines: 4,
                                  maxLength: 4000,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => unawaited(_sendReply()),
                                  decoration: const InputDecoration(
                                    hintText: 'Дополнить обращение...',
                                    counterText: '',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed:
                                    _sending ? null : () => unawaited(_sendReply()),
                                child: const Icon(Icons.send_rounded, size: 18),
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
