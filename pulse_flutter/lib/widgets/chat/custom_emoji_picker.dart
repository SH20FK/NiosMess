import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/chat/expression_picker_components.dart';
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
import 'package:pulse_flutter/widgets/app_dialogs.dart';

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
    tooltip: context.l10n.customEmojiTitle,
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
  const CustomEmojiPicker({
    required this.onSelected,
    this.selectedSetId,
    this.onSetSelected,
    this.onSearchFocus,
    this.showManagement = true,
    super.key,
  });
  final ValueChanged<ApiCustomEmoji> onSelected;
  final int? selectedSetId;
  final ValueChanged<int?>? onSetSelected;
  final VoidCallback? onSearchFocus;
  final bool showManagement;
  @override
  ConsumerState<CustomEmojiPicker> createState() => CustomEmojiPickerState();
}

class CustomEmojiPickerState extends ConsumerState<CustomEmojiPicker>
    with AutomaticKeepAliveClientMixin {
  late int? _setId = widget.selectedSetId;
  String _query = '';
  bool _busy = false;
  @override
  bool get wantKeepAlive => true;
  @override
  void didUpdateWidget(covariant CustomEmojiPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSetId != widget.selectedSetId) {
      _setId = widget.selectedSetId;
    }
  }

  void _selectSet(int id) {
    setState(() => _setId = id);
    widget.onSetSelected?.call(id);
  }

  Future<void> showManagement() async {
    if (_busy) return;
    final packs =
        ref.read(customEmojiSetsProvider).value ?? const <ApiCustomEmojiSet>[];
    final active =
        packs.where((pack) => pack.id == _setId).firstOrNull ??
        packs.firstOrNull;
    final account = ref.read(authProvider).session?.userId;
    final action = await AppModal.showSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(context.l10n.pickerManage),
                subtitle: active == null ? null : Text(active.title),
              ),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: Text(context.l10n.customCreateSet),
                onTap: () => Navigator.pop(context, 'create'),
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: Text(context.l10n.customAddSet),
                onTap: () => Navigator.pop(context, 'save'),
              ),
              if (active != null && active.ownerId == account)
                ListTile(
                  leading: const Icon(Icons.add_photo_alternate_outlined),
                  title: Text(context.l10n.customAddEmoji),
                  onTap: () => Navigator.pop(context, 'add'),
                ),
              if (active != null && !active.isOfficial)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline),
                  title: Text(context.l10n.customRemoveSet),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'create') return _create();
    if (action == 'save') return _save();
    if (action == 'add' && active != null) return _add(active);
    if (action == 'remove' && active != null) {
      await _perform(() async {
        await ref.read(customEmojiRequestProvider)('remove_emoji_set', {
          'set_id': active.id,
        });
        await ref.read(customEmojiSetsProvider.notifier).refresh();
      });
    }
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

  Future<List<String>?> _fields(String title, List<String> labels) =>
      showAppDialog<List<String>>(
        context: context,
        builder: (_) => _CustomEmojiFieldsDialog(title: title, labels: labels),
      );

  (int, String)? _activeAccount() {
    final session = ref.read(authProvider).session;
    if (session == null || ref.read(authProvider.notifier).isLoggingOut) {
      return null;
    }
    return (session.userId, session.accessToken);
  }

  bool _sameAccount((int, String) account) =>
      mounted && _activeAccount() == account;

  Future<void> _create() async {
    final account = _activeAccount();
    if (account == null) return;
    final values = await _fields(context.l10n.customCreateSet, [
      context.l10n.customSetTitle,
      context.l10n.customSetName,
    ]);
    if (!mounted || values == null || !_sameAccount(account)) return;
    await _perform(() async {
      if (!mounted || !_sameAccount(account)) return;
      final result = await ref.read(customEmojiRequestProvider)(
        'create_emoji_set',
        {
          'title': values[0],
          'name': values[1].toLowerCase(),
          'is_public': true,
        },
      );
      if (!mounted || !_sameAccount(account)) return;
      await ref.read(customEmojiSetsProvider.notifier).refresh();
      if (_sameAccount(account)) _selectSet((result['id'] as num).toInt());
    });
  }

  Future<void> _save() async {
    final account = _activeAccount();
    if (account == null) return;
    final values = await _fields(context.l10n.customAddSet, [
      context.l10n.customSetName,
    ]);
    if (!mounted || values == null || !_sameAccount(account)) return;
    await _perform(() async {
      if (!mounted || !_sameAccount(account)) return;
      final result = await ref.read(customEmojiRequestProvider)(
        'get_emoji_set',
        {'name': values[0].toLowerCase()},
      );
      if (!mounted || !_sameAccount(account)) return;
      final pack = ApiCustomEmojiSet.fromJson(
        Map<String, dynamic>.from(result['set'] as Map),
      );
      await ref.read(customEmojiRequestProvider)('save_emoji_set', {
        'set_id': pack.id,
      });
      if (!mounted || !_sameAccount(account)) return;
      await ref.read(customEmojiSetsProvider.notifier).refresh();
      if (_sameAccount(account)) _selectSet(pack.id);
    });
  }

  Future<void> _add(ApiCustomEmojiSet pack) async {
    final account = _activeAccount();
    if (account == null || pack.ownerId != account.$1) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'webp', 'gif', 'svg'],
    );
    if (!mounted || result.isEmpty || !_sameAccount(account)) return;
    final file = result.single;
    final bytes = await file.readAsBytes();
    if (!mounted || !_sameAccount(account)) return;
    if (bytes.length > 512 * 1024) {
      AppToast.showError(context, context.l10n.customFileTooLarge);
      return;
    }
    final values = await _fields(context.l10n.customAddEmoji, [
      context.l10n.customShortcode,
    ]);
    if (!mounted || values == null || !_sameAccount(account)) return;
    final tooManyFrames = context.l10n.customTooManyFrames;
    await _perform(() async {
      if (!mounted || !_sameAccount(account)) return;
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
              throw StateError(tooManyFrames);
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
      if (!mounted || !_sameAccount(account)) return;
      await ref.read(customEmojiRequestProvider)('add_custom_emoji', {
        'set_id': pack.id,
        'shortcode': values[0].toLowerCase(),
        'filename': file.name,
        'data_base64': base64Encode(bytes),
        'width': width,
        'height': height,
        'duration_seconds': duration,
      });
      if (!mounted || !_sameAccount(account)) return;
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
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (constraints.maxHeight >= 100)
            Row(
              children: [
                Expanded(
                  child: ExpressionSearchField(
                    initialValue: _query,
                    hint: context.l10n.pickerSearchEmoji,
                    onFocus: widget.onSearchFocus,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: AppLoadingIndicator(size: 20),
                  )
                else if (widget.showManagement)
                  IconButton(
                    tooltip: context.l10n.pickerManage,
                    onPressed: showManagement,
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
              ],
            ),
          if (constraints.maxHeight >= 160 && packs.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final pack in packs)
                    ExpressionPackButton(
                      label: pack.title,
                      selected: active?.id == pack.id,
                      onTap: () => _selectSet(pack.id),
                      child: pack.emojis.isEmpty
                          ? const CustomEmojiIcon()
                          : CustomEmojiImage(
                              emoji: pack.emojis.first,
                              size: 28,
                            ),
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
                        () => ref
                            .read(customEmojiSetsProvider.notifier)
                            .refresh(),
                      ),
                      child: Text(context.l10n.commonRetry),
                    ),
                  )
                : items.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        query.isEmpty
                            ? context.l10n.customEmptySet
                            : context.l10n.stickerHubNoResults,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : GridView.builder(
                    key: PageStorageKey('custom:${active?.id}:$query'),
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 60,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemCount: items.length,
                    itemBuilder: (_, index) => Tooltip(
                      message: items[index].token,
                      child: Semantics(
                        label: items[index].shortcode,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => widget.onSelected(items[index]),
                          child: Center(
                            child: CustomEmojiImage(
                              emoji: items[index],
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The route owns its controllers through the reverse transition and unmount.
class _CustomEmojiFieldsDialog extends StatefulWidget {
  const _CustomEmojiFieldsDialog({required this.title, required this.labels});
  final String title;
  final List<String> labels;

  @override
  State<_CustomEmojiFieldsDialog> createState() =>
      _CustomEmojiFieldsDialogState();
}

class _CustomEmojiFieldsDialogState extends State<_CustomEmojiFieldsDialog> {
  late final _controllers = [
    for (final _ in widget.labels) TextEditingController(),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() => Navigator.pop(
    context,
    _controllers.map((controller) => controller.text.trim()).toList(),
  );

  @override
  Widget build(BuildContext context) => AppDialog(
    title: widget.title,
    icon: Icons.emoji_emotions_outlined,
    actions: [
      AppDialogAction(
        label: context.l10n.commonCancel,
        onPressed: () => Navigator.pop(context),
      ),
      AppDialogAction(
        label: context.l10n.customContinue,
        isPrimary: true,
        onPressed: _submit,
      ),
    ],
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.labels.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == widget.labels.length - 1 ? 0 : 12,
            ),
            child: TextField(
              controller: _controllers[i],
              textInputAction: i == widget.labels.length - 1
                  ? TextInputAction.done
                  : TextInputAction.next,
              // EditableText already advances focus for TextInputAction.next.
              onSubmitted: i == widget.labels.length - 1
                  ? (_) => _submit()
                  : null,
              decoration: InputDecoration(labelText: widget.labels[i]),
            ),
          ),
      ],
    ),
  );
}
