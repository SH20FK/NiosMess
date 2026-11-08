import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/models/interactive_message.dart';
import 'package:uuid/uuid.dart';

class InteractiveIcon extends StatelessWidget {
  const InteractiveIcon(this.kind, {super.key, this.color, this.size = 20});
  final String kind;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) => kind == 'assign'
      ? SvgPicture.string(
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="8" r="3"/><path d="M5 20a7 7 0 0 1 14 0"/></svg>',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(
            color ??
                IconTheme.of(context).color ??
                Theme.of(context).colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        )
      : Icon(
          switch (kind) {
            'poll' => Icons.poll_rounded,
            'quiz' => Icons.quiz_rounded,
            'list' => Icons.checklist_rounded,
            'answer' => Icons.radio_button_unchecked_rounded,
            'selected' => Icons.check_circle_rounded,
            'check' => Icons.check_rounded,
            'incorrect' || 'close' => Icons.close_rounded,
            'unchecked' => Icons.check_box_outline_blank_rounded,
            'checked' => Icons.check_box_rounded,
            'remove' => Icons.close_rounded,
            _ => Icons.add_rounded,
          },
          size: size,
          color: color,
        );
}

Future<String?> showInteractiveComposer(BuildContext context, String kind) =>
    AppModal.showSheet<String>(
      context: context,
      maxWidth: 580,
      builder: (_) => _InteractiveComposer(kind: kind),
    );

class _InteractiveComposer extends StatefulWidget {
  const _InteractiveComposer({required this.kind});
  final String kind;
  @override
  State<_InteractiveComposer> createState() => _InteractiveComposerState();
}

class _InteractiveComposerState extends State<_InteractiveComposer> {
  final _form = GlobalKey<FormState>();
  final _titleFocus = FocusNode();
  Animation<double>? _entrance;
  bool _focusScheduled = false;
  final _title = CustomEmojiTextController();
  final _explanation = CustomEmojiTextController();
  final _items = [CustomEmojiTextController(), CustomEmojiTextController()];
  final _repeats = <int>[0, 0];
  final _removed = <TextEditingController>[];
  bool _multiple = false;
  int _correct = 0;
  int _duration = 0;
  DateTime? _customClose;
  String? _error;

  bool get _list => widget.kind == 'list';
  bool get _quiz => widget.kind == 'quiz';
  String get _label => _list
      ? context.l10n.interactiveList
      : _quiz
      ? context.l10n.interactiveQuiz
      : context.l10n.interactivePoll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusScheduled) return;
    _focusScheduled = true;
    _entrance = ModalRoute.of(context)?.animation;
    if (_entrance == null || _entrance!.status == AnimationStatus.completed) {
      _requestTitleFocus();
    } else {
      _entrance!.addStatusListener(_onEntranceStatus);
    }
  }

  void _onEntranceStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _entrance?.removeStatusListener(_onEntranceStatus);
    _requestTitleFocus();
  }

  void _requestTitleFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _titleFocus.canRequestFocus) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _entrance?.removeStatusListener(_onEntranceStatus);
    _titleFocus.dispose();
    for (final c in [_title, _explanation, ..._items, ..._removed]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onReorder(int oldIndex, int newIndex) {
    HapticService.selection();
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      final repeat = _repeats.removeAt(oldIndex);
      _repeats.insert(newIndex, repeat);
      if (_correct == oldIndex) {
        _correct = newIndex;
      } else if (oldIndex < _correct && newIndex >= _correct) {
        _correct -= 1;
      } else if (oldIndex > _correct && newIndex <= _correct) {
        _correct += 1;
      }
    });
  }

  void _submit() {
    HapticService.tap();
    if (!_form.currentState!.validate()) return;
    final items = _items.map((c) => c.text.trim()).toList();
    if (items.toSet().length != items.length) {
      setState(() => _error = context.l10n.interactiveDuplicateOptions);
      return;
    }
    final title = _title.text.trim();
    final closesAt = _duration == -1
        ? _customClose
        : _duration > 0
        ? DateTime.now().add(Duration(seconds: _duration))
        : null;
    if (closesAt != null && !closesAt.isAfter(DateTime.now())) {
      setState(() => _error = 'Выберите будущее время завершения');
      return;
    }
    final preview = '$_label: $title\n${items.map((s) => '— $s').join('\n')}';
    final result = InteractiveMessage.encode({
      'kind': widget.kind,
      'document': const Uuid().v4(),
      'title': title,
      'items': items,
      'multiple': !_quiz && !_list && _multiple,
      if (_list && _repeats.any((seconds) => seconds > 0))
        'repeat_seconds': List<int>.of(_repeats),
      if (closesAt != null)
        'closes_at': closesAt.toUtc().millisecondsSinceEpoch,
      if (_quiz) 'correct': _correct,
      if (_quiz) 'explanation': _explanation.text.trim(),
    }, preview);
    Navigator.pop(context, result);
  }

  Future<void> _selectDuration(int value) async {
    HapticService.selection();
    if (value != -1) {
      setState(() {
        _duration = value;
        _customClose = null;
        _error = null;
      });
      return;
    }
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final chosen = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    if (!chosen.isAfter(DateTime.now())) {
      setState(() => _error = 'Выберите будущее время завершения');
      return;
    }
    setState(() {
      _duration = -1;
      _customClose = chosen;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: InteractiveIcon(
                        widget.kind,
                        size: 20,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _label,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Question Card ─────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: TextFormField(
                          controller: _title,
                          focusNode: _titleFocus,
                          inputFormatters: [CustomEmojiLengthFormatter(180)],
                          style: theme.textTheme.titleMedium,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            suffixIcon: CustomEmojiComposerButton(controller: _title),
                            hintText: _list
                                ? context.l10n.interactiveTitleField
                                : context.l10n.interactiveQuestion,
                            counterText: '',
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? (_list
                                  ? context.l10n.interactiveTitleRequired
                                  : context.l10n.interactiveQuestionRequired)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Options Section Header ────────────────────────────
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _quiz
                                ? context.l10n.interactiveQuizOptions
                                : context.l10n.interactiveOptions,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_items.length}/${_list ? 20 : 10}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ── Reorderable Options List ──────────────────────────
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _items.length,
                        // ignore: deprecated_member_use
                        onReorder: _onReorder,
                        itemBuilder: (context, i) {
                          final isCorrectAnswer = _quiz && _correct == i;
                          return Container(
                            key: ObjectKey(_items[i]),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCorrectAnswer
                                  ? scheme.primaryContainer.withValues(alpha: 0.25)
                                  : scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCorrectAnswer
                                    ? scheme.primary.withValues(alpha: 0.5)
                                    : scheme.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_quiz)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                                    tooltip: 'Правильный ответ ${i + 1}',
                                    onPressed: () {
                                      HapticService.selection();
                                      setState(() => _correct = i);
                                    },
                                    icon: Icon(
                                      isCorrectAnswer
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      color: isCorrectAnswer
                                          ? scheme.primary
                                          : scheme.outline,
                                      size: 20,
                                    ),
                                  ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: _items[i],
                                        inputFormatters: [CustomEmojiLengthFormatter(100)],
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                          suffixIcon: CustomEmojiComposerButton(controller: _items[i]),
                                          hintText: _list
                                              ? context.l10n.interactiveItemNumber(i + 1)
                                              : context.l10n.interactiveOptionNumber(i + 1),
                                          counterText: '',
                                        ),
                                        validator: (v) => (v ?? '').trim().isEmpty
                                            ? context.l10n.interactiveFieldRequired
                                            : null,
                                      ),
                                      if (_list)
                                        DropdownButton<int>(
                                          value: _repeats[i],
                                          isExpanded: true,
                                          isDense: true,
                                          underline: const SizedBox.shrink(),
                                          items: const [
                                            DropdownMenuItem(value: 0, child: Text('Не повторять', maxLines: 1, overflow: TextOverflow.ellipsis)),
                                            DropdownMenuItem(value: 86400, child: Text('Каждый день', maxLines: 1, overflow: TextOverflow.ellipsis)),
                                            DropdownMenuItem(value: 604800, child: Text('Каждую неделю', maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() => _repeats[i] = value);
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                                  tooltip: _list
                                      ? context.l10n.interactiveRemoveItem
                                      : context.l10n.interactiveRemoveOption,
                                  onPressed: _items.length <= (_list ? 1 : 2)
                                      ? null
                                      : () => setState(() {
                                          HapticService.destructive();
                                          _removed.add(_items.removeAt(i));
                                          _repeats.removeAt(i);
                                          if (_correct == i) {
                                            _correct = 0;
                                          } else if (_correct > i) {
                                            _correct--;
                                          }
                                        }),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                ),
                                ReorderableDragStartListener(
                                  index: i,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      if (_items.length < (_list ? 20 : 10))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: () {
                              HapticService.tap();
                              setState(() {
                                _items.add(CustomEmojiTextController());
                                _repeats.add(0);
                              });
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              _list
                                  ? context.l10n.interactiveAddItem
                                  : context.l10n.interactiveAddOption,
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),

                      // ── Settings Card ─────────────────────────────────────
                      if (!_list) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Настройки голосования',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                if (!_quiz) ...[
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(context.l10n.interactiveMultiple),
                                    value: _multiple,
                                    onChanged: (v) {
                                      HapticService.selection();
                                      setState(() => _multiple = v);
                                    },
                                  ),
                                  const Divider(height: 16),
                                ],

                                Text(
                                  'Срок голосования',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Wrap with ChoiceChips for 0-overflow adaptive sizing at large text scale
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Всегда'),
                                      selected: _duration == 0,
                                      onSelected: (_) => _selectDuration(0),
                                    ),
                                    ChoiceChip(
                                      label: const Text('1 час'),
                                      selected: _duration == 3600,
                                      onSelected: (_) => _selectDuration(3600),
                                    ),
                                    ChoiceChip(
                                      label: const Text('24 часа'),
                                      selected: _duration == 86400,
                                      onSelected: (_) => _selectDuration(86400),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Своё время'),
                                      selected: _duration == -1,
                                      onSelected: (_) => _selectDuration(-1),
                                    ),
                                  ],
                                ),

                                if (_duration == -1 && _customClose != null) ...[
                                  const SizedBox(height: 8),
                                  InputChip(
                                    avatar: const Icon(Icons.event_rounded, size: 16),
                                    label: Text(
                                      'До ${_customClose!.day.toString().padLeft(2, '0')}.${_customClose!.month.toString().padLeft(2, '0')}.${_customClose!.year} ${_customClose!.hour.toString().padLeft(2, '0')}:${_customClose!.minute.toString().padLeft(2, '0')}',
                                    ),
                                    onDeleted: () {
                                      setState(() {
                                        _duration = 0;
                                        _customClose = null;
                                      });
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Quiz Explanation ──────────────────────────────────
                      if (_quiz) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Icon(Icons.lightbulb_outline_rounded, size: 18, color: scheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.l10n.interactiveExplanation,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _explanation,
                                inputFormatters: [CustomEmojiLengthFormatter(500)],
                                maxLines: 2,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  suffixIcon: CustomEmojiComposerButton(controller: _explanation),
                                  hintText: context.l10n.interactiveExplanationHint,
                                  counterText: '',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Error Banner ──────────────────────────────────────
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: scheme.onErrorContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Bottom Action Button ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      context.l10n.interactiveSend,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
