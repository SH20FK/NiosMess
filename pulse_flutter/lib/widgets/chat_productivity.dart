import 'package:flutter/material.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/chat_productivity.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/chat_productivity_provider.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_text.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji_picker.dart';

class ProductivityIcon extends StatelessWidget {
  const ProductivityIcon(this.name, {super.key, this.size = 20, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/svg/pattern_icons/lucide/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      color ??
          IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurfaceVariant,
      BlendMode.srcIn,
    ),
  );
}

(int?, String?) _account(WidgetRef ref) {
  final s = ref.read(authProvider).session;
  return (s?.userId, s?.accessToken);
}

void _sameAccount(WidgetRef ref, (int?, String?) expected) {
  if (expected.$1 == null || _account(ref) != expected) {
    throw StateError('Сеанс изменился');
  }
}

String _date(BuildContext context, DateTime value) => DateFormat.MMMd(
  Localizations.localeOf(context).toLanguageTag(),
).add_Hm().format(value);

Future<void> openSavedMessages(BuildContext context, WidgetRef ref) async {
  final account = _account(ref);
  try {
    final chat = await ref.read(chatProductivityRepositoryProvider).saved();
    if (!context.mounted) return;
    _sameAccount(ref, account);
    context.push('/chat/${chat.id}');
  } catch (e) {
    if (context.mounted) AppToast.showError(context, e);
  }
}

class ChatProductivityBar extends ConsumerWidget {
  const ChatProductivityBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(chatFoldersProvider).value ?? [];
    final selected = ref.watch(selectedChatFolderProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openSavedMessages(context, ref),
                  icon: const ProductivityIcon('bookmark'),
                  label: const Text(
                    'Избранное',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Отложенные сообщения и напоминания',
              icon: const ProductivityIcon('clock'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScheduledMessagesScreen(),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Папки чатов',
              icon: const ProductivityIcon('folder'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChatFoldersScreen(),
                ),
              ),
            ),
          ],
        ),
        if (folders.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('Все папки'),
                    selected: selected == null,
                    onSelected: (_) => ref
                        .read(selectedChatFolderProvider.notifier)
                        .select(null),
                  ),
                ),
                for (final folder in folders)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: CustomEmojiText(folder.title),
                      selected: selected == folder.id,
                      onSelected: (_) => ref
                          .read(selectedChatFolderProvider.notifier)
                          .select(selected == folder.id ? null : folder.id),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class ChatFoldersScreen extends ConsumerWidget {
  const ChatFoldersScreen({super.key});
  Future<void> _edit(BuildContext context, ChatFolder? folder) =>
      AppModal.showSheet<void>(
        context: context,
        maxWidth: 640,
        isScrollable: true,
        builder: (_) => ChatFolderEditor(folder: folder),
      );
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(chatFoldersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Папки чатов')),
      body: value.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(chatFoldersProvider),
            child: const Text('Повторить загрузку'),
          ),
        ),
        data: (folders) => ReorderableListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: folders.length,
          footer: TextButton.icon(
            onPressed: () => _edit(context, null),
            icon: const ProductivityIcon('plus'),
            label: const Text('Создать папку'),
          ),
          onReorderItem: (a, b) async {
            if (a >= folders.length) return;
            if (b >= folders.length) b = folders.length - 1;
            final ordered = [...folders];
            final item = ordered.removeAt(a);
            ordered.insert(b, item);
            try {
              for (var i = 0; i < ordered.length; i++) {
                final f = ordered[i];
                await ref.read(chatProductivityRepositoryProvider).call(
                  'save_chat_folder',
                  {...f.toJson(), 'position': i},
                );
              }
              ref.invalidate(chatFoldersProvider);
            } catch (e) {
              if (context.mounted) AppToast.showError(context, e);
              ref.invalidate(chatFoldersProvider);
            }
          },
          itemBuilder: (context, i) {
            final f = folders[i];
            return ListTile(
              key: ValueKey(f.id),
              leading: const ProductivityIcon('folder'),
              title: CustomEmojiText(f.title),
              subtitle: Text(
                '${f.chatIds.length} выбранных чатов${f.types.isEmpty ? '' : ' · Есть правила'}',
              ),
              onTap: () => _edit(context, f),
              trailing: PopupMenuButton<String>(
                tooltip: 'Действия с папкой',
                onSelected: (value) async {
                  if (value == 'edit') {
                    await _edit(context, f);
                    return;
                  }
                  try {
                    await ref.read(chatFoldersProvider.notifier).remove(f.id);
                    if (ref.read(selectedChatFolderProvider) == f.id) {
                      ref
                          .read(selectedChatFolderProvider.notifier)
                          .select(null);
                    }
                  } catch (e) {
                    if (context.mounted) AppToast.showError(context, e);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Изменить')),
                  PopupMenuItem(value: 'delete', child: Text('Удалить папку')),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class ChatFolderEditor extends ConsumerStatefulWidget {
  const ChatFolderEditor({super.key, this.folder});
  final ChatFolder? folder;
  @override
  ConsumerState<ChatFolderEditor> createState() => _ChatFolderEditorState();
}

class _ChatFolderEditorState extends ConsumerState<ChatFolderEditor> {
  late final CustomEmojiTextController _name;
  late final String _id;
  late final Set<int> _ids;
  late final Set<String> _types;
  late final (int?, String?) _owner;
  bool _unread = false, _saving = false;
  @override
  void initState() {
    super.initState();
    _owner = _account(ref);
    _id = widget.folder?.id ?? const Uuid().v4();
    _name = CustomEmojiTextController(text: widget.folder?.title ?? '');
    _ids = {...?widget.folder?.chatIds};
    _types = {...?widget.folder?.types};
    _unread = widget.folder?.unreadOnly ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    try {
      _sameAccount(ref, _owner);
      if (_name.text.trim().isEmpty || customEmojiLength(_name.text) > 40) {
        throw StateError('Введите название до 40 символов');
      }
      if (_ids.isEmpty && _types.isEmpty) {
        throw StateError('Выберите чаты или правило');
      }
      setState(() => _saving = true);
      await ref
          .read(chatFoldersProvider.notifier)
          .save(
            ChatFolder(
              id: _id,
              title: _name.text.trim(),
              chatIds: _ids
                  .where((id) => ref.read(chatByIdProvider(id)) != null)
                  .toList(),
              types: _types.toList(),
              unreadOnly: _unread,
              position:
                  widget.folder?.position ??
                  (ref.read(chatFoldersProvider).value?.length ?? 0),
              version: widget.folder?.version ?? 0,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppToast.showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(visibleChatsProvider).value ?? [];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: chats.length + 1,
                  itemBuilder: (context, index) {
                    if (index > 0) {
                      final chat = chats[index - 1];
                      return CheckboxListTile(
                        value: _ids.contains(chat.id),
                        title: CustomEmojiText(chat.name),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (on) => setState(
                          () => on == true
                              ? _ids.add(chat.id)
                              : _ids.remove(chat.id),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.folder == null
                              ? 'Новая папка'
                              : 'Изменить папку',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _name,
                          inputFormatters: [CustomEmojiLengthFormatter(40)],
                          decoration: InputDecoration(
                            labelText: 'Название',
                            suffixIcon: CustomEmojiComposerButton(
                              controller: _name,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Автоматически добавлять'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final entry in {
                              'direct': 'Личные',
                              'group': 'Группы',
                              'channel': 'Каналы',
                              'bot': 'Боты',
                            }.entries)
                              FilterChip(
                                label: Text(entry.value),
                                selected: _types.contains(entry.key),
                                onSelected: (on) => setState(
                                  () => on
                                      ? _types.add(entry.key)
                                      : _types.remove(entry.key),
                                ),
                              ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Только непрочитанные'),
                          value: _unread,
                          onChanged: (v) => setState(() => _unread = v),
                        ),
                        const Text('Добавить отдельные чаты'),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Сохранение' : 'Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<DateTime?> pickProductivityDate(
  BuildContext context,
  DateTime initial,
) async {
  final now = DateTime.now();
  final day = await showDatePicker(
    context: context,
    initialDate: initial.isBefore(now) ? now : initial,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365)),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

Future<bool> showScheduledMessageComposer(
  BuildContext context,
  WidgetRef ref, {
  required int chatId,
  required String text,
  int? replyTo,
  ApiMessage? reminder,
}) async {
  final account = _account(ref);
  final result = await AppModal.showSheet<bool>(
    context: context,
    maxWidth: 560,
    isScrollable: true,
    builder: (_) => _ScheduleEditor(
      text: text,
      reminder: reminder != null,
      submit: (value, due, operationId) async {
        _sameAccount(ref, account);
        final repo = ref.read(chatProductivityRepositoryProvider);
        final target = reminder == null ? chatId : (await repo.saved()).id;
        _sameAccount(ref, account);
        await repo.schedule(
          target,
          value,
          due,
          operationId: operationId,
          replyTo: reminder == null ? replyTo : null,
          sourceChat: reminder?.chatId,
          sourceMessage: reminder?.id,
        );
      },
    ),
  );
  if (result == true && context.mounted) {
    AppToast.showSuccess(
      context,
      reminder == null ? 'Сообщение запланировано' : 'Напоминание сохранено',
    );
  }
  return result == true;
}

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({
    required this.text,
    required this.reminder,
    required this.submit,
  });
  final String text;
  final bool reminder;
  final Future<void> Function(String, DateTime, String) submit;
  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late final _text = CustomEmojiTextController(text: widget.text);
  final _operationId = const Uuid().v4();
  bool _saving = false;
  DateTime _due = DateTime.now().add(const Duration(hours: 1));
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.reminder ? 'Напомнить о сообщении' : 'Отложенная отправка',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              enabled: !_saving,
              minLines: 2,
              maxLines: 6,
              inputFormatters: [CustomEmojiLengthFormatter(10000)],
              decoration: InputDecoration(
                labelText: widget.reminder ? 'Текст напоминания' : 'Сообщение',
                suffixIcon: CustomEmojiComposerButton(controller: _text),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const ProductivityIcon('clock'),
              label: Text(_date(context, _due)),
              onPressed: _saving
                  ? null
                  : () async {
                      final date = await pickProductivityDate(context, _due);
                      if (date != null && mounted) setState(() => _due = date);
                    },
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final entry in {
                  'Через час': DateTime.now().add(const Duration(hours: 1)),
                  'Завтра утром': DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day + 1,
                    9,
                  ),
                }.entries)
                  ActionChip(
                    label: Text(entry.key),
                    onPressed: _saving
                        ? null
                        : () => setState(() => _due = entry.value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Отправится с сервера, даже если это устройство будет выключено.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      if (_text.text.trim().isEmpty) {
                        AppToast.showError(
                          context,
                          StateError('Введите сообщение'),
                        );
                        return;
                      }
                      if (!_due.isAfter(
                        DateTime.now().add(const Duration(seconds: 5)),
                      )) {
                        AppToast.showError(
                          context,
                          StateError('Выберите время в будущем'),
                        );
                        return;
                      }
                      setState(() => _saving = true);
                      try {
                        await widget.submit(
                          _text.text.trim(),
                          _due,
                          _operationId,
                        );
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        if (context.mounted) AppToast.showError(context, e);
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: Text(
                _saving
                    ? 'Сохраняем…'
                    : widget.reminder
                    ? 'Сохранить напоминание'
                    : 'Запланировать',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ScheduledMessagesScreen extends ConsumerWidget {
  const ScheduledMessagesScreen({super.key, this.chatId});
  final int? chatId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(scheduledChatMessagesProvider(chatId));
    return Scaffold(
      appBar: AppBar(title: const Text('Отложенные и напоминания')),
      body: jobs.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () =>
                ref.invalidate(scheduledChatMessagesProvider(chatId)),
            child: const Text('Повторить загрузку'),
          ),
        ),
        data: (items) => items.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Пока ничего не запланировано'),
                    const SizedBox(height: 8),
                    const Text(
                      'Удерживайте кнопку отправки, чтобы выбрать время. У сообщения можно выбрать «Напомнить».',
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.maybePop(context),
                      child: const Text('Вернуться к чатам'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(scheduledChatMessagesProvider(chatId));
                  await ref.read(scheduledChatMessagesProvider(chatId).future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final job = items[i];
                    final chat = ref.watch(chatByIdProvider(job.chatId));
                    return ListTile(
                      leading: ProductivityIcon(
                        job.kind == 'reminder' ? 'bell' : 'clock',
                      ),
                      title: CustomEmojiText(
                        job.preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${chat?.name ?? 'Чат'}\n${_date(context, job.dueAt)}${job.error == null ? '' : '\n${job.error}'}',
                      ),
                      isThreeLine: true,
                      onTap: () => context.push('/chat/${job.chatId}'),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Действия с отложенным сообщением',
                        onSelected: (action) async {
                          final account = _account(ref);
                          try {
                            final payload = <String, dynamic>{'id': job.id};
                            if (action == 'reschedule') {
                              final due = await pickProductivityDate(
                                context,
                                job.dueAt,
                              );
                              if (due == null || !context.mounted) return;
                              _sameAccount(ref, account);
                              payload['due_at'] = due.toUtc().toIso8601String();
                            }
                            await ref
                                .read(chatProductivityRepositoryProvider)
                                .call(
                                  action == 'cancel'
                                      ? 'cancel_scheduled_message'
                                      : 'update_scheduled_message',
                                  payload,
                                );
                            ref.invalidate(
                              scheduledChatMessagesProvider(chatId),
                            );
                          } catch (e) {
                            if (context.mounted) AppToast.showError(context, e);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'reschedule',
                            child: Text('Изменить время'),
                          ),
                          PopupMenuItem(
                            value: 'cancel',
                            child: Text('Отменить отправку'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class GroupTopicsScreen extends ConsumerStatefulWidget {
  const GroupTopicsScreen({super.key, required this.chatId});
  final int chatId;
  @override
  ConsumerState<GroupTopicsScreen> createState() => _GroupTopicsScreenState();
}

class _GroupTopicsScreenState extends ConsumerState<GroupTopicsScreen> {
  final _name = CustomEmojiTextController();
  bool _editing = false, _busy = false;
  ChatTopic? _topic;
  String _createId = const Uuid().v4();
  late final (int?, String?) _owner;
  @override
  void initState() {
    super.initState();
    _owner = _account(ref);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      _sameAccount(ref, _owner);
      setState(() => _busy = true);
      await ref
          .read(chatProductivityRepositoryProvider)
          .call(_topic == null ? 'create_group_topic' : 'update_group_topic', {
            'chat_id': widget.chatId,
            if (_topic == null) 'id': _createId,
            'title': _name.text.trim(),
            if (_topic != null) 'topic_id': _topic!.id,
          });
      ref.invalidate(groupTopicsProvider(widget.chatId));
      ref.invalidate(chatsProvider);
      if (mounted) {
        setState(() {
          _editing = false;
          _topic = null;
          _name.clear();
          _createId = const Uuid().v4();
        });
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(groupTopicsProvider(widget.chatId));
    final chat = ref.watch(chatByIdProvider(widget.chatId));
    return Scaffold(
      appBar: AppBar(title: Text(chat?.name ?? 'Темы группы')),
      body: value.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(groupTopicsProvider(widget.chatId)),
            child: const Text('Повторить загрузку'),
          ),
        ),
        data: (data) => Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: data.topics.length,
                itemBuilder: (context, i) {
                  final topic = data.topics[i];
                  final unread =
                      ref.watch(chatByIdProvider(topic.id))?.unreadCount ??
                      topic.unreadCount;
                  return ListTile(
                    leading: ProductivityIcon(topic.closed ? 'lock' : 'hash'),
                    title: CustomEmojiText(topic.title),
                    subtitle: topic.closed ? const Text('Тема закрыта') : null,
                    onTap: () async {
                      final account = _account(ref);
                      try {
                        final json = await ref
                            .read(chatProductivityRepositoryProvider)
                            .call('get_chat', {'chat_id': topic.id});
                        if (!context.mounted) return;
                        _sameAccount(ref, account);
                        ref
                            .read(chatsProvider.notifier)
                            .upsertChat(ApiChatSummary.fromJson(json));
                        context.push('/chat/${topic.id}');
                      } catch (e) {
                        if (context.mounted) AppToast.showError(context, e);
                      }
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unread > 0)
                          Text(
                            '$unread',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        if (data.canManage && topic.id != widget.chatId)
                          PopupMenuButton<String>(
                            tooltip: 'Действия с темой',
                            onSelected: (action) async {
                              if (action == 'rename') {
                                setState(() {
                                  _topic = topic;
                                  _editing = true;
                                  _name.text = topic.title;
                                });
                                return;
                              }
                              try {
                                _sameAccount(ref, _owner);
                                await ref
                                    .read(chatProductivityRepositoryProvider)
                                    .call('update_group_topic', {
                                      'chat_id': widget.chatId,
                                      'topic_id': topic.id,
                                      'closed': !topic.closed,
                                    });
                                ref.invalidate(
                                  groupTopicsProvider(widget.chatId),
                                );
                                ref.invalidate(chatsProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  AppToast.showError(context, e);
                                }
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Text('Переименовать'),
                              ),
                              PopupMenuItem(
                                value: 'close',
                                child: Text(
                                  topic.closed
                                      ? 'Открыть тему'
                                      : 'Закрыть тему',
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (data.canManage)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _editing
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _name,
                              autofocus: true,
                              inputFormatters: [CustomEmojiLengthFormatter(80)],
                              decoration: InputDecoration(
                                labelText: 'Название темы',
                                suffixIcon: CustomEmojiComposerButton(
                                  controller: _name,
                                ),
                              ),
                              onSubmitted: (_) => _busy ? null : _save(),
                            ),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() => _editing = false),
                                  child: const Text('Отмена'),
                                ),
                                FilledButton(
                                  onPressed: _busy ? null : _save,
                                  child: const Text('Сохранить'),
                                ),
                              ],
                            ),
                          ],
                        )
                      : TextButton.icon(
                          onPressed: () => setState(() {
                            _editing = true;
                            _topic = null;
                            _name.clear();
                          }),
                          icon: const ProductivityIcon('plus'),
                          label: const Text('Создать тему'),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
