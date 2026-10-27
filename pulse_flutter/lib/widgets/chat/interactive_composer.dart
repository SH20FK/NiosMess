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
            'poll' => Icons.poll_outlined,
            'quiz' => Icons.quiz_outlined,
            'list' => Icons.checklist_rounded,
            'answer' => Icons.radio_button_unchecked_rounded,
            'selected' => Icons.radio_button_checked_rounded,
            'check' => Icons.check_rounded,
            'incorrect' || 'close' => Icons.close_rounded,
            'unchecked' => Icons.check_box_outline_blank_rounded,
            'checked' => Icons.check_box_rounded,
            'remove' => Icons.remove_rounded,
            _ => Icons.add_rounded,
          },
          size: size,
          color: color,
        );
}

Future<String?> showInteractiveComposer(BuildContext context, String kind) =>
    AppModal.showSheet<String>(
      context: context,
      maxWidth: 560,
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

  void _submit() {
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

  Future<void> _selectDuration(int? value) async {
    if (value == null) return;
    if (value != -1) {
      setState(() {
        _duration = value;
        _customClose = null;
      });
      return;
    }
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
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
    return Padding(
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_label, style: theme.textTheme.titleLarge),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.pop(context),
                      icon: const InteractiveIcon('close'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _title,
                        focusNode: _titleFocus,
                        inputFormatters: [CustomEmojiLengthFormatter(180)],
                        decoration: InputDecoration(
                          suffixIcon: CustomEmojiComposerButton(
                            controller: _title,
                          ),
                          labelText: _list
                              ? context.l10n.interactiveTitleField
                              : context.l10n.interactiveQuestion,
                          counterText: _list ? null : '',
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? (_list
                                  ? context.l10n.interactiveTitleRequired
                                  : context.l10n.interactiveQuestionRequired)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      if (!_list)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _quiz
                                  ? context.l10n.interactiveQuizOptions
                                  : context.l10n.interactiveOptions,
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                        ),
                      for (var i = 0; i < _items.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_quiz)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: IconButton(
                                    tooltip: 'Правильный ответ ${i + 1}',
                                    isSelected: _correct == i,
                                    onPressed: () =>
                                        setState(() => _correct = i),
                                    icon: InteractiveIcon(
                                      _correct == i ? 'selected' : 'answer',
                                      color: _correct == i
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Column(
                                  children: [
                                    TextFormField(
                                      key: ObjectKey(_items[i]),
                                      controller: _items[i],
                                      inputFormatters: [
                                        CustomEmojiLengthFormatter(100),
                                      ],
                                      decoration: InputDecoration(
                                        suffixIcon: CustomEmojiComposerButton(
                                          controller: _items[i],
                                        ),
                                        labelText: _list
                                            ? context.l10n
                                                  .interactiveItemNumber(i + 1)
                                            : context.l10n
                                                  .interactiveOptionNumber(
                                                    i + 1,
                                                  ),
                                        counterText: _list ? null : '',
                                      ),
                                      validator: (v) => (v ?? '').trim().isEmpty
                                          ? context
                                                .l10n
                                                .interactiveFieldRequired
                                          : null,
                                    ),
                                    if (_list)
                                      DropdownButton<int>(
                                        value: _repeats[i],
                                        isExpanded: true,
                                        items: const [
                                          DropdownMenuItem(
                                            value: 0,
                                            child: Text('Не повторять'),
                                          ),
                                          DropdownMenuItem(
                                            value: 86400,
                                            child: Text('Каждый день'),
                                          ),
                                          DropdownMenuItem(
                                            value: 604800,
                                            child: Text('Каждую неделю'),
                                          ),
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
                                tooltip: _list
                                    ? context.l10n.interactiveRemoveItem
                                    : context.l10n.interactiveRemoveOption,
                                onPressed: _items.length <= (_list ? 1 : 2)
                                    ? null
                                    : () => setState(() {
                                        _removed.add(_items.removeAt(i));
                                        _repeats.removeAt(i);
                                        if (_correct == i) {
                                          _correct = 0;
                                        } else if (_correct > i) {
                                          _correct--;
                                        }
                                      }),
                                icon: const InteractiveIcon('remove'),
                              ),
                            ],
                          ),
                        ),
                      if (_items.length < (_list ? 20 : 10))
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              _items.add(CustomEmojiTextController());
                              _repeats.add(0);
                            }),
                            icon: const InteractiveIcon('add'),
                            label: Text(
                              _list
                                  ? context.l10n.interactiveAddItem
                                  : context.l10n.interactiveAddOption,
                            ),
                          ),
                        ),
                      if (!_list && !_quiz)
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.l10n.interactiveMultiple),
                          value: _multiple,
                          onChanged: (v) => setState(() => _multiple = v),
                        ),
                      if (!_list)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Завершить голосование'),
                            DropdownButton<int>(
                              value: _duration,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 0,
                                  child: Text('Вручную'),
                                ),
                                DropdownMenuItem(
                                  value: 3600,
                                  child: Text('Через час'),
                                ),
                                DropdownMenuItem(
                                  value: 86400,
                                  child: Text('Через день'),
                                ),
                                DropdownMenuItem(
                                  value: 604800,
                                  child: Text('Через неделю'),
                                ),
                                DropdownMenuItem(
                                  value: -1,
                                  child: Text('Выбрать дату и время'),
                                ),
                              ],
                              onChanged: _selectDuration,
                            ),
                          ],
                        ),
                      if (!_list && _customClose != null)
                        Text(
                          'До ${_customClose!.day.toString().padLeft(2, '0')}.${_customClose!.month.toString().padLeft(2, '0')}.${_customClose!.year} ${_customClose!.hour.toString().padLeft(2, '0')}:${_customClose!.minute.toString().padLeft(2, '0')}',
                        ),
                      if (_quiz) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _explanation,
                          inputFormatters: [CustomEmojiLengthFormatter(500)],
                          maxLines: 3,
                          decoration: InputDecoration(
                            suffixIcon: CustomEmojiComposerButton(
                              controller: _explanation,
                            ),
                            labelText: context.l10n.interactiveExplanation,
                            helperText: context.l10n.interactiveExplanationHint,
                            counterText: '',
                          ),
                        ),
                      ],
                      if (!_list)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            context.l10n.interactiveVotesVisible,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(context.l10n.interactiveSend),
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
