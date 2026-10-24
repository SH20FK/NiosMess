import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/custom_emoji_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/custom_emoji_provider.dart';
import 'package:pulse_flutter/widgets/chat/custom_emoji.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class CustomEmojiIcon extends StatelessWidget {
  const CustomEmojiIcon({super.key, this.size = 22});
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="6"/><path d="M8 14c2 3 6 3 8 0M8 9h.01M16 9h.01"/></svg>',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurfaceVariant,
      BlendMode.srcIn,
    ),
  );
}

class CustomEmojiComposerButton extends StatelessWidget {
  const CustomEmojiComposerButton({required this.controller, super.key});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Кастомные эмодзи',
    icon: const CustomEmojiIcon(),
    onPressed: () => AppModal.showSheet<void>(
      context: context,
      maxWidth: 560,
      builder: (_) => SizedBox(
        height: 420,
        child: CustomEmojiPicker(
          onSelected: (emoji) => insertCustomEmoji(controller, emoji),
        ),
      ),
    ),
  );
}

class CustomEmojiPicker extends ConsumerStatefulWidget {
  const CustomEmojiPicker({required this.onSelected, super.key});
  final ValueChanged<ApiCustomEmoji> onSelected;
  @override
  ConsumerState<CustomEmojiPicker> createState() => _CustomEmojiPickerState();
}

class _CustomEmojiPickerState extends ConsumerState<CustomEmojiPicker>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  int? _setId;
  String _query = '';
  bool _busy = false;
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) AppToast.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<String>?> _fields(String title, List<String> labels) async {
    final controllers = [for (final _ in labels) TextEditingController()];
    try {
      return await showDialog<List<String>>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < labels.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controllers[i],
                      decoration: InputDecoration(labelText: labels[i]),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                controllers.map((c) => c.text.trim()).toList(),
              ),
              child: const Text('Продолжить'),
            ),
          ],
        ),
      );
    } finally {
      for (final c in controllers) {
        c.dispose();
      }
    }
  }

  Future<void> _create() async {
    final values = await _fields('Новый набор эмодзи', [
      'Название',
      'Короткое имя латиницей',
    ]);
    if (values == null || !mounted) return;
    await _perform(() async {
      final result = await ref.read(customEmojiRequestProvider)(
        'create_emoji_set',
        {
          'title': values[0],
          'name': values[1].toLowerCase(),
          'is_public': true,
        },
      );
      await ref.read(customEmojiSetsProvider.notifier).refresh();
      if (mounted) setState(() => _setId = (result['id'] as num).toInt());
    });
  }

  Future<void> _save() async {
    final values = await _fields('Добавить набор', ['Короткое имя набора']);
    if (values == null || !mounted) return;
    await _perform(() async {
      final result = await ref.read(customEmojiRequestProvider)(
        'get_emoji_set',
        {'name': values[0].toLowerCase()},
      );
      final pack = ApiCustomEmojiSet.fromJson(
        Map<String, dynamic>.from(result['set'] as Map),
      );
      await ref.read(customEmojiRequestProvider)('save_emoji_set', {
        'set_id': pack.id,
      });
      await ref.read(customEmojiSetsProvider.notifier).refresh();
      if (mounted) setState(() => _setId = pack.id);
    });
  }

  Future<void> _add(ApiCustomEmojiSet pack) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'webp', 'gif', 'svg'],
    );
    if (result.isEmpty || !mounted) return;
    final file = result.single;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 512 * 1024) {
      AppToast.showError(context, 'Выберите изображение размером до 512 КБ');
      return;
    }
    final values = await _fields('Добавить эмодзи', [
      'Короткое имя: латиница, цифры, _',
    ]);
    if (values == null || !mounted) return;
    await _perform(() async {
      var width = 128, height = 128;
      double? duration;
      if (file.extension?.toLowerCase() != 'svg') {
        final codec = await ui.instantiateImageCodec(bytes);
        try {
          final first = await codec.getNextFrame();
          width = first.image.width;
          height = first.image.height;
          var millis = first.duration.inMilliseconds;
          first.image.dispose();
          if (codec.frameCount > 1) {
            if (codec.frameCount > 300) {
              throw StateError('Слишком много кадров в эмодзи');
            }
            for (var i = 1; i < codec.frameCount; i++) {
              final frame = await codec.getNextFrame();
              millis += frame.duration.inMilliseconds;
              frame.image.dispose();
            }
            duration = millis / 1000;
          }
        } finally {
          codec.dispose();
        }
      }
      await ref.read(customEmojiRequestProvider)('add_custom_emoji', {
        'set_id': pack.id,
        'shortcode': values[0].toLowerCase(),
        'filename': file.name,
        'data_base64': base64Encode(bytes),
        'width': width,
        'height': height,
        'duration_seconds': duration,
      });
      await ref.read(customEmojiSetsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final result = ref.watch(customEmojiSetsProvider),
        scheme = Theme.of(context).colorScheme;
    final packs = result.value ?? const <ApiCustomEmojiSet>[];
    final active =
        packs.where((s) => s.id == _setId).firstOrNull ?? packs.firstOrNull;
    final account = ref.watch(authProvider.select((a) => a.session?.userId));
    final query = _query.toLowerCase().trim();
    final items = query.isEmpty
        ? active?.emojis ?? const <ApiCustomEmoji>[]
        : [
            for (final pack in packs)
              for (final emoji in pack.emojis)
                if (emoji.shortcode.contains(query) ||
                    pack.title.toLowerCase().contains(query))
                  emoji,
          ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Поиск эмодзи',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: AppLoadingIndicator(size: 20),
                )
              else
                MenuAnchor(
                  builder: (_, controller, _) => IconButton(
                    tooltip: 'Наборы эмодзи',
                    icon: const Icon(Icons.more_horiz_rounded),
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                  ),
                  menuChildren: [
                    MenuItemButton(
                      onPressed: _create,
                      leadingIcon: const Icon(Icons.add_rounded),
                      child: const Text('Создать набор'),
                    ),
                    MenuItemButton(
                      onPressed: _save,
                      leadingIcon: const Icon(Icons.playlist_add_rounded),
                      child: const Text('Добавить набор'),
                    ),
                    if (active != null && active.ownerId == account)
                      MenuItemButton(
                        onPressed: () => _add(active),
                        leadingIcon: const Icon(
                          Icons.add_photo_alternate_outlined,
                        ),
                        child: const Text('Добавить эмодзи'),
                      ),
                    if (active != null && !active.isOfficial)
                      MenuItemButton(
                        onPressed: () => _perform(() async {
                          await ref.read(customEmojiRequestProvider)(
                            'remove_emoji_set',
                            {'set_id': active.id},
                          );
                          await ref
                              .read(customEmojiSetsProvider.notifier)
                              .refresh();
                        }),
                        leadingIcon: const Icon(Icons.remove_circle_outline),
                        child: const Text('Убрать из моих наборов'),
                      ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: result.isLoading && packs.isEmpty
              ? const Center(child: AppLoadingIndicator())
              : result.hasError && packs.isEmpty
              ? Center(
                  child: TextButton(
                    onPressed: () => _perform(
                      () =>
                          ref.read(customEmojiSetsProvider.notifier).refresh(),
                    ),
                    child: const Text('Повторить загрузку'),
                  ),
                )
              : items.isEmpty
              ? Center(
                  child: Text(
                    query.isEmpty
                        ? 'В этом наборе пока нет эмодзи'
                        : 'Ничего не найдено',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 56,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, index) => Tooltip(
                    message: items[index].token,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => widget.onSelected(items[index]),
                      child: Center(
                        child: CustomEmojiImage(emoji: items[index], size: 32),
                      ),
                    ),
                  ),
                ),
        ),
        if (packs.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: packs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Tooltip(
                message: packs[i].title,
                child: ChoiceChip(
                  selected: active?.id == packs[i].id,
                  onSelected: (_) => setState(() => _setId = packs[i].id),
                  showCheckmark: false,
                  label: packs[i].emojis.isEmpty
                      ? const CustomEmojiIcon()
                      : CustomEmojiImage(
                          emoji: packs[i].emojis.first,
                          size: 24,
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
