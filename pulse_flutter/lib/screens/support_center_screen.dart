import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/support_ticket_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/repositories/support_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class SupportCenterScreen extends ConsumerStatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  ConsumerState<SupportCenterScreen> createState() =>
      _SupportCenterScreenState();
}

class _SupportCenterScreenState extends ConsumerState<SupportCenterScreen> {
  bool _loading = true;
  String? _error;
  SpamBlockStatus? _spamBlock;
  List<SupportTicket> _tickets = const <SupportTicket>[];
  String _statusFilter = 'all'; // 'all' | 'open' | 'closed'
  StreamSubscription<Map<String, dynamic>>? _pushSub;

  @override
  void initState() {
    super.initState();
    _pushSub = ref.read(webSocketClientProvider).pushStream.listen((event) {
      final act = event['action'] ?? event['event'];
      if (act == 'support_ticket_updated' || act == 'spam_block_changed') {
        unawaited(_loadData(silent: true));
      }
    });
    unawaited(_loadData());
  }

  @override
  void dispose() {
    unawaited(_pushSub?.cancel());
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repo = ref.read(supportRepositoryProvider);
      final bundle = await repo.listTicketsWithStatus();
      SpamBlockStatus? sb = bundle.spamBlock;
      if (sb == null) {
        final overview = await repo.getStatus();
        sb = overview.spamBlock;
      }
      if (!mounted) return;
      setState(() {
        _tickets = bundle.tickets;
        _spamBlock = sb;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d.$m.${local.year} $h:$min';
  }

  Future<void> _openAppealDialog() async {
    HapticService.tap();
    final explanationCtrl = TextEditingController();
    bool submitting = false;

    await showAppDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Апелляция спам-блока',
          icon: Icons.gavel_rounded,
          actions: [
            AppDialogAction(
              label: 'Отмена',
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
            ),
            AppDialogAction(
              label: 'Отправить',
              isPrimary: true,
              isLoading: submitting,
              onPressed: submitting
                  ? null
                  : () async {
                      final text = explanationCtrl.text.trim();
                      if (text.length < 10) {
                        AppToast.showError(
                          ctx,
                          'Опишите ситуацию подробнее (минимум 10 символов)',
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        final ticket = await ref
                            .read(supportRepositoryProvider)
                            .submitSpamAppeal(text);
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        await _loadData(silent: true);
                        if (ticket != null && ticket.id > 0 && mounted) {
                          AppToast.showSuccess(
                            context,
                            'Апелляция отправлена (#${ticket.id})',
                          );
                          await context.push('/support/${ticket.id}');
                          await _loadData(silent: true);
                        }
                      } catch (e) {
                        if (!ctx.mounted) return;
                        setDialogState(() => submitting = false);
                        AppToast.showError(ctx, e);
                      }
                    },
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Расскажите модераторам, почему ограничение было наложено ошибочно или что вы уже исправили.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: explanationCtrl,
                enabled: !submitting,
                minLines: 4,
                maxLines: 7,
                maxLength: 3000,
                decoration: const InputDecoration(
                  labelText: 'Пояснение к апелляции',
                  hintText: 'Минимум 10 символов...',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    explanationCtrl.dispose();
  }

  Future<void> _openNewTicketDialog() async {
    HapticService.tap();
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String category = 'general';
    bool submitting = false;

    const categories = <(String, String)>[
      ('general', 'Общий вопрос'),
      ('bug', 'Ошибка / баг'),
      ('privacy', 'Приватность / безопасность'),
      ('copyright', 'Авторские права'),
      ('abuse', 'Жалоба / злоупотребление'),
    ];

    await showAppDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Новое обращение',
          icon: Icons.support_agent_rounded,
          actions: [
            AppDialogAction(
              label: 'Отмена',
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
            ),
            AppDialogAction(
              label: 'Создать',
              isPrimary: true,
              isLoading: submitting,
              onPressed: submitting
                  ? null
                  : () async {
                      final subj = subjectCtrl.text.trim();
                      final body = bodyCtrl.text.trim();
                      if (subj.isEmpty || body.isEmpty) {
                        AppToast.showError(
                          ctx,
                          'Заполните тему и сообщение',
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        final ticket = await ref
                            .read(supportRepositoryProvider)
                            .createSupportRequest(
                              ticketType:
                                  category == 'copyright' ? 'copyright' : 'support',
                              category: category,
                              subject: subj,
                              body: body,
                            );
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        await _loadData(silent: true);
                        if (ticket != null && ticket.id > 0 && mounted) {
                          AppToast.showSuccess(
                            context,
                            'Тикет #${ticket.id} создан',
                          );
                          await context.push('/support/${ticket.id}');
                          await _loadData(silent: true);
                        }
                      } catch (e) {
                        if (!ctx.mounted) return;
                        setDialogState(() => submitting = false);
                        AppToast.showError(ctx, e);
                      }
                    },
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: categories.map((entry) {
                  return ChoiceChip(
                    label: Text(entry.$2),
                    selected: category == entry.$1,
                    onSelected: submitting
                        ? null
                        : (_) => setDialogState(() => category = entry.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: subjectCtrl,
                enabled: !submitting,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Тема'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: bodyCtrl,
                enabled: !submitting,
                minLines: 3,
                maxLines: 6,
                maxLength: 4000,
                decoration: const InputDecoration(labelText: 'Подробности'),
              ),
            ],
          ),
        ),
      ),
    );
    subjectCtrl.dispose();
    bodyCtrl.dispose();
  }

  List<SupportTicket> get _filteredTickets {
    if (_statusFilter == 'open') {
      return _tickets.where((t) => !t.isClosed).toList(growable: false);
    }
    if (_statusFilter == 'closed') {
      return _tickets.where((t) => t.isClosed).toList(growable: false);
    }
    return _tickets;
  }

  String _categoryLabel(SupportTicket t) {
    if (t.isSpamAppeal) return 'Апелляция';
    return switch (t.category) {
      'bug' => 'Баг',
      'privacy' => 'Приватность',
      'copyright' => 'Авторское право',
      'abuse' => 'Нарушение',
      'account' => 'Аккаунт',
      _ => 'Поддержка',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profile = ref.watch(authProvider).profile;
    final bool effectiveBlocked =
        _spamBlock?.isBlocked ?? (profile?.isRestrictedBySpamBlock ?? false);
    final DateTime? effectiveUntil =
        _spamBlock?.blockedUntil ?? profile?.spamBlockUntil;
    final String? effectiveReason =
        _spamBlock?.reason ?? profile?.spamBlockReason;
    final int? appealTicketId = _spamBlock?.appealTicketId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поддержка и Спам-Блок'),
        actions: [
          IconButton(
            tooltip: 'Чат с @Support',
            icon: const Icon(Icons.chat_outlined),
            onPressed: () => context.push('/chat/direct/support'),
          ),
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => unawaited(_loadData()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewTicketDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Новый тикет'),
      ),
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadData(silent: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  _buildSpamBlockCard(
                    context,
                    scheme,
                    textTheme,
                    isBlocked: effectiveBlocked,
                    until: effectiveUntil,
                    reason: effectiveReason,
                    appealTicketId: appealTicketId,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Мои обращения (${_tickets.length})',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/chat/direct/support'),
                        icon: const Icon(Icons.smart_toy_outlined, size: 18),
                        label: const Text('@Support'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Все'),
                        selected: _statusFilter == 'all',
                        onSelected: (_) => setState(() => _statusFilter = 'all'),
                      ),
                      FilterChip(
                        label: const Text('Открытые'),
                        selected: _statusFilter == 'open',
                        onSelected: (_) =>
                            setState(() => _statusFilter = 'open'),
                      ),
                      FilterChip(
                        label: const Text('Закрытые'),
                        selected: _statusFilter == 'closed',
                        onSelected: (_) =>
                            setState(() => _statusFilter = 'closed'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Не удалось загрузить тикеты: $_error',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    )
                  else if (_filteredTickets.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.mark_chat_read_outlined,
                            size: 36,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Обращений пока нет',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Нажмите «Новый тикет» или напишите боту @Support — все сообщения соберутся в один удобный тред.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._filteredTickets.map(
                      (ticket) => _buildTicketTile(
                        context,
                        scheme,
                        textTheme,
                        ticket,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSpamBlockCard(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme, {
    required bool isBlocked,
    required DateTime? until,
    required String? reason,
    required int? appealTicketId,
  }) {
    final bgColor = isBlocked
        ? scheme.errorContainer.withValues(alpha: 0.55)
        : scheme.primaryContainer.withValues(alpha: 0.35);
    final borderColor = isBlocked
        ? scheme.error.withValues(alpha: 0.35)
        : scheme.primary.withValues(alpha: 0.25);
    final icon = isBlocked ? Icons.gpp_maybe_rounded : Icons.verified_user_rounded;
    final iconColor = isBlocked ? scheme.error : scheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isBlocked
                      ? 'На аккаунте действует Спам-Блок'
                      : 'Статус аккаунта: без ограничений',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isBlocked)
            Text(
              'Свободный доступ к публичным группам, каналам, NiosGram и личным сообщениям соблюдается.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else ...[
            Text(
              'Причина: ${reason ?? "Нарушение правил NiosMess"}',
              style: textTheme.bodyMedium,
            ),
            if (until != null) ...[
              const SizedBox(height: 4),
              Text(
                'Окончание: ${_formatDate(until)} (автоматически снимается по истечении)',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Связь с @Support и тикеты поддержки остаются полностью доступными.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (appealTicketId != null)
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await context.push('/support/$appealTicketId');
                      await _loadData(silent: true);
                    },
                    icon: const Icon(Icons.forum_outlined, size: 18),
                    label: Text('Открыть апелляцию #$appealTicketId'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _openAppealDialog,
                    icon: const Icon(Icons.gavel_rounded, size: 18),
                    label: const Text('Подать апелляцию'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTicketTile(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    SupportTicket ticket,
  ) {
    final preview = (ticket.lastPreview?.trim().isNotEmpty == true)
        ? ticket.lastPreview!.trim()
        : ticket.body.trim();
    final timeStr = _formatDate(
      ticket.lastMessageAt ?? ticket.updatedAt ?? ticket.createdAt,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          HapticService.tap();
          await context.push('/support/${ticket.id}');
          await _loadData(silent: true);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: ticket.unreadByUser > 0
                  ? scheme.primary.withValues(alpha: 0.45)
                  : scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ticket.isSpamAppeal
                          ? scheme.errorContainer
                          : scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${ticket.id} · ${_categoryLabel(ticket)}',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ticket.isSpamAppeal
                            ? scheme.onErrorContainer
                            : scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ticket.isClosed
                          ? scheme.surfaceContainerHighest
                          : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ticket.isClosed ? 'Закрыт' : 'Открыт',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ticket.isClosed
                            ? scheme.onSurfaceVariant
                            : scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (ticket.unreadByUser > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+${ticket.unreadByUser}',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ticket.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.message_outlined,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${ticket.messageCount}',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (timeStr.isNotEmpty)
                    Text(
                      timeStr,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
