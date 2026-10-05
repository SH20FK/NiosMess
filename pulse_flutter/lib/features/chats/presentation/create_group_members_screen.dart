import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/features/chats/application/create_group_controller.dart';
import 'package:pulse_flutter/features/chats/application/people_picker_controller.dart';
import 'package:pulse_flutter/features/chats/domain/member_candidate.dart';
import 'package:pulse_flutter/widgets/empty_state_widget.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class CreateGroupMembersScreen extends ConsumerStatefulWidget {
  const CreateGroupMembersScreen({super.key});

  @override
  ConsumerState<CreateGroupMembersScreen> createState() =>
      _CreateGroupMembersScreenState();
}

class _CreateGroupMembersScreenState
    extends ConsumerState<CreateGroupMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  static const PeoplePickerKey _pickerKey = PeoplePickerKey(
    sessionId: 'create-group-members',
    mode: PeoplePickerMode.direct,
  );

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final pickerState = ref.watch(peoplePickerControllerProvider(_pickerKey));
    final pickerNotifier =
        ref.read(peoplePickerControllerProvider(_pickerKey).notifier);

    final groupState = ref.watch(createGroupControllerProvider);
    final groupNotifier = ref.read(createGroupControllerProvider.notifier);
    final selected = groupState.draft.selectedMembers;
    final selectedIds = selected.map((m) => m.userId).toSet();

    final bool isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    Widget body = Column(
      children: <Widget>[
        // Search Input Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            autofocus: false,
            onChanged: pickerNotifier.setQuery,
            decoration: InputDecoration(
              hintText: 'Поиск по имени или @username...',
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              suffixIcon: pickerState.hasQuery
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        pickerNotifier.setQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.full),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
        ),

        // Selected Members Horizontal Strip
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          child: selected.isNotEmpty
              ? Container(
                  height: 96,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    border: Border(
                      bottom: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: selected.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (BuildContext context, int index) {
                      final member = selected[index];
                      return _SelectedMemberItem(
                        candidate: member,
                        onRemove: () {
                          HapticService.selection();
                          groupNotifier.removeMember(member.userId);
                        },
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Candidate List or Search Results
        Expanded(
          child: pickerState.isSearching
              ? const Center(
                  child: AppLoadingIndicator(size: 36),
                )
              : pickerState.hasQuery
                  ? _buildSearchResults(
                      pickerState,
                      selectedIds,
                      groupNotifier,
                      scheme,
                      textTheme,
                    )
                  : _buildRecentList(
                      pickerState,
                      selectedIds,
                      groupNotifier,
                      scheme,
                      textTheme,
                    ),
        ),
      ],
    );

    if (isWide) {
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
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
              child: body,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Новая группа'),
            Text(
              selected.isEmpty
                  ? 'Добавьте участников'
                  : 'Выбрано: ${selected.length}',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.tonalIcon(
                onPressed: () {
                  HapticService.tap();
                  context.push('/new-group/details');
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text('Далее (${selected.length})'),
              ),
            ),
        ],
      ),
      body: body,
      floatingActionButton: selected.isNotEmpty && !isWide
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticService.tap();
                context.push('/new-group/details');
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text('Далее (${selected.length})'),
            )
          : null,
    );
  }

  Widget _buildRecentList(
    PeoplePickerState state,
    Set<int> selectedIds,
    CreateGroupController groupNotifier,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final recent = state.recentCandidates;
    if (recent.isEmpty) {
      return const Center(
        child: EmptyStateWidget(
          icon: Icons.people_outline_rounded,
          title: 'Нет контактов',
          subtitle: 'Найдите пользователей через строку поиска выше',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: recent.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 72),
      itemBuilder: (BuildContext context, int index) {
        final candidate = recent[index];
        final isSelected = selectedIds.contains(candidate.userId);
        return _MemberSelectionTile(
          candidate: candidate,
          isSelected: isSelected,
          onTap: () {
            HapticService.selection();
            groupNotifier.toggleMember(candidate);
          },
        );
      },
    );
  }

  Widget _buildSearchResults(
    PeoplePickerState state,
    Set<int> selectedIds,
    CreateGroupController groupNotifier,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (state.searchResults.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.searchResults.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 72),
        itemBuilder: (BuildContext context, int index) {
          final candidate = state.searchResults[index];
          final isSelected = selectedIds.contains(candidate.userId);
          return _MemberSelectionTile(
            candidate: candidate,
            isSelected: isSelected,
            onTap: () {
              HapticService.selection();
              groupNotifier.toggleMember(candidate);
            },
          );
        },
      );
    }

    return Center(
      child: EmptyStateWidget(
        icon: Icons.search_off_rounded,
        title: 'Ничего не найдено',
        subtitle: 'Попробуйте изменить поисковый запрос',
      ),
    );
  }
}

class _SelectedMemberItem extends StatelessWidget {
  const _SelectedMemberItem({
    required this.candidate,
    required this.onRemove,
  });

  final MemberCandidate candidate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Stack(
      children: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PulseAvatar(
              avatarUrl: candidate.avatarUrl,
              name: candidate.displayName,
              radius: 24,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 56,
              child: Text(
                candidate.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberSelectionTile extends StatelessWidget {
  const _MemberSelectionTile({
    required this.candidate,
    required this.isSelected,
    required this.onTap,
  });

  final MemberCandidate candidate;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ListTile(
      onTap: onTap,
      leading: PulseAvatar(
        avatarUrl: candidate.avatarUrl,
        name: candidate.displayName,
        radius: 23,
      ),
      title: Text(
        candidate.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.titleMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: candidate.username.isNotEmpty
          ? Text(
              '@${candidate.username}',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: 2,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check_rounded,
                size: 16,
                color: scheme.onPrimary,
              )
            : null,
      ),
    );
  }
}
