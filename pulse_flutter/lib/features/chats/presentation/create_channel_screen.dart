import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class CreateChannelScreen extends ConsumerStatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  ConsumerState<CreateChannelScreen> createState() =>
      _CreateChannelScreenState();
}

class _CreateChannelScreenState extends ConsumerState<CreateChannelScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isPrivate = false;
  bool _commentsEnabled = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    HapticService.tap();

    try {
      final repo = ref.read(chatRepositoryProvider);
      final rawUsername = _usernameController.text.trim();
      final slug = rawUsername.replaceFirst(RegExp(r'^@'), '');

      final result = await repo.createChat(
        name: _nameController.text.trim(),
        chatType: 'channel',
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        username: slug.isNotEmpty ? slug : null,
        commentsEnabled: _commentsEnabled,
        isPrivate: _isPrivate,
      );

      if (!mounted) return;

      if (result != null && result.chatId > 0) {
        ref.invalidate(chatsProvider);
        AppToast.showSuccess(context, 'Канал успешно создан');
        context.go('/chat/${result.chatId}');
      } else {
        setState(() => _isSubmitting = false);
        AppToast.showError(
          context,
          'Не удалось создать канал. Возможно, такой юзернейм уже занят.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppToast.showError(context, 'Не удалось создать канал');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
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
              // Channel Avatar Placeholder (Squircle M3E)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(
                  Icons.campaign_rounded,
                  size: 32,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              // Channel Name
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  maxLength: 64,
                  decoration: InputDecoration(
                    labelText: 'Название канала *',
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

          // Username / Public link
          if (!_isPrivate)
            Column(
              children: <Widget>[
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  maxLength: 32,
                  decoration: InputDecoration(
                    labelText: 'Юзернейм канала *',
                    hintText: 'channel_username',
                    prefixText: '@',
                    counterText: '',
                    filled: true,
                    fillColor: scheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (_isPrivate) return null;
                    final trimmed =
                        value?.trim().replaceFirst(RegExp(r'^@'), '') ?? '';
                    if (trimmed.length < 3) {
                      return 'Не менее 3 символов';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
                      return 'Допустимы латиница, цифры, _ и -';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),

          // Description field
          TextFormField(
            controller: _descController,
            maxLines: 3,
            maxLength: 255,
            decoration: InputDecoration(
              labelText: 'Описание канала',
              hintText: 'О чем будет ваш канал?',
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Privacy Settings Segmented Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Тип канала',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Публичный'),
                      icon: Icon(Icons.public_rounded, size: 18),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Частный'),
                      icon: Icon(Icons.lock_outline_rounded, size: 18),
                    ),
                  ],
                  selected: <bool>{_isPrivate},
                  onSelectionChanged: (selection) {
                    HapticService.selection();
                    setState(() => _isPrivate = selection.first);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _isPrivate
                      ? 'Вступить в канал можно только по пригласительной ссылке.'
                      : 'Публичные каналы доступны в поиске и по постоянной ссылке.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Comments enabled switch
          SwitchListTile(
            value: _commentsEnabled,
            onChanged: (val) {
              HapticService.selection();
              setState(() => _commentsEnabled = val);
            },
            title: const Text('Разрешить комментарии к постам'),
            subtitle: Text(
              _commentsEnabled
                  ? 'К каждому посту автоматически создается ветка обсуждений.'
                  : 'Подписчики не смогут комментировать публикации.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            tileColor: scheme.surfaceContainerLow,
          ),
          const SizedBox(height: 32),

          // Submit Button
          FilledButton(
            onPressed: _isSubmitting ? null : _handleCreate,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: AppLoadingIndicator(size: 24),
                  )
                : const Text(
                    'Создать канал',
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
                color: scheme.outlineVariant.withValues(alpha: 0.2),
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
        title: const Text('Новый канал'),
      ),
      body: content,
    );
  }
}
