import 'package:pulse_flutter/widgets/app_refresh_indicator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/router/app_navigation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
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

void _sameAccount(
  WidgetRef ref,
  (int?, String?) expected,
  AppLocalizations l10n,
) {
  if (expected.$1 == null || _account(ref) != expected) {
    throw StateError(l10n.errorSessionExpired);
  }
}

String _date(BuildContext context, DateTime value) => DateFormat.MMMd(
  Localizations.localeOf(context).toLanguageTag(),
).add_Hm().format(value);

/// Single-flight guard for [openSavedMessages]: a second tap while the saved
/// chat is still resolving must not push a duplicate route.
bool _savedMessagesOpening = false;

Future<void> openSavedMessages(BuildContext context, WidgetRef ref) async {
  if (_savedMessagesOpening) return;
  final account = _account(ref);
  if (account.$1 == null) return;
  _savedMessagesOpening = true;
  final repo = ref.read(chatProductivityRepositoryProvider);
  if (repo.cachedSavedChatId == null) {
    AppToast.showInfo(context, context.l10n.inboxSavedOpening);
  }
  try {
    final chat = await repo.saved();
    if (!context.mounted) return;
    _sameAccount(ref, account, context.l10n);
    context.push('/chat/${chat.id}');
  } catch (e) {
    if (context.mounted) AppToast.showError(context, e);
  } finally {
    _savedMessagesOpening = false;
  }
}

/// Opens folder management from the inbox scope strip (the "⋯" menu item
/// and the long-press on a folder pill).
Future<void> openChatFolders(BuildContext context) {
  return pushAppRoute<void>(
    context,
    '/chats/folders',
    fallback: (_) => const ChatFoldersScreen(),
  );
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

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    ChatFolder folder,
  ) async {
    try {
      await ref.read(chatFoldersProvider.notifier).remove(folder.id);
      if (ref.read(selectedChatFolderProvider) == folder.id) {
        ref.read(selectedChatFolderProvider.notifier).select(null);
      }
    } catch (e) {
      if (context.mounted) AppToast.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final value = ref.watch(chatFoldersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.inboxFolders)),
      body: value.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(chatFoldersProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l.commonRetry),
          ),
        ),
        data: (folders) => ReorderableListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: folders.length,
          footer: TextButton.icon(
            onPressed: () => _edit(context, null),
            icon: const ProductivityIcon('plus'),
            label: Text(l.inboxFolderCreate),
          ),
          onReorderItem: (a, b) async {
            if (a >= folders.length) return;
            if (b >= folders.length) b = folders.length - 1;
            final ordered = [...folders];
            final item = ordered.removeAt(a);
            ordered.insert(b, item);
            try {
              await ref.read(chatFoldersProvider.notifier).reorder(ordered);
            } catch (e) {
              if (context.mounted) AppToast.showError(context, e);
            }
          },
          itemBuilder: (context, i) {
            final f = folders[i];
            return ListTile(
              key: ValueKey(f.id),
              leading: const ProductivityIcon('folder'),
              title: CustomEmojiText(f.title),
              subtitle: Text(
                [
                  l.inboxFolderChatsCount(f.chatIds.length),
                  if (f.types.isNotEmpty) l.inboxFolderHasRules,
                ].join(' · '),
              ),
              onTap: () => _edit(context, f),
              trailing: MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(context, f),
                    child: Text(l.chatEdit),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _remove(context, ref, f),
                    child: Text(l.inboxFolderDelete),
                  ),
                ],
                builder: (context, controller, _) => IconButton(
                  tooltip: l.inboxFolderActions,
                  icon: const ProductivityIcon('ellipsis'),
                  onPressed: () =>
                      controller.isOpen ? controller.close() : controller.open(),
                ),
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
    final l = context.l10n;
    try {
      _sameAccount(ref, _owner, context.l10n);
      if (_name.text.trim().isEmpty || customEmojiLength(_name.text) > 40) {
        throw StateError(l.inboxFolderNameInvalid);
      }
      if (_ids.isEmpty && _types.isEmpty) {
        throw StateError(l.inboxFolderEmptyRules);
      }
      setState(() => _saving = true);
      await ref
          .read(chatFoldersProvider.notifier)
          .save(
            ChatFolder(
              id: _id,
              title: _name.text.trim(),
              // Every explicitly selected chat is sent as-is: the local list may
              // be filtered by search or still loading, and dropping unknown ids
              // silently removed folder members on save.
              chatIds: _ids.toList(),
              types: _types.toList(),
              unreadOnly: _unread,
              position:
                  widget.folder?.position ??
                  (ref.read(chatFoldersProvider).value?.length ?? 0),
              version: widget.folder?.version ?? 0,
            ),
          );
      if (mounted) Navigator.pop(context);
    } on ChatFolderVersionConflict {
      if (!mounted) return;
      AppToast.showError(context, l.inboxFolderConflict);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) AppToast.showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final chatsValue = ref.watch(visibleChatsProvider);
    final chats = chatsValue.value ?? const <ApiChatSummary>[];
    final Widget? status = chats.isNotEmpty
        ? null
        : chatsValue.hasError
        ? Center(
            child: TextButton.icon(
              onPressed: () => ref.invalidate(chatsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l.inboxChatsLoadFailed),
            ),
          )
        : chatsValue.isLoading
        ? const SizedBox(
            height: 160,
            child: Center(child: AppLoadingIndicator()),
          )
        : null;
    final headerCount = 1 + (status == null ? 0 : 1);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: chats.length + headerCount,
                  itemBuilder: (context, index) {
                    if (index >= headerCount) {
                      final chat = chats[index - headerCount];
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
                    if (index == 1) return status!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.folder == null
                              ? l.inboxFolderNew
                              : l.inboxFolderEdit,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _name,
                          inputFormatters: [CustomEmojiLengthFormatter(40)],
                          decoration: InputDecoration(
                            labelText: l.groupNameLabel,
                            suffixIcon: CustomEmojiComposerButton(
                              controller: _name,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(l.inboxFolderAutoAdd),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final entry in {
                              'direct': l.chatListFilterDirect,
                              'group': l.chatListFilterGroups,
                              'channel': l.chatListFilterChannels,
                              'bot': l.chatListFilterBots,
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
                          title: Text(l.inboxFolderUnreadOnly),
                          value: _unread,
                          onChanged: (v) => setState(() => _unread = v),
                        ),
                        Text(l.inboxFolderAddChats),
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
                  child: Text(_saving ? l.commonSaving : l.commonSave),
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
        final l10n = context.l10n;
        _sameAccount(ref, account, l10n);
        final repo = ref.read(chatProductivityRepositoryProvider);
        final target = reminder == null ? chatId : (await repo.saved()).id;
        _sameAccount(ref, account, l10n);
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
      reminder == null
          ? context.l10n.inboxScheduleCreated
          : context.l10n.inboxReminderSaved,
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
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
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
                widget.reminder
                    ? l.inboxReminderTitle
                    : l.inboxScheduleTitle,
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
                  labelText: widget.reminder
                      ? l.inboxReminderText
                      : l.chatMessageHint,
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
                    l.inboxScheduleInHour: DateTime.now().add(
                      const Duration(hours: 1),
                    ),
                    l.inboxScheduleTomorrow: DateTime(
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
                l.inboxScheduleServerHint,
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
                            StateError(l.inboxMessageRequired),
                          );
                          return;
                        }
                        if (!_due.isAfter(
                          DateTime.now().add(const Duration(seconds: 5)),
                        )) {
                          AppToast.showError(
                            context,
                            StateError(l.inboxScheduleFutureTime),
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
                      ? l.commonSaving
                      : widget.reminder
                      ? l.inboxReminderSave
                      : l.inboxScheduleAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScheduledMessagesScreen extends ConsumerWidget {
  const ScheduledMessagesScreen({super.key, this.chatId});
  final int? chatId;

  Future<void> _reschedule(
    BuildContext context,
    WidgetRef ref,
    ScheduledChatMessage job,
  ) async {
    final account = _account(ref);
    try {
      final due = await pickProductivityDate(context, job.dueAt);
      if (due == null || !context.mounted) return;
      _sameAccount(ref, account, context.l10n);
      await ref.read(chatProductivityRepositoryProvider).call(
        'update_scheduled_message',
        {'id': job.id, 'due_at': due.toUtc().toIso8601String()},
      );
      ref.invalidate(scheduledChatMessagesProvider(chatId));
    } catch (e) {
      if (context.mounted) AppToast.showError(context, e);
    }
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    ScheduledChatMessage job,
  ) async {
    try {
      await ref.read(chatProductivityRepositoryProvider).call(
        'cancel_scheduled_message',
        {'id': job.id},
      );
      ref.invalidate(scheduledChatMessagesProvider(chatId));
    } catch (e) {
      if (context.mounted) AppToast.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final jobs = ref.watch(scheduledChatMessagesProvider(chatId));
    return Scaffold(
      appBar: AppBar(title: Text(l.inboxScheduledTitle)),
      body: jobs.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(
          child: TextButton.icon(
            onPressed: () =>
                ref.invalidate(scheduledChatMessagesProvider(chatId)),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l.commonRetry),
          ),
        ),
        data: (items) => items.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l.inboxScheduleEmpty),
                    const SizedBox(height: 8),
                    Text(l.inboxScheduleEmptyHint),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.maybePop(context),
                      child: Text(l.callBackToChats),
                    ),
                  ],
                ),
              )
            : AppRefreshIndicator(
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
                        job.previewLocked
                            ? l.inboxScheduleLockedPreview
                            : job.preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${chat?.name ?? l.commonChat}\n${_date(context, job.dueAt)}${job.error == null ? '' : '\n${job.error}'}',
                      ),
                      isThreeLine: true,
                      onTap: () => context.push('/chat/${job.chatId}'),
                      trailing: MenuAnchor(
                        menuChildren: [
                          MenuItemButton(
                            leadingIcon: const Icon(Icons.schedule_rounded),
                            onPressed: () => _reschedule(context, ref, job),
                            child: Text(l.inboxScheduleReschedule),
                          ),
                          MenuItemButton(
                            leadingIcon: const Icon(
                              Icons.cancel_outlined,
                            ),
                            onPressed: () =>
                                _cancel(context, ref, job),
                            child: Text(l.inboxScheduleCancel),
                          ),
                        ],
                        builder: (context, controller, _) => IconButton(
                          tooltip: l.inboxScheduleActions,
                          icon: const ProductivityIcon('ellipsis'),
                          onPressed: () => controller.isOpen
                              ? controller.close()
                              : controller.open(),
                        ),
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
      _sameAccount(ref, _owner, context.l10n);
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

  Future<void> _toggleClosed(BuildContext context, ChatTopic topic) async {
    try {
      _sameAccount(ref, _owner, context.l10n);
      await ref.read(chatProductivityRepositoryProvider).call(
        'update_group_topic',
        {
          'chat_id': widget.chatId,
          'topic_id': topic.id,
          'closed': !topic.closed,
        },
      );
      ref.invalidate(groupTopicsProvider(widget.chatId));
      ref.invalidate(chatsProvider);
    } catch (e) {
      if (context.mounted) AppToast.showError(context, e);
    }
  }

  void _startRename(ChatTopic topic) {
    setState(() {
      _topic = topic;
      _editing = true;
      _name.text = topic.title;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final value = ref.watch(groupTopicsProvider(widget.chatId));
    final chat = ref.watch(chatByIdProvider(widget.chatId));
    return Scaffold(
      appBar: AppBar(title: Text(chat?.name ?? l.inboxTopicsTitle)),
      body: value.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(groupTopicsProvider(widget.chatId)),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l.commonRetry),
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
                    subtitle: topic.closed ? Text(l.inboxTopicClosed) : null,
                    onTap: () async {
                      final account = _account(ref);
                      try {
                        final json = await ref
                            .read(chatProductivityRepositoryProvider)
                            .call('get_chat', {'chat_id': topic.id});
                        if (!context.mounted) return;
                        _sameAccount(ref, account, context.l10n);
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
                          MenuAnchor(
                            menuChildren: [
                              MenuItemButton(
                                leadingIcon: const Icon(Icons.edit_outlined),
                                onPressed: () => _startRename(topic),
                                child: Text(l.inboxTopicRename),
                              ),
                              MenuItemButton(
                                leadingIcon: Icon(
                                  topic.closed
                                      ? Icons.unarchive_outlined
                                      : Icons.archive_outlined,
                                ),
                                onPressed: () => _toggleClosed(context, topic),
                                child: Text(
                                  topic.closed
                                      ? l.inboxTopicOpen
                                      : l.inboxTopicClose,
                                ),
                              ),
                            ],
                            builder: (context, controller, _) => IconButton(
                              tooltip: l.inboxTopicActions,
                              icon: const ProductivityIcon('ellipsis'),
                              onPressed: () => controller.isOpen
                                  ? controller.close()
                                  : controller.open(),
                            ),
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
                                labelText: l.inboxTopicName,
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
                                  child: Text(l.commonCancel),
                                ),
                                FilledButton(
                                  onPressed: _busy ? null : _save,
                                  child: Text(l.commonSave),
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
                          label: Text(l.inboxTopicCreate),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
