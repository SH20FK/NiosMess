import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/services/call_history_service.dart';
import 'package:pulse_flutter/core/services/favorite_contacts_service.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_error_formatter.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/search_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/centered_note.dart';
import 'package:pulse_flutter/widgets/common/user_search_picker_sheet.dart';
import 'package:pulse_flutter/widgets/contacts/call_log_view.dart';
import 'package:pulse_flutter/widgets/contacts/online_presence_radar.dart';
import 'package:pulse_flutter/widgets/profile/my_qr_code_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';

enum _ContactsMainTab { contacts, calls }

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  _ContactsMainTab _selectedTab = _ContactsMainTab.contacts;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _openingUsername;
  List<ApiChatSummary>? _cachedDirectContacts;

  @override
  void initState() {
    super.initState();
    _cachedDirectContacts = ref.read(cacheServiceProvider).getCachedContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ApiChatSummary> _recentDirectChats(List<ApiChatSummary> chats) {
    return chats
        .where((ApiChatSummary c) => c.chatType == 'direct')
        .toList(growable: false);
  }

  Map<String, List<ApiChatSummary>> _groupAlphabetically(
    List<ApiChatSummary> chats,
  ) {
    final Map<String, List<ApiChatSummary>> grouped =
        <String, List<ApiChatSummary>>{};

    for (final ApiChatSummary chat in chats) {
      final String trimmed = chat.name.trim();
      final String letter =
          trimmed.isEmpty ? '#' : trimmed[0].toUpperCase();
      final String key =
          RegExp(r'^[A-ZА-ЯЁ]').hasMatch(letter) ? letter : '#';
      grouped.putIfAbsent(key, () => <ApiChatSummary>[]).add(chat);
    }

    final List<String> sortedKeys = grouped.keys.toList()
      ..sort((String a, String b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });

    final Map<String, List<ApiChatSummary>> result =
        <String, List<ApiChatSummary>>{};
    for (final String k in sortedKeys) {
      final List<ApiChatSummary> list = grouped[k]!;
      list.sort((ApiChatSummary a, ApiChatSummary b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      result[k] = list;
    }
    return result;
  }

  Future<void> _openDirectChat(String username) async {
    final String normalized = username.trim();
    if (normalized.isEmpty) return;

    setState(() => _openingUsername = normalized);
    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .openDirectChatByUsername(normalized);
      if (result == null || result.chatId <= 0) {
        throw ApiException(
          statusCode: 0,
          message: 'Could not open direct chat',
        );
      }
      await ref.read(chatsProvider.notifier).refresh();
      if (!mounted) return;
      context.push('/chat/${result.chatId}');
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(context, error);
    } finally {
      if (mounted) setState(() => _openingUsername = null);
    }
  }

  void _showContactQuickActions(ApiChatSummary chat) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isFav =
        ref.read(favoriteContactsProvider).contains(chat.id);

    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: PulseAvatar(
                  radius: 22,
                  name: chat.name,
                  avatarUrl: chat.avatarUrl,
                ),
                title: Text(
                  chat.name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: chat.username != null && chat.username!.isNotEmpty
                    ? Text('@${chat.username}')
                    : null,
                trailing: IconButton(
                  onPressed: () {
                    ref
                        .read(favoriteContactsProvider.notifier)
                        .toggleFavorite(chat.id);
                    Navigator.of(ctx).pop();
                  },
                  icon: Icon(
                    isFav ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFav ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  tooltip: isFav
                      ? 'Удалить из избранных'
                      : 'Добавить в избранное',
                ),
              ),
              const Divider(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.chat_bubble_outline_rounded,
                      color: scheme.primary, size: 20),
                ),
                title: const Text('Открыть чат'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push('/chat/${chat.id}');
                },
              ),
              if (chat.username != null && chat.username!.isNotEmpty) ...<Widget>[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.phone_rounded,
                        color: scheme.primary, size: 20),
                  ),
                  title: const Text('Голосовой вызов'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/call/dm/${chat.username}?isVideo=0');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.videocam_rounded,
                        color: scheme.secondary, size: 20),
                  ),
                  title: const Text('Видеозвонок'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/call/dm/${chat.username}?isVideo=1');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person_outline_rounded,
                        color: scheme.onSurfaceVariant, size: 20),
                  ),
                  title: const Text('Информация о контакте'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/contact/${chat.username}');
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final UiSettingsState settings = ref.watch(uiSettingsProvider);
    final bool compact = settings.compactMode;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<List<ApiChatSummary>> chatsAsync = ref.watch(chatsProvider);
    final int missedCalls = ref.watch(missedCallsCountProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _selectedTab == _ContactsMainTab.contacts
              ? context.l10n.tabContacts
              : 'Звонки',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: scheme.onSurface,
          ),
        ),
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        actions: <Widget>[
          IconButton(
            onPressed: () {
              if (ref.read(uiSettingsProvider).haptics) {
                HapticService.tap();
              }
              MyQrCodeSheet.show(context);
            },
            icon: const Icon(Icons.qr_code_2_rounded),
            tooltip: 'Мой QR-код',
          ),
          IconButton(
            onPressed: () {
              if (ref.read(uiSettingsProvider).haptics) {
                HapticService.tap();
              }
              UserSearchPickerSheet.show(
                context,
                title: 'Новый контакт',
                onUserSelected: (ApiSearchUser user) {
                  _openDirectChat(user.username);
                },
              );
            },
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Добавить контакт',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // Top Segmented Switcher
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenHorizontalPadding,
                vertical: 6,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<_ContactsMainTab>(
                  segments: <ButtonSegment<_ContactsMainTab>>[
                    const ButtonSegment<_ContactsMainTab>(
                      value: _ContactsMainTab.contacts,
                      label: Text('Контакты'),
                      icon: Icon(Icons.people_alt_rounded, size: 18),
                    ),
                    ButtonSegment<_ContactsMainTab>(
                      value: _ContactsMainTab.calls,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text('Звонки'),
                          if (missedCalls > 0) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$missedCalls',
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onError,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      icon: const Icon(Icons.phone_rounded, size: 18),
                    ),
                  ],
                  selected: <_ContactsMainTab>{_selectedTab},
                  onSelectionChanged: (Set<_ContactsMainTab> newSelection) {
                    if (ref.read(uiSettingsProvider).haptics) {
                      HapticService.tap();
                    }
                    setState(() => _selectedTab = newSelection.first);
                  },
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return scheme.primaryContainer;
                      }
                      return scheme.surfaceContainerHigh;
                    }),
                    side: const WidgetStatePropertyAll<BorderSide>(
                      BorderSide.none,
                    ),
                    shape: WidgetStatePropertyAll<OutlinedBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content: Calls or Contacts
            Expanded(
              child: _selectedTab == _ContactsMainTab.calls
                  ? const CallLogView()
                  : _buildContactsTab(
                      auth: auth,
                      chatsAsync: chatsAsync,
                      compact: compact,
                      textTheme: textTheme,
                      scheme: scheme,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsTab({
    required AuthState auth,
    required AsyncValue<List<ApiChatSummary>> chatsAsync,
    required bool compact,
    required TextTheme textTheme,
    required ColorScheme scheme,
  }) {
    if (!auth.isAuthenticated) {
      return CenteredNote(context.l10n.contactsNotAuth);
    }

    final List<ApiChatSummary>? freshChats = chatsAsync.value;
    if (freshChats != null) {
      final List<ApiChatSummary> direct = _recentDirectChats(freshChats);
      _cachedDirectContacts = direct;
      ref.read(cacheServiceProvider).saveContacts(direct);
    }

    final List<ApiChatSummary> direct =
        _cachedDirectContacts ?? const <ApiChatSummary>[];

    return RefreshIndicator(
      onRefresh: () async {
        if (_searchQuery.trim().isNotEmpty) {
          ref
              .read(debouncedSearchProvider.notifier)
              .search(_searchQuery.trim());
        } else {
          await ref.read(chatsProvider.notifier).refresh();
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: <Widget>[
          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenHorizontalPadding,
                vertical: 8,
              ),
              child: SearchBar(
                controller: _searchController,
                onChanged: (String value) {
                  setState(() => _searchQuery = value);
                  if (value.trim().isNotEmpty) {
                    ref.read(debouncedSearchProvider.notifier).search(value);
                  } else {
                    ref.read(debouncedSearchProvider.notifier).clear();
                  }
                },
                hintText: context.l10n.contactsSearchHint,
                leading: const Icon(Icons.search_rounded),
                elevation: const WidgetStatePropertyAll<double>(0.0),
                backgroundColor:
                    WidgetStatePropertyAll<Color>(scheme.surfaceContainerHigh),
                trailing: <Widget>[
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        if (ref.read(uiSettingsProvider).haptics) {
                          HapticService.tap();
                        }
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        ref.read(debouncedSearchProvider.notifier).clear();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ),
          ),

          // If searching: show search results
          if (_searchQuery.trim().isNotEmpty)
            ..._buildSearchResultsSlivers(compact, textTheme, scheme)
          else ...<Widget>[
            // Quick Action Buttons Row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenHorizontalPadding,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    _quickActionCard(
                      icon: Icons.qr_code_2_rounded,
                      label: 'QR-код',
                      scheme: scheme,
                      textTheme: textTheme,
                      onTap: () {
                        if (ref.read(uiSettingsProvider).haptics) {
                          HapticService.tap();
                        }
                        MyQrCodeSheet.show(context);
                      },
                    ),
                    const SizedBox(width: 8),
                    _quickActionCard(
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Добавить',
                      scheme: scheme,
                      textTheme: textTheme,
                      onTap: () {
                        if (ref.read(uiSettingsProvider).haptics) {
                          HapticService.tap();
                        }
                        UserSearchPickerSheet.show(
                          context,
                          title: 'Поиск пользователя',
                          onUserSelected: (ApiSearchUser user) {
                            _openDirectChat(user.username);
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _quickActionCard(
                      icon: Icons.call_outlined,
                      label: 'Звонки',
                      scheme: scheme,
                      textTheme: textTheme,
                      onTap: () {
                        if (ref.read(uiSettingsProvider).haptics) {
                          HapticService.tap();
                        }
                        setState(() => _selectedTab = _ContactsMainTab.calls);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Online Presence Radar
            if (direct.isNotEmpty)
              SliverToBoxAdapter(
                child: OnlinePresenceRadar(directChats: direct),
              ),

            // Favorites section
            ..._buildFavoritesSlivers(direct, compact, textTheme, scheme),

            // Alphabetical Directory
            ..._buildAddressBookSlivers(
              direct,
              chatsAsync,
              compact,
              textTheme,
              scheme,
            ),
          ],

          SliverPadding(
            padding: EdgeInsets.only(
              bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 22, color: scheme.primary),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFavoritesSlivers(
    List<ApiChatSummary> direct,
    bool compact,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    final Set<int> favIds = ref.watch(favoriteContactsProvider);
    final List<ApiChatSummary> favChats = direct
        .where((ApiChatSummary c) => favIds.contains(c.id))
        .toList(growable: false);

    if (favChats.isEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.screenHorizontalPadding,
            16,
            AppConstants.screenHorizontalPadding,
            8,
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.star_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'Избранные',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${favChats.length})',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenHorizontalPadding,
        ),
        sliver: SliverList.separated(
          itemCount: favChats.length,
          separatorBuilder: (_, _) => SizedBox(height: compact ? 6 : 8),
          itemBuilder: (BuildContext context, int index) {
            final ApiChatSummary chat = favChats[index];
            return _contactCard(
              chat: chat,
              isFavorite: true,
              compact: compact,
              textTheme: textTheme,
              scheme: scheme,
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildAddressBookSlivers(
    List<ApiChatSummary> direct,
    AsyncValue<List<ApiChatSummary>> chatsAsync,
    bool compact,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    if (direct.isEmpty) {
      if (chatsAsync.isLoading) {
        return const <Widget>[
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: AppConstants.screenHorizontalPadding,
              vertical: 16,
            ),
            sliver: SliverToBoxAdapter(child: ChatListSkeleton(count: 4)),
          ),
        ];
      }
      return <Widget>[
        SliverFillRemaining(
          child: CenteredNote(context.l10n.contactsNoRecentFull),
        ),
      ];
    }

    final Map<String, List<ApiChatSummary>> grouped =
        _groupAlphabetically(direct);
    final Set<int> favIds = ref.watch(favoriteContactsProvider);
    final List<Widget> slivers = <Widget>[];

    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.screenHorizontalPadding,
            18,
            AppConstants.screenHorizontalPadding,
            8,
          ),
          child: Row(
            children: <Widget>[
              Text(
                'Все контакты',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${direct.length}',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    for (final MapEntry<String, List<ApiChatSummary>> entry
        in grouped.entries) {
      // Section header letter
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenHorizontalPadding,
              12,
              AppConstants.screenHorizontalPadding,
              6,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.key,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Section items
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenHorizontalPadding,
          ),
          sliver: SliverList.separated(
            itemCount: entry.value.length,
            separatorBuilder: (_, _) => SizedBox(height: compact ? 6 : 8),
            itemBuilder: (BuildContext context, int index) {
              final ApiChatSummary chat = entry.value[index];
              final bool isFav = favIds.contains(chat.id);
              return _contactCard(
                chat: chat,
                isFavorite: isFav,
                compact: compact,
                textTheme: textTheme,
                scheme: scheme,
              );
            },
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _contactCard({
    required ApiChatSummary chat,
    required bool isFavorite,
    required bool compact,
    required TextTheme textTheme,
    required ColorScheme scheme,
  }) {
    final List<ApiBadge> badges =
        chat.partnerBadges.take(2).toList(growable: false);
    final int hiddenBadgeCount = chat.partnerBadges.length - badges.length;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: chat.username == null || chat.username!.isEmpty
            ? () => context.push('/chat/${chat.id}')
            : () => context.push('/contact/${chat.username}'),
        onLongPress: () {
          if (ref.read(uiSettingsProvider).haptics) {
            HapticService.confirm();
          }
          _showContactQuickActions(chat);
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: compact ? 8 : 11,
          ),
          child: Row(
            children: <Widget>[
              // Avatar
              PulseAvatar(
                radius: 22,
                name: chat.name,
                avatarUrl: chat.avatarUrl,
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            chat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (badges.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          Wrap(
                            spacing: 3,
                            children: <Widget>[
                              ...badges.map(
                                (ApiBadge badge) => BadgeChip(
                                  id: badge.id,
                                  name: badge.name,
                                  icon: badge.icon,
                                  color: badge.color,
                                  interactive: false,
                                  mode: BadgeResolver.isStatusBadge(badge)
                                      ? BadgeDisplayMode.statusIcon
                                      : BadgeDisplayMode.infoLabel,
                                ),
                              ),
                              if (hiddenBadgeCount > 0)
                                BadgeOverflowChip(count: hiddenBadgeCount),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chat.username != null && chat.username!.isNotEmpty
                          ? '@${chat.username}'
                          : (chat.lastMessage?.content ?? 'Чат'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons: Voice call, Video call, Chat
              if (chat.username != null && chat.username!.isNotEmpty) ...<Widget>[
                IconButton(
                  onPressed: () {
                    if (ref.read(uiSettingsProvider).haptics) {
                      HapticService.reaction();
                    }
                    context.push('/call/dm/${chat.username}?isVideo=0');
                  },
                  icon: const Icon(Icons.phone_outlined, size: 20),
                  tooltip: 'Позвонить',
                  color: scheme.primary,
                ),
                IconButton(
                  onPressed: () {
                    if (ref.read(uiSettingsProvider).haptics) {
                      HapticService.reaction();
                    }
                    context.push('/call/dm/${chat.username}?isVideo=1');
                  },
                  icon: const Icon(Icons.videocam_outlined, size: 20),
                  tooltip: 'Видеозвонок',
                  color: scheme.secondary,
                ),
              ] else ...<Widget>[
                IconButton(
                  onPressed: () {
                    if (ref.read(uiSettingsProvider).haptics) {
                      HapticService.reaction();
                    }
                    context.push('/chat/${chat.id}');
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  tooltip: 'Открыть чат',
                  color: scheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSearchResultsSlivers(
    bool compact,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    final AsyncValue<ApiSearchResult> resultsAsync =
        ref.watch(debouncedSearchProvider);

    return resultsAsync.when(
      data: (ApiSearchResult results) {
        if (results.isEmpty) {
          return <Widget>[
            SliverFillRemaining(
              child: CenteredNote(context.l10n.contactsNoMatches),
            ),
          ];
        }

        final List<Widget> children = <Widget>[];

        if (results.users.isNotEmpty) {
          children.add(
            _resultHeader(context, context.l10n.contactsUsers, results.users.length),
          );
          children.add(const SizedBox(height: 8));
          for (final ApiSearchUser user in results.users) {
            final bool opening = _openingUsername == user.username;
            children.add(_userTile(user, opening, compact, textTheme, scheme));
            children.add(SizedBox(height: compact ? 6 : 8));
          }
        }

        if (results.chats.isNotEmpty) {
          children.add(
            _resultHeader(context, context.l10n.contactsChats, results.chats.length),
          );
          children.add(const SizedBox(height: 8));
          for (final ApiSearchChat chat in results.chats) {
            children.add(_chatTile(chat, textTheme, scheme));
            children.add(const SizedBox(height: 8));
          }
        }

        if (results.messages.isNotEmpty) {
          children.add(
            _resultHeader(
              context,
              context.l10n.contactsMessages,
              results.messages.length,
            ),
          );
          children.add(const SizedBox(height: 8));
          for (final ApiSearchMessage message in results.messages) {
            children.add(_messageTile(message, textTheme, scheme));
            children.add(const SizedBox(height: 8));
          }
        }

        return <Widget>[
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenHorizontalPadding,
            ),
            sliver: SliverList(delegate: SliverChildListDelegate(children)),
          ),
        ];
      },
      loading: () => const <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: AppConstants.screenHorizontalPadding,
          ),
          sliver: SliverToBoxAdapter(child: ChatListSkeleton(count: 4)),
        ),
      ],
      error: (Object error, StackTrace _) => <Widget>[
        SliverFillRemaining(
          child: CenteredNote(AppErrorFormatter.format(error).toString()),
        ),
      ],
    );
  }

  Widget _userTile(
    ApiSearchUser user,
    bool opening,
    bool compact,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    final List<ApiBadge> visibleBadges =
        user.badges.take(3).toList(growable: false);
    final int hiddenBadgeCount = user.badges.length - visibleBadges.length;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => context.push('/contact/${user.username}'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: compact ? 8 : 12,
          ),
          child: Row(
            children: <Widget>[
              PulseAvatar(
                radius: 22,
                name: user.displayName.isEmpty ? user.username : user.displayName,
                avatarUrl: user.avatarUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            user.displayName.isEmpty
                                ? '@${user.username}'
                                : user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (visibleBadges.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          Wrap(
                            spacing: 3,
                            children: <Widget>[
                              ...visibleBadges.map(
                                (ApiBadge badge) => BadgeChip(
                                  id: badge.id,
                                  name: badge.name,
                                  icon: badge.icon,
                                  color: badge.color,
                                  interactive: false,
                                ),
                              ),
                              if (hiddenBadgeCount > 0)
                                BadgeOverflowChip(count: hiddenBadgeCount),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (opening)
                const AppLoadingIndicator(size: 20)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      onPressed: () {
                        if (ref.read(uiSettingsProvider).haptics) {
                          HapticService.reaction();
                        }
                        context.push('/call/dm/${user.username}?isVideo=0');
                      },
                      icon: const Icon(Icons.phone_outlined, size: 20),
                      tooltip: 'Позвонить',
                      color: scheme.primary,
                    ),
                    IconButton(
                      onPressed: () {
                        if (ref.read(uiSettingsProvider).haptics) {
                          HapticService.reaction();
                        }
                        _openDirectChat(user.username);
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 20),
                      tooltip: context.l10n.contactsChat,
                      color: scheme.primary,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chatTile(
    ApiSearchChat chat,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          if (ref.read(uiSettingsProvider).haptics) {
            HapticService.reaction();
          }
          context.push('/chat/${chat.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: <Widget>[
              PulseAvatar(
                radius: 18,
                name: chat.name,
                avatarUrl: chat.avatarUrl,
                fallbackColor: scheme.secondaryContainer,
                textColor: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(chat.name, style: textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '@${chat.username ?? '-'} • ${context.l10n.contactsMembersCount(chat.membersCount)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageTile(
    ApiSearchMessage message,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () =>
            context.push('/chat/${message.chatId}?highlight=${message.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message.senderDisplayName,
                style: textTheme.labelLarge?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 3),
              Text(
                message.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultHeader(BuildContext context, String title, int count) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
