import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/chat_actions_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/search_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class CreateChatWizardView extends ConsumerStatefulWidget {
  const CreateChatWizardView({
    this.initialType,
    this.isDialog = false,
    this.onClose,
    this.onChatCreated,
    super.key,
  });

  final String? initialType;
  final bool isDialog;
  final VoidCallback? onClose;
  final ValueChanged<int>? onChatCreated;

  @override
  ConsumerState<CreateChatWizardView> createState() =>
      _CreateChatWizardViewState();
}

class _CreateChatWizardViewState extends ConsumerState<CreateChatWizardView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  int _step = 0; // 0: Information, 1: Members & Privacy
  late String _chatType;
  bool _isPublic = false;
  bool _commentsEnabled = true;
  bool _busy = false;

  final Set<int> _selectedUserIds = <int>{};
  final Map<int, String> _selectedUsernames = <int, String>{};
  final Map<int, String?> _selectedUserAvatars = <int, String?>{};

  String _searchQuery = '';

  static String _cleanUsername(String input) {
    final String trimmed = input.trim();
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }

  @override
  void initState() {
    super.initState();
    _chatType = widget.initialType == 'channel' ? 'channel' : 'group';
    _searchController.addListener(() {
      final String q = _searchController.text.trim();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
        ref.read(debouncedSearchProvider.notifier).search(q);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _usernameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _nameController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty ||
      _usernameController.text.trim().isNotEmpty ||
      _selectedUserIds.isNotEmpty;

  void _nextStep() {
    final String name = _nameController.text.trim();
    if (name.length < 3) {
      AppToast.showInfo(context, context.l10n.groupNameTooShort);
      return;
    }
    HapticService.tap();
    setState(() => _step = 1);
  }

  void _previousStep() {
    HapticService.tap();
    setState(() => _step = 0);
  }

  Future<void> _handleCloseRequest() async {
    if (_step == 1) {
      _previousStep();
      return;
    }
    if (!_hasChanges) {
      widget.onClose?.call();
      return;
    }
    final bool? confirm = await showAppConfirmDialog(
      context: context,
      title: context.l10n.dialogCancelChatCreationTitle,
      subtitle: context.l10n.dialogCancelChatCreationBody,
      confirmLabel: context.l10n.commonYes,
      cancelLabel: context.l10n.commonNo,
      icon: Icons.close_rounded,
    );
    if (confirm == true && mounted) {
      widget.onClose?.call();
    }
  }

  Future<void> _submit() async {
    if (_busy) return;

    final String name = _nameController.text.trim();
    if (name.length < 3) {
      AppToast.showInfo(context, context.l10n.groupNameTooShort);
      return;
    }

    if (_isPublic) {
      final String username = _cleanUsername(_usernameController.text);
      final RegExp rx = RegExp(r'^[A-Za-z0-9._]{3,32}$');
      if (!rx.hasMatch(username)) {
        AppToast.showInfo(context, context.l10n.groupUsernameRules);
        return;
      }
    }

    setState(() => _busy = true);
    HapticService.tap();

    try {
      final String? publicUsername =
          _isPublic ? _cleanUsername(_usernameController.text) : null;

      final ChatCreateResult? result = await ref
          .read(chatRepositoryProvider)
          .createChat(
            name: name,
            chatType: _chatType,
            description: _descriptionController.text.trim(),
            username: publicUsername,
            commentsEnabled: _chatType == 'channel' ? _commentsEnabled : null,
            isPrivate: !_isPublic,
          );

      if (result == null || result.chatId <= 0) {
        throw ApiException(statusCode: 0, message: 'Could not create chat');
      }

      if (_chatType == 'group' && _selectedUserIds.isNotEmpty) {
        await ref
            .read(chatRepositoryProvider)
            .inviteUsers(result.chatId, _selectedUserIds.toList());
      }

      await ref.read(chatsProvider.notifier).refresh();

      if (!mounted) return;
      AppToast.showSuccess(
        context,
        _chatType == 'channel'
            ? context.l10n.groupCreatedChannel
            : context.l10n.groupCreatedGroup,
      );
      widget.onChatCreated?.call(result.chatId);
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _handleCloseRequest();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(context, scheme, textTheme),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: M3SpringCurves.spatial,
              switchOutCurve: Curves.easeInCubic,
              child: _step == 0
                  ? _buildStep1Info(context, scheme, textTheme)
                  : _buildStep2MembersAndPrivacy(context, scheme, textTheme),
            ),
          ),
          _buildFooter(context, scheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final bool isChannel = _chatType == 'channel';
    final Color iconContainerColor =
        isChannel ? scheme.tertiaryContainer : scheme.primaryContainer;
    final Color iconColor =
        isChannel ? scheme.onTertiaryContainer : scheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.14),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (_step > 0) ...<Widget>[
                IconButton(
                  onPressed: _busy ? null : _previousStep,
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: context.l10n.groupBack,
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerLow,
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(38, 38),
                  ),
                ),
                const SizedBox(width: 10),
              ] else ...<Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconContainerColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isChannel ? Icons.campaign_rounded : Icons.groups_rounded,
                    size: 22,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isChannel
                          ? context.l10n.groupNewChannel
                          : context.l10n.groupNewGroup,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      _step == 0
                          ? 'Шаг 1 из 2: Основная информация'
                          : (isChannel
                              ? 'Шаг 2 из 2: Настройки канала'
                              : 'Шаг 2 из 2: Участники и доступ'),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _handleCloseRequest,
                icon: const Icon(Icons.close_rounded),
                tooltip: context.l10n.commonCancel,
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surfaceContainerLow,
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(38, 38),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List<Widget>.generate(2, (int index) {
              final bool active = index <= _step;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: M3SpringCurves.spatial,
                  margin: EdgeInsets.only(right: index == 0 ? 8 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: active ? scheme.primary : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Info(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return SingleChildScrollView(
      key: const ValueKey<int>(0),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Type selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _typeTab(
                    type: 'group',
                    icon: Icons.groups_rounded,
                    label: context.l10n.groupTypeGroup,
                    selected: _chatType == 'group',
                    scheme: scheme,
                    textTheme: textTheme,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _typeTab(
                    type: 'channel',
                    icon: Icons.campaign_rounded,
                    label: context.l10n.groupTypeChannel,
                    selected: _chatType == 'channel',
                    scheme: scheme,
                    textTheme: textTheme,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Live Hero preview card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: M3SpringCurves.spatial,
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _chatType == 'channel'
                        ? scheme.tertiaryContainer
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _chatType == 'channel'
                        ? Icons.campaign_rounded
                        : Icons.groups_rounded,
                    size: 26,
                    color: _chatType == 'channel'
                        ? scheme.onTertiaryContainer
                        : scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _nameController.text.trim().isEmpty
                            ? (_chatType == 'channel'
                                ? 'Название нового канала'
                                : 'Название новой группы')
                            : _nameController.text.trim(),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _chatType == 'channel'
                            ? 'Публичные публикации и новости'
                            : 'Совместное общение участников',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Name field
          TextField(
            controller: _nameController,
            onChanged: (String _) => setState(() {}),
            maxLength: 128,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.l10n.groupNameLabel,
              hintText: _chatType == 'channel'
                  ? 'Введите имя канала'
                  : 'Введите имя группы',
              prefixIcon: const Icon(Icons.edit_note_rounded),
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),

          // Description field
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 3,
            maxLength: 512,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _chatType == 'channel'
                  ? context.l10n.groupDescriptionChannelLabel
                  : context.l10n.groupDescriptionGroupLabel,
              hintText: _chatType == 'channel'
                  ? context.l10n.groupDescriptionChannelHint
                  : context.l10n.groupDescriptionGroupHint,
              prefixIcon: const Icon(Icons.notes_rounded),
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeTab({
    required String type,
    required IconData icon,
    required String label,
    required bool selected,
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    return GestureDetector(
      onTap: () {
        HapticService.tap();
        setState(() => _chatType = type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: M3SpringCurves.spatial,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2MembersAndPrivacy(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (_chatType == 'group') {
      return _buildGroupStep2(context, scheme, textTheme);
    } else {
      return _buildChannelStep2(context, scheme, textTheme);
    }
  }

  Widget _buildGroupStep2(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final List<ApiChatSummary> chats = ref.watch(chatsProvider).maybeWhen(
          data: (List<ApiChatSummary> list) => list,
          orElse: () => const <ApiChatSummary>[],
        );

    final List<ApiChatSummary> directContacts = chats
        .where((ApiChatSummary c) => c.chatType == 'direct')
        .toList(growable: false);

    return SingleChildScrollView(
      key: const ValueKey<int>(1),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Selected contacts chips
          if (_selectedUsernames.isNotEmpty) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Выбрано участников: ${_selectedUsernames.length}',
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedUsernames.entries.map((e) {
                      final int uid = e.key;
                      final String name = e.value;
                      final String? avatar = _selectedUserAvatars[uid];
                      return Chip(
                        avatar: PulseAvatar(
                          radius: 12,
                          name: name,
                          avatarUrl: avatar,
                        ),
                        label: Text(name, style: textTheme.labelMedium),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        onDeleted: () {
                          HapticService.tap();
                          setState(() {
                            _selectedUserIds.remove(uid);
                            _selectedUsernames.remove(uid);
                            _selectedUserAvatars.remove(uid);
                          });
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: scheme.surfaceContainerHighest,
                      );
                    }).toList(growable: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Search members input
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Поиск контактов или @username...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // Contact candidates
          Text(
            _searchQuery.isEmpty ? 'Недавние диалоги' : 'Результаты поиска',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 190),
            child: _searchQuery.isEmpty
                ? _buildDirectContactsList(directContacts, scheme, textTheme)
                : _buildGlobalSearchResults(scheme, textTheme),
          ),

          const SizedBox(height: 16),
          _privacySection(scheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildDirectContactsList(
    List<ApiChatSummary> contacts,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (contacts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'У вас пока нет недавних диалогов для быстрого добавления.',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: contacts.length,
        separatorBuilder: (BuildContext context, int index) => Divider(
          height: 1,
          indent: 56,
          color: scheme.outlineVariant.withValues(alpha: 0.12),
        ),
        itemBuilder: (BuildContext ctx, int index) {
          final ApiChatSummary contact = contacts[index];
          final bool isSelected = _selectedUserIds.contains(contact.id);

          return ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            leading: PulseAvatar(
              radius: 18,
              name: contact.name,
              avatarUrl: contact.avatarUrl,
            ),
            title: Text(
              contact.name,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: contact.username != null
                ? Text(
                    '@${contact.username}',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  )
                : null,
            trailing: Checkbox(
              value: isSelected,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              onChanged: (bool? val) {
                HapticService.tap();
                setState(() {
                  if (val == true) {
                    _selectedUserIds.add(contact.id);
                    _selectedUsernames[contact.id] = contact.name;
                    _selectedUserAvatars[contact.id] = contact.avatarUrl;
                  } else {
                    _selectedUserIds.remove(contact.id);
                    _selectedUsernames.remove(contact.id);
                    _selectedUserAvatars.remove(contact.id);
                  }
                });
              },
            ),
            onTap: () {
              HapticService.tap();
              setState(() {
                if (isSelected) {
                  _selectedUserIds.remove(contact.id);
                  _selectedUsernames.remove(contact.id);
                  _selectedUserAvatars.remove(contact.id);
                } else {
                  _selectedUserIds.add(contact.id);
                  _selectedUsernames[contact.id] = contact.name;
                  _selectedUserAvatars[contact.id] = contact.avatarUrl;
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildGlobalSearchResults(
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final AsyncValue<ApiSearchResult> searchAsync =
        ref.watch(debouncedSearchProvider);

    return searchAsync.when(
      data: (ApiSearchResult result) {
        if (result.users.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Пользователи по запросу «$_searchQuery» не найдены.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.12),
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: result.users.length,
            separatorBuilder: (BuildContext context, int index) => Divider(
              height: 1,
              indent: 56,
              color: scheme.outlineVariant.withValues(alpha: 0.12),
            ),
            itemBuilder: (BuildContext ctx, int index) {
              final ApiSearchUser u = result.users[index];
              final bool isSelected = _selectedUserIds.contains(u.id);

              return ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                leading: PulseAvatar(
                  radius: 18,
                  name: u.displayName.isNotEmpty ? u.displayName : u.username,
                  avatarUrl: u.avatarUrl,
                ),
                title: Text(
                  u.displayName.isNotEmpty ? u.displayName : u.username,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '@${u.username}',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                trailing: Checkbox(
                  value: isSelected,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  onChanged: (bool? val) {
                    HapticService.tap();
                    setState(() {
                      if (val == true) {
                        _selectedUserIds.add(u.id);
                        _selectedUsernames[u.id] =
                            u.displayName.isNotEmpty ? u.displayName : u.username;
                        _selectedUserAvatars[u.id] = u.avatarUrl;
                      } else {
                        _selectedUserIds.remove(u.id);
                        _selectedUsernames.remove(u.id);
                        _selectedUserAvatars.remove(u.id);
                      }
                    });
                  },
                ),
                onTap: () {
                  HapticService.tap();
                  setState(() {
                    if (isSelected) {
                      _selectedUserIds.remove(u.id);
                      _selectedUsernames.remove(u.id);
                      _selectedUserAvatars.remove(u.id);
                    } else {
                      _selectedUserIds.add(u.id);
                      _selectedUsernames[u.id] =
                          u.displayName.isNotEmpty ? u.displayName : u.username;
                      _selectedUserAvatars[u.id] = u.avatarUrl;
                    }
                  });
                },
              );
            },
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: const AppLoadingIndicator(size: 24),
      ),
      error: (Object error, StackTrace stackTrace) => Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'Не удалось выполнить поиск пользователей.',
          style: textTheme.bodySmall?.copyWith(color: scheme.error),
        ),
      ),
    );
  }

  Widget _buildChannelStep2(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return SingleChildScrollView(
      key: const ValueKey<int>(2),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _privacySection(scheme, textTheme),
          const SizedBox(height: 12),

          // Comments switch card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.comment_rounded,
                    color: scheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.groupEnableComments,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.groupEnableCommentsSubtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _commentsEnabled,
                  onChanged: (bool val) {
                    HapticService.tap();
                    setState(() => _commentsEnabled = val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacySection(ColorScheme scheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Доступ и приватность',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _privacyCard(
          selected: !_isPublic,
          icon: Icons.lock_rounded,
          title: context.l10n.groupPrivate,
          subtitle: _chatType == 'channel'
              ? 'Канал доступен только по защищенной ссылке'
              : context.l10n.groupPrivateSubtitle,
          scheme: scheme,
          textTheme: textTheme,
          onTap: () {
            HapticService.tap();
            setState(() => _isPublic = false);
          },
        ),
        const SizedBox(height: 8),
        _privacyCard(
          selected: _isPublic,
          icon: Icons.public_rounded,
          title: context.l10n.groupPublic,
          subtitle: _chatType == 'channel'
              ? 'Открыт в глобальном поиске и имеет ссылку'
              : context.l10n.groupPublicSubtitle,
          scheme: scheme,
          textTheme: textTheme,
          onTap: () {
            HapticService.tap();
            setState(() => _isPublic = true);
          },
        ),
        if (_isPublic) ...<Widget>[
          const SizedBox(height: 10),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: context.l10n.groupPublicUsername,
              hintText: 'channel_username',
              prefixText: '@',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              helperText: 'От 3 до 32 символов (латиница, цифры, _)',
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _privacyCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: M3SpringCurves.spatial,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.38)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.14),
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.18)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.14),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (_step > 0) ...<Widget>[
            OutlinedButton.icon(
              onPressed: _busy ? null : _previousStep,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(context.l10n.groupBack),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: PulseButton(
              label: _step == 0
                  ? context.l10n.groupContinue
                  : (_chatType == 'channel'
                      ? 'Создать канал'
                      : 'Создать группу'),
              icon: _step == 0
                  ? Icons.arrow_forward_rounded
                  : (_chatType == 'channel'
                      ? Icons.campaign_rounded
                      : Icons.check_circle_rounded),
              isLoading: _busy,
              onPressed: _busy ? null : (_step == 0 ? _nextStep : _submit),
            ),
          ),
        ],
      ),
    );
  }
}
