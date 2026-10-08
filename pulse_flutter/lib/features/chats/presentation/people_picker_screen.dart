import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/navigation/direct_chat_navigator.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/features/chats/application/people_picker_controller.dart';
import 'package:pulse_flutter/features/chats/domain/member_candidate.dart';
import 'package:pulse_flutter/widgets/empty_state_widget.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class PeoplePickerScreen extends ConsumerStatefulWidget {
  const PeoplePickerScreen({
    this.mode = PeoplePickerMode.direct,
    super.key,
  });

  final PeoplePickerMode mode;

  @override
  ConsumerState<PeoplePickerScreen> createState() => _PeoplePickerScreenState();
}

class _PeoplePickerScreenState extends ConsumerState<PeoplePickerScreen> {
  late final TextEditingController _searchController;
  late final String _sessionId;
  late final PeoplePickerKey _pickerKey;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _sessionId = 'picker_${DateTime.now().millisecondsSinceEpoch}';
    _pickerKey = PeoplePickerKey(sessionId: _sessionId, mode: widget.mode);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCandidateSelected(MemberCandidate candidate) async {
    if (_navigating) return;
    _navigating = true;
    HapticService.tap();

    final bool isSecret = widget.mode == PeoplePickerMode.secret;
    final int? chatId = await navigateToDirectChat(
      context,
      ref,
      username: candidate.username,
      userId: candidate.userId,
      isSecret: isSecret,
      displayName: candidate.displayName,
      avatarUrl: candidate.avatarUrl,
    );

    if (!mounted) return;
    _navigating = false;

    if (chatId == null || (!isSecret && chatId <= 0)) {
      AppToast.showError(
        context,
        isSecret
            ? context.l10n.secretCreateFailed
            : 'Не удалось открыть диалог',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final state = ref.watch(peoplePickerControllerProvider(_pickerKey));
    final controller =
        ref.read(peoplePickerControllerProvider(_pickerKey).notifier);

    final bool isSecret = widget.mode == PeoplePickerMode.secret;
    final String titleText =
        isSecret ? 'Новый секретный чат' : 'Новое сообщение';
    final String subtitleText = isSecret
        ? 'Сквозное Double Ratchet шифрование'
        : 'Выберите собеседника или найдите по @id';

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_searchController.text.isNotEmpty) {
              _searchController.clear();
              controller.setQuery('');
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (isSecret) ...<Widget>[
                  Icon(Icons.lock_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                ],
                Text(
                  titleText,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              subtitleText,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: <Widget>[
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: controller.setQuery,
                  decoration: InputDecoration(
                    hintText: 'Имя или @username',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              controller.setQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: scheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              if (state.isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: AppLoadingIndicator(size: 20),
                  ),
                ),

              // Content View
              Expanded(
                child: state.hasQuery
                    ? _buildSearchResults(state, controller, scheme, textTheme)
                    : _buildInitialView(state, scheme, textTheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialView(
    PeoplePickerState state,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        // Quick Actions for direct mode
        if (widget.mode == PeoplePickerMode.direct) ...<Widget>[
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.group_add_rounded, color: scheme.onPrimaryContainer),
            ),
            title: const Text('Новая группа', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Чат для нескольких участников'),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/new-group/members');
            },
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.tertiaryContainer,
              child: Icon(Icons.campaign_rounded, color: scheme.onTertiaryContainer),
            ),
            title: const Text('Новый канал', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Публикации для аудитории'),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/new-channel');
            },
          ),
          const Divider(height: 16, indent: 72),
        ],

        if (state.recentCandidates.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Недавние собеседники',
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...state.recentCandidates.map((c) => _buildCandidateTile(c, scheme, textTheme)),
        ] else if (widget.mode == PeoplePickerMode.secret) ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: EmptyStateWidget(
              icon: Icons.shield_rounded,
              title: 'Секретный диалог',
              subtitle: 'Введите @username собеседника, чтобы начать зашифрованную переписку без следов на сервере',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchResults(
    PeoplePickerState state,
    PeoplePickerController controller,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (state.searchResults.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.searchResults.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
        itemBuilder: (BuildContext context, int index) {
          final candidate = state.searchResults[index];
          return _buildCandidateTile(candidate, scheme, textTheme);
        },
      );
    }

    if (!state.isSearching) {
      final String rawQuery = state.query.replaceFirst(RegExp(r'^@'), '');
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        children: <Widget>[
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.alternate_email_rounded, color: scheme.onPrimaryContainer),
            ),
            title: Text('Найти @$rawQuery', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Проверить точный юзернейм на сервере'),
            onTap: () async {
              final resolved = await controller.resolveHandle(rawQuery);
              if (resolved != null) {
                _handleCandidateSelected(resolved);
              } else if (mounted) {
                AppToast.showInfo(context, 'Пользователь @$rawQuery не найден');
              }
            },
          ),
          const SizedBox(height: 24),
          EmptyStateWidget(
            icon: Icons.person_off_rounded,
            title: 'Ничего не найдено',
            subtitle: 'Пользователь по запросу «${state.query}» не найден',
          ),
        ],
      );
    }

    return const Center(child: AppLoadingIndicator());
  }

  Widget _buildCandidateTile(
    MemberCandidate candidate,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: PulseAvatar(
        radius: 22,
        name: candidate.displayName,
        avatarUrl: candidate.avatarUrl,
      ),
      title: Text(
        candidate.displayName,
        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: candidate.username.isNotEmpty
          ? Text(
              '@${candidate.username}',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: () => _handleCandidateSelected(candidate),
    );
  }
}
