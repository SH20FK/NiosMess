import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) => Icon(
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
  final _title = TextEditingController();
  final _explanation = TextEditingController();
  final _items = [TextEditingController(), TextEditingController()];
  final _removed = <TextEditingController>[];
  bool _multiple = false;
  int _correct = 0;
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
    final preview = '$_label: $title\n${items.map((s) => '— $s').join('\n')}';
    final result = InteractiveMessage.encode({
      'kind': widget.kind,
      'document': const Uuid().v4(),
      'title': title,
      'items': items,
      'multiple': !_quiz && !_list && _multiple,
      if (_quiz) 'correct': _correct,
      if (_quiz) 'explanation': _explanation.text.trim(),
    }, preview);
    Navigator.pop(context, result);
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
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
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
                        maxLength: 180,
                        decoration: InputDecoration(
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
                                child: TextFormField(
                                  key: ObjectKey(_items[i]),
                                  controller: _items[i],
                                  maxLength: 100,
                                  decoration: InputDecoration(
                                    labelText: _list
                                        ? context.l10n.interactiveItemNumber(
                                            i + 1,
                                          )
                                        : context.l10n.interactiveOptionNumber(
                                            i + 1,
                                          ),
                                    counterText: _list ? null : '',
                                  ),
                                  validator: (v) => (v ?? '').trim().isEmpty
                                      ? context.l10n.interactiveFieldRequired
                                      : null,
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
                            onPressed: () => setState(
                              () => _items.add(TextEditingController()),
                            ),
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
                      if (_quiz) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _explanation,
                          maxLength: 500,
                          maxLines: 3,
                          decoration: InputDecoration(
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
