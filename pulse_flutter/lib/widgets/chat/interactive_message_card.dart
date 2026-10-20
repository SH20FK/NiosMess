import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/interactive_message.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/interactive_provider.dart';
import 'package:pulse_flutter/widgets/chat/interactive_composer.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class InteractiveMessageCard extends ConsumerStatefulWidget {
  const InteractiveMessageCard({
    required this.message,
    required this.definition,
    required this.foreground,
    super.key,
  });
  final ApiMessage message;
  final InteractiveMessage definition;
  final Color foreground;
  @override
  ConsumerState<InteractiveMessageCard> createState() =>
      _InteractiveMessageCardState();
}

class _InteractiveMessageCardState
    extends ConsumerState<InteractiveMessageCard> {
  bool _busy = false;
  Set<int>? _selection;

  @override
  void didUpdateWidget(covariant InteractiveMessageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition.fingerprint != widget.definition.fingerprint) {
      _selection = null;
    }
  }

  Future<void> _update(Map<String, dynamic> action, String description) async {
    if (_busy || widget.message.id <= 0) return;
    setState(() => _busy = true);
    final accountId = ref.read(authProvider).session?.userId ?? -1;
    try {
      final document = widget.definition;
      final content = InteractiveMessage.encode({
        'kind': 'update',
        'document': document.document,
        'definition': document.fingerprint,
        'root': widget.message.id,
        ...action,
      }, '$description: ${document.title}');
      await ref
          .read(chatMessagesProvider(widget.message.chatId).notifier)
          .sendInteractiveUpdate(
            content,
            rootId: widget.message.id,
            encryptedRoot: widget.message.isE2ee,
          );
      if (mounted) {
        _selection = null;
        ref.invalidate(
          interactiveEventsProvider((
            accountId,
            widget.message.chatId,
            widget.message.id,
          )),
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          'Не удалось сохранить. Повторите отправку.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showVoters(InteractiveState state) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Голоса', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in state.votes.entries.where(
                    (e) => e.value.isNotEmpty,
                  ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: PulseAvatar(
                        name: state.names[entry.key] ?? 'Участник',
                        avatarUrl: state.avatars[entry.key],
                        radius: 20,
                      ),
                      title: Text(
                        state.names[entry.key]?.trim().isNotEmpty == true
                            ? state.names[entry.key]!
                            : 'Участник ${entry.key}',
                      ),
                      subtitle: Text(
                        entry.value
                            .map((i) => widget.definition.items[i])
                            .join(', '),
                      ),
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final definition = widget.definition;
    final message = widget.message;
    final me = ref.watch(authProvider.select((a) => a.session?.userId ?? -1));
    final key = (me, message.chatId, message.id);
    final events = ref.watch(interactiveEventsProvider(key));
    final state = InteractiveState(
      definition,
      message.senderId,
      events.value ?? [],
      rootId: message.id,
      requireE2ee: message.isE2ee,
    );
    final ready =
        !events.isLoading &&
        !events.hasError &&
        message.id > 0 &&
        !message.isSending;
    final canAct = ready && !state.closed && !_busy;
    final mine = state.votes[me] ?? <int>{};
    final selected = _selection ?? mine;
    final quiz = definition.kind == 'quiz';
    final list = definition.kind == 'list';
    final showResults = mine.isNotEmpty || state.closed;
    final foreground = widget.foreground;
    final theme = Theme.of(context);
    final label = list
        ? 'Общий список'
        : quiz
        ? 'Викторина'
        : 'Открытый опрос';
    final localTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        onSurface: foreground,
        primary: foreground,
        onSurfaceVariant: foreground,
      ),
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: foreground),
        checkColor: WidgetStatePropertyAll(
          foreground.computeLuminance() > .5 ? Colors.black : Colors.white,
        ),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? foreground
              : Colors.transparent,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: foreground),
      ),
    );
    return Theme(
      data: localTheme,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: SizedBox(
          width: 310,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (list) ...[
                Row(
                  children: [
                    InteractiveIcon(
                      definition.kind,
                      color: foreground,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ),
                    if (state.closed)
                      Text(
                        'Завершён',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  definition.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 8),
              ] else ...[
                Text(
                  definition.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.closed
                      ? quiz
                            ? 'Викторина завершена'
                            : 'Опрос завершён'
                      : quiz
                      ? 'Викторина, один ответ'
                      : definition.multiple
                      ? 'Открытый опрос, несколько ответов'
                      : 'Открытый опрос, один ответ',
                  style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                ),
                const SizedBox(height: 12),
              ],
              for (var i = 0; i < definition.items.length; i++)
                if (list)
                  _choice(
                    label: definition.items[i],
                    selected: list
                        ? state.checked[i] == true
                        : selected.contains(i),
                    enabled: canAct && (!quiz || mine.isEmpty),
                    percentage: !list && showResults && state.voters > 0
                        ? state.count(i) / state.voters
                        : null,
                    helper: list && state.checked[i] == true
                        ? state.checkedBy[i]
                        : quiz && showResults && i == definition.correct
                        ? 'Правильный ответ'
                        : null,
                    helperAvatar: list ? state.checkedByAvatar[i] : null,
                    helperIsPerson: list && state.checked[i] == true,
                    onTap: () {
                      if (list) {
                        _update(
                          {
                            'action': 'check',
                            'item': i,
                            'checked': state.checked[i] != true,
                          },
                          state.checked[i] == true
                              ? 'Пункт снова открыт'
                              : 'Пункт выполнен',
                        );
                      } else if (quiz) {
                        _update({
                          'action': 'vote',
                          'choices': [i],
                        }, 'Ответ на викторину');
                      } else {
                        setState(() {
                          _selection = Set<int>.from(selected);
                          if (definition.multiple) {
                            if (!_selection!.add(i)) _selection!.remove(i);
                          } else {
                            _selection = {i};
                          }
                        });
                      }
                    },
                    foreground: foreground,
                  )
                else
                  _ballotChoice(
                    label: definition.items[i],
                    selected: selected.contains(i),
                    multiple: definition.multiple && !quiz,
                    enabled: canAct && (!quiz || mine.isEmpty),
                    percentage: showResults && state.voters > 0
                        ? state.count(i) / state.voters
                        : null,
                    correct: quiz && showResults && i == definition.correct,
                    wrong:
                        quiz &&
                        showResults &&
                        mine.contains(i) &&
                        i != definition.correct,
                    foreground: foreground,
                    onTap: () {
                      if (quiz) {
                        _update({
                          'action': 'vote',
                          'choices': [i],
                        }, 'Ответ на викторину');
                      } else {
                        setState(() {
                          _selection = Set<int>.from(selected);
                          if (definition.multiple) {
                            if (!_selection!.add(i)) _selection!.remove(i);
                          } else {
                            _selection = {i};
                          }
                        });
                      }
                    },
                  ),
              if (quiz && showResults && mine.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  mine.contains(definition.correct) ? 'Верно' : 'Неверно',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                  ),
                ),
                if (definition.explanation.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(definition.explanation),
                  ),
              ],
              if (!list && !quiz && !state.closed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    children: [
                      TextButton(
                        onPressed:
                            canAct && _selection != null && selected.isNotEmpty
                            ? () => _update({
                                'action': 'vote',
                                'choices': selected.toList()..sort(),
                              }, 'Голос в опросе')
                            : null,
                        child: Text(
                          mine.isEmpty ? 'Голосовать' : 'Изменить голос',
                        ),
                      ),
                      if (mine.isNotEmpty)
                        TextButton(
                          onPressed: canAct
                              ? () => _update({
                                  'action': 'vote',
                                  'choices': <int>[],
                                }, 'Голос отозван')
                              : null,
                          child: const Text('Отозвать'),
                        ),
                    ],
                  ),
                ),
              if (events.hasError)
                TextButton(
                  onPressed: () =>
                      ref.invalidate(interactiveEventsProvider(key)),
                  child: const Text('Не удалось загрузить. Повторить'),
                )
              else if (events.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Загружаю изменения…'),
                )
              else if (message.id <= 0)
                const Text('Доступно после отправки')
              else if (list)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Выполнено ${state.checked.values.where((v) => v).length} из ${definition.items.length}',
                  ),
                )
              else
                TextButton(
                  onPressed: ready && state.voters > 0
                      ? () => _showVoters(state)
                      : null,
                  child: Text('Проголосовали: ${state.voters}'),
                ),
              if (me == message.senderId && !state.closed && ready)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: canAct
                        ? () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(
                                  list
                                      ? 'Завершить список?'
                                      : 'Завершить голосование?',
                                ),
                                content: const Text(
                                  'После этого участники не смогут менять ответы.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Отмена'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Завершить'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && mounted) {
                              await _update({'action': 'close'}, 'Завершено');
                            }
                          }
                        : null,
                    child: const Text('Завершить'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ballotChoice({
    required String label,
    required bool selected,
    required bool multiple,
    required bool enabled,
    required bool correct,
    required bool wrong,
    required VoidCallback onTap,
    required Color foreground,
    double? percentage,
  }) {
    final results = percentage != null;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final icon = correct
        ? 'check'
        : wrong
        ? 'incorrect'
        : multiple
        ? selected
              ? 'checked'
              : 'unchecked'
        : selected
        ? 'selected'
        : 'answer';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(6),
          child: Semantics(
            selected: selected,
            enabled: enabled,
            button: true,
            label: [
              label,
              if (correct) 'Правильный ответ',
              if (wrong) 'Ваш ответ, неверно',
            ].join(', '),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: InteractiveIcon(
                          icon,
                          size: 20,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                color: foreground,
                                fontWeight: selected || correct
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            if (correct || wrong) ...[
                              const SizedBox(height: 2),
                              Text(
                                correct ? 'Правильный ответ' : 'Ваш ответ',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: foreground),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (results) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${(percentage * 100).round()}%',
                          style: TextStyle(
                            color: foreground,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (results)
                    Padding(
                      padding: const EdgeInsets.only(left: 32, top: 8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: percentage, end: percentage),
                        duration: duration,
                        builder: (_, value, _) => SizedBox(
                          height: 4,
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: foreground.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: value.clamp(0, 1),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: foreground,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice({
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
    required Color foreground,
    double? percentage,
    String? helper,
    String? helperAvatar,
    bool helperIsPerson = false,
  }) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Semantics(
            selected: selected,
            enabled: enabled,
            button: true,
            label: label,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IgnorePointer(
                        child: Checkbox(value: selected, onChanged: (_) {}),
                      ),
                      Expanded(child: Text(label)),
                      if (percentage != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('${(percentage * 100).round()}%'),
                        ),
                    ],
                  ),
                  if (helper != null && helper.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: helperIsPerson
                          ? Row(
                              children: [
                                PulseAvatar(
                                  name: helper,
                                  avatarUrl: helperAvatar,
                                  radius: 10,
                                ),
                                const SizedBox(width: 6),
                                Expanded(child: Text(helper)),
                              ],
                            )
                          : Text(helper),
                    ),
                  if (percentage != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: percentage),
                        duration: duration,
                        builder: (_, value, _) => AppLoadingIndicator(
                          value: value,
                          minHeight: 3,
                          color: foreground,
                          backgroundColor: foreground.withValues(alpha: .15),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
