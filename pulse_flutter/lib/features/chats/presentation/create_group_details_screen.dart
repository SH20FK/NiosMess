import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/features/chats/application/create_group_controller.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class CreateGroupDetailsScreen extends ConsumerStatefulWidget {
  const CreateGroupDetailsScreen({super.key});

  @override
  ConsumerState<CreateGroupDetailsScreen> createState() =>
      _CreateGroupDetailsScreenState();
}

class _CreateGroupDetailsScreenState
    extends ConsumerState<CreateGroupDetailsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final draft = ref.read(createGroupControllerProvider).draft;
    _nameController.text = draft.name;
    _descController.text = draft.description;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    HapticService.tap();
    final notifier = ref.read(createGroupControllerProvider.notifier);
    notifier.setName(_nameController.text);
    notifier.setDescription(_descController.text);

    final result = await notifier.submit();
    if (!mounted) return;

    if (result != null && result.chatId > 0) {
      if (result.hasMemberFailures) {
        AppToast.showInfo(
          context,
          'Группа создана, но часть участников не удалось добавить из-за настроек приватности',
        );
      } else {
        AppToast.showSuccess(context, 'Группа успешно создана');
      }
      notifier.reset();
      context.go('/chat/${result.chatId}');
    } else {
      final error = ref.read(createGroupControllerProvider).errorMessage ??
          'Не удалось создать группу';
      AppToast.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final groupState = ref.watch(createGroupControllerProvider);
    final groupNotifier = ref.read(createGroupControllerProvider.notifier);
    final draft = groupState.draft;
    final bool isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    Widget content = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: <Widget>[
          // Header Squircle Avatar + Name Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Group Avatar Placeholder (Squircle M3E)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(
                  Icons.group_rounded,
                  size: 32,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              // Name text field
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  maxLength: 64,
                  decoration: InputDecoration(
                    labelText: 'Название группы *',
                    hintText: 'Введите название',
                    counterText: '',
                    filled: true,
                    fillColor: scheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.length < 2) {
                      return 'Не менее 2 символов';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description field
          TextFormField(
            controller: _descController,
            maxLines: 3,
            maxLength: 255,
            decoration: InputDecoration(
              labelText: 'Описание (необязательно)',
              hintText: 'О чем эта группа?',
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Privacy Settings Tile
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: scheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Тип группы',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Публичная'),
                      icon: Icon(Icons.public_rounded, size: 18),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Частная'),
                      icon: Icon(Icons.lock_outline_rounded, size: 18),
                    ),
                  ],
                  selected: <bool>{draft.isPrivate},
                  onSelectionChanged: (selection) {
                    HapticService.selection();
                    groupNotifier.setIsPrivate(selection.first);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  draft.isPrivate
                      ? 'Вступить в группу можно только по пригласительной ссылке.'
                      : 'Группа будет доступна в глобальном поиске NiosMess.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Selected Members Preview Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Участники (${draft.memberCount})',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Изменить'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (draft.selectedMembers.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                  color: scheme.outlineVariant,
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: draft.selectedMembers.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 64),
                itemBuilder: (BuildContext context, int index) {
                  final member = draft.selectedMembers[index];
                  return ListTile(
                    dense: true,
                    leading: PulseAvatar(
                      avatarUrl: member.avatarUrl,
                      name: member.displayName,
                      radius: 18,
                    ),
                    title: Text(
                      member.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: member.username.isNotEmpty
                        ? Text(
                            '@${member.username}',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                  );
                },
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Text(
                'Участники не выбраны. Вы сможете пригласить их позже по ссылке.',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 32),

          // Submit Button
          FilledButton(
            onPressed: groupState.isSubmitting ? null : _handleCreate,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
            ),
            child: groupState.isSubmitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: AppLoadingIndicator(size: 24),
                  )
                : const Text(
                    'Создать группу',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );

    if (isWide) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Card(
            margin: const EdgeInsets.all(24),
            elevation: 0,
            color: scheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              side: BorderSide(
                color: scheme.outlineVariant,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              child: content,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Параметры группы'),
      ),
      body: content,
    );
  }
}
