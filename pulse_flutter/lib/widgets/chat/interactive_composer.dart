import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/models/interactive_message.dart';
import 'package:uuid/uuid.dart';

class InteractiveIcon extends StatelessWidget {
  const InteractiveIcon(this.kind, {super.key, this.color, this.size = 20});
  final String kind;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'
    '${switch (kind) {
      'poll' => '<path d="M5 20V10h4v10M10 20V4h4v16M15 20v-7h4v7M3 20h18"/>',
      'quiz' => '<path d="M9 8a3 3 0 0 1 6 0c0 2-3 2-3 4m0 4h.01"/><rect x="3" y="2" width="18" height="20" rx="3"/>',
      'list' => '<path d="m3 6 2 2 3-4m3 2h10M3 13h4m4 0h10M3 20h4m4 0h10"/>',
      'answer' => '<circle cx="12" cy="12" r="8"/>',
      'selected' => '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4" fill="currentColor" stroke="none"/>',
      'check' => '<path d="m5 12 4 4L19 6"/>',
      'incorrect' => '<path d="m6 6 12 12M6 18 18 6"/>',
      'unchecked' => '<rect x="4" y="4" width="16" height="16" rx="3"/>',
      'checked' => '<rect x="4" y="4" width="16" height="16" rx="3"/><path d="m8 12 3 3 5-6"/>',
      'close' => '<path d="m6 6 12 12M6 18 18 6"/>',
      'remove' => '<path d="M5 12h14"/>',
      _ => '<path d="M12 5v14M5 12h14"/>',
    }}</svg>',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      color ??
          IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurface,
      BlendMode.srcIn,
    ),
  );
}

Future<String?> showInteractiveComposer(BuildContext context, String kind) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
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
      ? 'Общий список'
      : _quiz
      ? 'Викторина'
      : 'Опрос';

  @override
  void dispose() {
    for (final c in [_title, _explanation, ..._items, ..._removed]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final items = _items.map((c) => c.text.trim()).toList();
    if (items.toSet().length != items.length) {
      setState(() => _error = 'Варианты не должны повторяться');
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
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                      tooltip: 'Закрыть',
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
                        autofocus: true,
                        maxLength: 180,
                        decoration: InputDecoration(
                          labelText: _list ? 'Название' : 'Вопрос',
                          counterText: _list ? null : '',
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Введите ${_list ? 'название' : 'вопрос'}'
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
                                  ? 'Варианты ответа. Отметьте правильный'
                                  : 'Варианты ответа',
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
                                    labelText:
                                        '${_list ? 'Пункт' : 'Вариант'} ${i + 1}',
                                    counterText: _list ? null : '',
                                  ),
                                  validator: (v) => (v ?? '').trim().isEmpty
                                      ? 'Заполните поле'
                                      : null,
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    'Удалить ${_list ? 'пункт' : 'вариант'}',
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
                              _list ? 'Добавить пункт' : 'Добавить вариант',
                            ),
                          ),
                        ),
                      if (!_list && !_quiz)
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Несколько ответов'),
                          value: _multiple,
                          onChanged: (v) => setState(() => _multiple = v),
                        ),
                      if (_quiz) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _explanation,
                          maxLength: 500,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Пояснение (необязательно)',
                            helperText: 'Появится после ответа',
                            counterText: '',
                          ),
                        ),
                      ],
                      if (!_list)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Участники видят, кто за что проголосовал.',
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
                    child: const Text('Отправить'),
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
