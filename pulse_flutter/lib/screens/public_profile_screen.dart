import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/navigation/direct_chat_navigator.dart';
import 'package:pulse_flutter/core/services/favorite_contacts_service.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/repositories/report_repository.dart';
import 'package:pulse_flutter/core/utils/bot_detector.dart';
import 'package:pulse_flutter/providers/chat_muted_provider.dart';
import 'package:pulse_flutter/screens/calls/outgoing_call_screen.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/profile/my_qr_code_sheet.dart';
import 'package:pulse_flutter/widgets/profile/profile_shared_media_tab_view.dart';
import 'package:pulse_flutter/widgets/profile/working_hours_widget.dart';
import 'package:pulse_flutter/widgets/profile_header_delegate.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({required this.username, super.key});

  final String username;

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  ApiProfile? _profile;
  bool _loading = false;
  String? _error;
  int? _resolvedChatId;
  ActionPhase _messagePhase = ActionPhase.idle;
  bool _isMutedLocally = false;

  @override
  void initState() {
    super.initState();
    _checkCacheAndLoad();
  }

  @override
  void didUpdateWidget(covariant PublicProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username.toLowerCase() != widget.username.toLowerCase()) {
      setState(() {
        _profile = null;
        _resolvedChatId = null;
        _error = null;
        _messagePhase = ActionPhase.idle;
      });
      _checkCacheAndLoad();
    }
  }

  void _checkCacheAndLoad() {
    final String targetUser = widget.username.trim().toLowerCase();

    // 1. If self profile, redirect to main profile tab
    final auth = ref.read(authProvider);
    final String? myUsername =
        auth.profile?.username ?? auth.session?.username;
    if (myUsername != null &&
        myUsername.trim().toLowerCase() == targetUser) {
      _profile = auth.profile;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/main/profile');
      });
      return;
    }

    // 2. Try local cache box strictly for this username
    final cached =
        ref.read(cacheServiceProvider).getCachedProfile(widget.username);
    if (cached != null && cached.username.trim().toLowerCase() == targetUser) {
      _profile = cached;
    }

    // 3. Find existing direct chat in local state (zero network requests)
    final List<ApiChatSummary> chats =
        ref.read(chatsProvider).value ?? const <ApiChatSummary>[];
    for (final ApiChatSummary c in chats) {
      if (c.chatType == 'direct' &&
          c.username != null &&
          c.username!.trim().toLowerCase() == targetUser) {
        _resolvedChatId = c.id;
        _profile ??= ApiProfile(
          id: c.id,
          username: c.username!,
          displayName: c.name,
          bio: '',
          avatarUrl: c.avatarUrl,
          isOnline: c.isOnline,
        );
        break;
      }
    }

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_profile == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final ApiProfile profile = await ref
          .read(authRepositoryProvider)
          .getPublicProfile(widget.username);

      if (!mounted) return;
      if (profile.username.trim().toLowerCase() ==
          widget.username.trim().toLowerCase()) {
        // If profile is mine, redirect to self profile tab
        final auth = ref.read(authProvider);
        final int? myId = auth.profile?.id ?? auth.session?.userId;
        if (myId != null && myId == profile.id) {
          if (mounted) context.go('/main/profile');
          return;
        }

        // Check matching chat in local provider
        int? matchedChatId = _resolvedChatId;
        final List<ApiChatSummary> chats =
            ref.read(chatsProvider).value ?? const <ApiChatSummary>[];
        for (final ApiChatSummary c in chats) {
          if (c.chatType == 'direct' &&
              c.username != null &&
              c.username!.trim().toLowerCase() ==
                  profile.username.trim().toLowerCase()) {
            matchedChatId = c.id;
            break;
          }
        }

        setState(() {
          _profile = profile;
          _resolvedChatId = matchedChatId;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_profile == null) {
          final String errStr = e.toString().toLowerCase();
          if (errStr.contains('timed out') ||
              errStr.contains('socketexception')) {
            _error = context.l10n.profileNetworkError;
          } else {
            _error = context.l10n.profileLoadFailed;
          }
        }
      });
    }
  }

  Future<void> _handleMessageTap(ApiProfile profile) async {
    HapticService.tap();
    if (_messagePhase == ActionPhase.pending) return;

    setState(() {
      _messagePhase = ActionPhase.pending;
    });

    final int? chatId = await navigateToDirectChat(
      context,
      ref,
      username: profile.username,
      userId: profile.id,
      knownChatId: _resolvedChatId,
    );

    if (!mounted) return;

    setState(() {
      if (chatId != null && chatId > 0) {
        _resolvedChatId = chatId;
        _messagePhase = ActionPhase.idle;
      } else {
        _messagePhase = ActionPhase.idle;
        AppToast.showError(context, context.l10n.profileLoadFailed);
      }
    });
  }

  Future<void> _handleSecretChatTap(ApiProfile profile) async {
    HapticService.tap();
    AppToast.showInfo(context, context.l10n.profileConnectingDirect);

    final int? chatId = await navigateToDirectChat(
      context,
      ref,
      username: profile.username,
      userId: profile.id,
      isSecret: true,
    );

    if (!mounted) return;
    if (chatId != null && chatId > 0) {
      setState(() {
        _resolvedChatId = chatId;
      });
    } else {
      AppToast.showError(context, 'Не удалось создать секретный чат');
    }
  }

  void _handleCallTap(ApiProfile profile, {required bool isVideo}) {
    HapticService.tap();
    context.push(
      '/call/outgoing',
      extra: OutgoingCallArgs(
        username: profile.username,
        displayName: profile.displayName,
        avatarUrl: profile.avatarUrl,
        chatId: _resolvedChatId,
        isVideo: isVideo,
      ),
    );
  }

  void _handleShareQrTap(ApiProfile profile) {
    HapticService.tap();
    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) => MyQrCodeSheet(
        username: profile.username,
        displayName: profile.displayName,
        avatarUrl: profile.avatarUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AuthState auth = ref.watch(authProvider);
    final AppRadiiTheme radii = AppRadii.of(context);

    if (_loading && _profile == null) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: Text(context.l10n.profileTitle),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/main/chats');
              }
            },
          ),
        ),
        body: Center(
          child: AppLoadingIndicator(color: scheme.primary),
        ),
      );
    }

    if (_error != null && _profile == null) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: Text(context.l10n.profileTitle),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/main/chats');
              }
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.person_off_rounded,
                  size: 56,
                  color: scheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: _loadProfile,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ApiProfile profile = _profile!;
    final bool isMe = auth.profile?.id == profile.id;

    final List<ApiChatSummary> chats =
        ref.watch(chatsProvider).value ?? const <ApiChatSummary>[];
    ApiChatSummary? matchingChat;
    for (final ApiChatSummary c in chats) {
      if (c.chatType == 'direct' &&
          c.username != null &&
          c.username!.trim().toLowerCase() ==
              profile.username.trim().toLowerCase()) {
        matchingChat = c;
        break;
      }
    }

    final bool isOnline = profile.isOnline || (matchingChat?.isOnline ?? false);
    final String statusText = _computeStatusText(profile, isOnline);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          // ── Collapsing Hero Header ─────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: ProfileHeaderDelegate(
              name: profile.displayName,
              username: profile.username,
              avatarUrl: profile.avatarUrl,
              badges: profile.badges,
              statusText: statusText,
              isOnline: isOnline,
              isMe: isMe,
              topInset: MediaQuery.paddingOf(context).top,
              heroTag: _resolvedChatId != null
                  ? 'chat_avatar_$_resolvedChatId'
                  : (profile.username.isNotEmpty ? 'profile_avatar_${profile.username}' : null),
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/main/chats');
                }
              },
              onMore: isMe ? null : () => _showMoreActionsMenu(profile),
            ),
          ),

          // ── Body Content ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: Breakpoints.medium),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: 32 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // ── Blocked Banner ───────────────────────────────
                      if (!isMe) ...[
                        Builder(
                          builder: (BuildContext ctx) {
                            final bool isBlockedByMe = ref
                                    .watch(privacyProvider)
                                    .isUserBlocked(profile.id) ||
                                profile.isBlockedByMe;
                            final bool isBlockedByUser =
                                profile.isBlockedByUser;
                            if (isBlockedByMe || isBlockedByUser) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildBlockedBanner(
                                  ctx,
                                  profile,
                                  scheme,
                                  textTheme,
                                  radii,
                                  isBlockedByMe: isBlockedByMe,
                                  isBlockedByUser: isBlockedByUser,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],

                      // ── Primary & Secondary Actions Hierarchy ─────────
                      if (!isMe) ...[
                        _buildActionHierarchy(
                            context, profile, scheme, textTheme, radii),
                        const SizedBox(height: 20),
                      ],

                      // ── About & Bio Section ──────────────────────────
                      _buildAboutCard(context, profile, scheme, textTheme, radii,
                          isMe: isMe),
                      const SizedBox(height: 20),

                      // ── Shared Media Gallery Tabs ────────────────────
                      ProfileSharedMediaTabView(
                        chatId: _resolvedChatId,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _computeStatusText(ApiProfile profile, bool isOnline) {
    if (isOnline) {
      return context.l10n.profileOnline;
    }
    if (profile.lastSeen != null) {
      final Duration diff = DateTime.now().difference(profile.lastSeen!);
      final bool isRu =
          Localizations.localeOf(context).languageCode == 'ru';
      final String minUnit = isRu ? ' мин' : 'm';
      final String hourUnit = isRu ? ' ч' : 'h';
      if (diff.inMinutes < 60) {
        final int m = diff.inMinutes.clamp(1, 59);
        return '${context.l10n.profileLastSeen} $m$minUnit';
      }
      if (diff.inHours < 24) {
        return '${context.l10n.profileLastSeen} ${diff.inHours}$hourUnit';
      }
      return '${context.l10n.profileLastSeen} ${DateFormat.yMMMMd(Localizations.localeOf(context).languageCode).format(profile.lastSeen!)}';
    }
    return context.l10n.profileOffline;
  }

  // ── M3 Expressive Action Hierarchy ──────────────────────────────────
  Widget _buildActionHierarchy(
    BuildContext context,
    ApiProfile profile,
    ColorScheme scheme,
    TextTheme textTheme,
    AppRadiiTheme radii,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Primary Action: Full-width "Написать" (56dp, pill)
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: () => _handleMessageTap(profile),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radii.full),
              ),
            ),
            icon: _messagePhase == ActionPhase.pending
                ? AppLoadingIndicator(
                    size: 18,
                    color: scheme.onPrimary,
                  )
                : const Icon(Icons.chat_bubble_rounded, size: 20),
            label: Text(
              context.l10n.profileMessage,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary Actions: Audio call, Video call, Share / QR
        Row(
          children: <Widget>[
            Expanded(
              child: _buildSecondaryActionButton(
                icon: Icons.call_rounded,
                label: context.l10n.profileCall,
                backgroundColor: scheme.surfaceContainerHigh,
                foregroundColor: scheme.onSurface,
                onTap: () => _handleCallTap(profile, isVideo: false),
                scheme: scheme,
                textTheme: textTheme,
                radii: radii,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSecondaryActionButton(
                icon: Icons.videocam_rounded,
                label: context.l10n.profileVideo,
                backgroundColor: scheme.surfaceContainerHigh,
                foregroundColor: scheme.onSurface,
                onTap: () => _handleCallTap(profile, isVideo: true),
                scheme: scheme,
                textTheme: textTheme,
                radii: radii,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSecondaryActionButton(
                icon: Icons.qr_code_rounded,
                label: context.l10n.groupProfileShare,
                backgroundColor: scheme.surfaceContainerHigh,
                foregroundColor: scheme.onSurface,
                onTap: () => _handleShareQrTap(profile),
                scheme: scheme,
                textTheme: textTheme,
                radii: radii,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryActionButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback onTap,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required AppRadiiTheme radii,
  }) {
    final BorderRadius borderRad = BorderRadius.circular(radii.md);
    return Material(
      color: backgroundColor,
      borderRadius: borderRad,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRad,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 20, color: foregroundColor),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── About & Bio Section ─────────────────────────────────────────────
  Widget _buildAboutCard(
    BuildContext context,
    ApiProfile profile,
    ColorScheme scheme,
    TextTheme textTheme,
    AppRadiiTheme radii, {
    bool isMe = false,
  }) {
    final String currentLocale =
        Localizations.localeOf(context).languageCode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radii.xl),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Bio
          if (profile.bio.trim().isNotEmpty) ...[
            Text(
              context.l10n.profileBioHeader,
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              profile.bio.trim(),
              style: textTheme.bodyLarge?.copyWith(
                color: scheme.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Divider(
              color: scheme.outlineVariant,
              height: 1,
            ),
            const SizedBox(height: 16),
          ],

          // Username row with copy
          _buildInfoRow(
            icon: Icons.alternate_email_rounded,
            label: context.l10n.profileUsernameLabel,
            value: '@${profile.username}',
            scheme: scheme,
            textTheme: textTheme,
            radii: radii,
            onTap: () {
              Clipboard.setData(ClipboardData(text: '@${profile.username}'));
              HapticService.confirm();
              AppToast.showInfo(
                  context, context.l10n.profileUsernameCopied);
            },
          ),
          const SizedBox(height: 14),

          // Registration Date
          if (profile.createdAt != null) ...[
            _buildInfoRow(
              icon: Icons.calendar_today_rounded,
              label: context.l10n.profileRegistrationDate,
              value: DateFormat.yMMMMd(currentLocale)
                  .format(profile.createdAt!),
              scheme: scheme,
              textTheme: textTheme,
              radii: radii,
            ),
          ],

          // Phone Number
          if (profile.phoneNumber != null &&
              profile.phoneNumber!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildInfoRow(
              icon: Icons.phone_rounded,
              label: context.l10n.profilePhoneNumber,
              value: profile.phoneNumber!,
              scheme: scheme,
              textTheme: textTheme,
              radii: radii,
              onTap: () {
                Clipboard.setData(
                    ClipboardData(text: profile.phoneNumber!));
                HapticService.confirm();
                AppToast.showInfo(context, context.l10n.profilePhoneCopied);
              },
            ),
          ],

          // Birthday
          if (profile.birthday != null && profile.birthday!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildInfoRow(
              icon: Icons.cake_rounded,
              label: context.l10n.profileBirthday,
              value: profile.birthday!,
              scheme: scheme,
              textTheme: textTheme,
              radii: radii,
            ),
          ],

          // Working Hours
          if (profile.workingHours != null &&
              profile.workingHours!.isNotEmpty) ...[
            const SizedBox(height: 16),
            WorkingHoursWidget(
              workingHours: profile.workingHours,
              isEditable: isMe,
            ),
          ],

          // Non-status badges
          if (profile.badges
              .where((b) => !BadgeResolver.isStatusBadge(b))
              .isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: profile.badges
                  .where((b) => !BadgeResolver.isStatusBadge(b))
                  .map(
                    (ApiBadge badge) => BadgeChip(
                      id: badge.id,
                      name: badge.name,
                      icon: badge.icon,
                      color: badge.color,
                      showName: true,
                      mode: BadgeDisplayMode.infoLabel,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required AppRadiiTheme radii,
    VoidCallback? onTap,
  }) {
    final Widget content = Row(
      children: <Widget>[
        M3Container(
          Shapes.c9_sided_cookie,
          width: 36,
          height: 36,
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: Icon(icon, size: 18, color: scheme.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.copy_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
      ],
    );

    if (onTap != null) {
      final BorderRadius itemRad = BorderRadius.circular(radii.sm);
      return Material(
        color: Colors.transparent,
        borderRadius: itemRad,
        child: InkWell(
          onTap: onTap,
          borderRadius: itemRad,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: content,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: content,
    );
  }

  Widget _buildBlockedBanner(
    BuildContext context,
    ApiProfile profile,
    ColorScheme scheme,
    TextTheme textTheme,
    AppRadiiTheme radii, {
    required bool isBlockedByMe,
    required bool isBlockedByUser,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(radii.md),
        border: Border.all(
          color: scheme.error,
          width: 1.2,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.error,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.block_rounded,
              color: scheme.onError,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isBlockedByMe
                      ? context.l10n.profileBlockedByMeTitle
                      : context.l10n.profileBlockedByUserTitle,
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isBlockedByMe
                      ? context.l10n.profileBlockedByMeDesc
                      : context.l10n.profileBlockedByUserDesc,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
          if (isBlockedByMe) ...[
            const SizedBox(width: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _showUnblockDialog(profile),
              child: Text(context.l10n.unblockAction),
            ),
          ],
        ],
      ),
    );
  }

  // ── "⋮" Actions Menu ───────────────────────────────────────────────
  void _showMoreActionsMenu(ApiProfile profile) {
    final bool isBlocked =
        ref.read(privacyProvider).isUserBlocked(profile.id) ||
            profile.isBlockedByMe;
    final bool isSupport =
        BotDetector.isSupport(profile.username, userId: profile.id);
    final bool isFavorite =
        ref.read(favoriteContactsProvider).contains(profile.id);

    final int? effectiveChatId = _resolvedChatId ??
        ref.read(chatsProvider).value?.where((c) =>
            c.chatType == 'direct' &&
            c.username?.trim().toLowerCase() ==
                profile.username.trim().toLowerCase()).firstOrNull?.id;
    final bool isMuted = effectiveChatId != null
        ? (ref.read(chatMutedProvider(effectiveChatId)).value ?? false)
        : _isMutedLocally;

    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) {
        final ColorScheme sheetScheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 1. Secret chat
              ListTile(
                leading: Icon(Icons.lock_rounded, color: sheetScheme.primary),
                title: Text(context.l10n.profileSecretChat),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleSecretChatTap(profile);
                },
              ),

              // 2. Mute / Unmute notifications
              ListTile(
                leading: Icon(
                  isMuted
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: sheetScheme.onSurface,
                ),
                title: Text(
                  isMuted
                      ? context.l10n.profileUnmuteNotifications
                      : context.l10n.profileMuteNotifications,
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  int? targetChatId = _resolvedChatId;
                  if (targetChatId == null || targetChatId <= 0) {
                    final List<ApiChatSummary> chats =
                        ref.read(chatsProvider).value ?? const <ApiChatSummary>[];
                    targetChatId = chats
                        .where((c) =>
                            c.chatType == 'direct' &&
                            c.username?.trim().toLowerCase() ==
                                profile.username.trim().toLowerCase())
                        .firstOrNull
                        ?.id;
                  }
                  if (targetChatId != null && targetChatId > 0) {
                    await ref
                        .read(chatMutedProvider(targetChatId).notifier)
                        .toggle();
                    final bool nowMuted = ref
                            .read(chatMutedProvider(targetChatId))
                            .value ??
                        false;
                    if (mounted) {
                      setState(() {
                        _resolvedChatId = targetChatId;
                        _isMutedLocally = nowMuted;
                      });
                      HapticService.tap();
                      AppToast.showSuccess(
                        context,
                        nowMuted
                            ? context.l10n.profileMuteNotifications
                            : context.l10n.profileUnmuteNotifications,
                      );
                    }
                  } else {
                    setState(() {
                      _isMutedLocally = !_isMutedLocally;
                    });
                    HapticService.tap();
                    AppToast.showSuccess(
                      context,
                      _isMutedLocally
                          ? context.l10n.profileMuteNotifications
                          : context.l10n.profileUnmuteNotifications,
                    );
                  }
                },
              ),

              // 3. Add to / Remove from favorites
              ListTile(
                leading: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: sheetScheme.primary,
                ),
                title: Text(
                  isFavorite
                      ? context.l10n.profileRemoveFromFavorites
                      : context.l10n.profileAddToFavorites,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref
                      .read(favoriteContactsProvider.notifier)
                      .toggleFavorite(profile.id);
                  HapticService.confirm();
                  AppToast.showSuccess(
                    context,
                    isFavorite
                        ? context.l10n.profileRemoveFromFavorites
                        : context.l10n.profileAddToFavorites,
                  );
                },
              ),

              // 4. Common groups
              ListTile(
                leading: Icon(Icons.group_rounded, color: sheetScheme.onSurface),
                title: Text(context.l10n.profileCommonGroups),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCommonGroupsDialog(profile);
                },
              ),

              // 5. Share QR
              ListTile(
                leading:
                    Icon(Icons.qr_code_rounded, color: sheetScheme.onSurface),
                title: Text(context.l10n.profileShareQr),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleShareQrTap(profile);
                },
              ),

              // 6. Block / Unblock (hidden for support)
              if (!isSupport) ...[
                if (isBlocked)
                  ListTile(
                    leading:
                        Icon(Icons.lock_open_rounded, color: sheetScheme.primary),
                    title: Text(
                      context.l10n.unblockUserPrompt(profile.username),
                      style: TextStyle(
                        color: sheetScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showUnblockDialog(profile);
                    },
                  )
                else
                  ListTile(
                    leading: Icon(Icons.block_rounded, color: sheetScheme.error),
                    title: Text(
                      context.l10n.blockUserPrompt(profile.username),
                      style: TextStyle(color: sheetScheme.error),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showBlockDialog(profile);
                    },
                  ),

                // 7. Report (hidden for support)
                ListTile(
                  leading: Icon(Icons.flag_rounded, color: sheetScheme.onSurface),
                  title: Text(context.l10n.reportUser),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showReportUserDialog(profile);
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showCommonGroupsDialog(ApiProfile profile) {
    // Truthfully display empty state when no verified mutual groups exist (ППРФ-2)
    const List<ApiChatSummary> commonGroups = <ApiChatSummary>[];

    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) {
        final TextTheme dialogTheme = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  context.l10n.profileCommonGroups,
                  style: dialogTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (commonGroups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        context.l10n.profileNoCommonGroups,
                        style: dialogTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  ...commonGroups.take(6).map(
                        (ApiChatSummary g) => ListTile(
                          leading: const Icon(Icons.group_rounded),
                          title: Text(g.name),
                          subtitle: Text(
                              context.l10n.chatMemberCount(g.membersCount)),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            context.push('/chat/${g.id}');
                          },
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUnblockDialog(ApiProfile profile) {
    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) {
        final TextTheme dialogTheme = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  context.l10n.unblockAction,
                  style: dialogTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.unblockUserConfirmDesc(profile.username),
                  style: dialogTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    // Cancel on left per platform convention
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(context.l10n.commonCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action on right
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          HapticService.confirm();
                          final bool success = await ref
                              .read(privacyProvider.notifier)
                              .unblockUser(profile.id);
                          if (!mounted) return;
                          if (success) {
                            AppToast.showSuccess(
                              context,
                              context.l10n.userUnblockedToast(profile.username),
                            );
                            setState(() {
                              _profile = _profile?.copyWith(
                                isBlockedByMe: false,
                                isBlocked: profile.isBlockedByUser,
                              );
                            });
                          } else {
                            AppToast.showError(
                              context,
                              context.l10n.userUnblockFailed,
                            );
                          }
                        },
                        child: Text(context.l10n.unblockAction),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBlockDialog(ApiProfile profile) {
    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) {
        final TextTheme dialogTheme = Theme.of(ctx).textTheme;
        final ColorScheme dialogScheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  context.l10n.profileBlock,
                  style: dialogTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.blockUserConfirmDesc(profile.username),
                  style: dialogTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    // Cancel on left per platform convention
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(context.l10n.commonCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action on right with high-contrast onError foreground
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: dialogScheme.error,
                          foregroundColor: dialogScheme.onError,
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          HapticService.confirm();
                          final bool success = await ref
                              .read(privacyProvider.notifier)
                              .blockUser(
                                profile.id,
                                user: BlockedUser(
                                  id: profile.id,
                                  username: profile.username,
                                  displayName: profile.displayName,
                                  avatarUrl: profile.avatarUrl,
                                ),
                              );
                          if (!mounted) return;
                          if (success) {
                            AppToast.showSuccess(
                              context,
                              context.l10n.userBlockedToast(profile.username),
                            );
                            setState(() {
                              _profile = _profile?.copyWith(
                                isBlockedByMe: true,
                                isBlocked: true,
                              );
                            });
                          } else {
                            AppToast.showError(
                              context,
                              context.l10n.userBlockFailed,
                            );
                          }
                        },
                        child: Text(context.l10n.profileBlock),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReportUserDialog(ApiProfile profile) {
    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) {
        final ColorScheme sheetScheme = Theme.of(ctx).colorScheme;
        final TextTheme sheetTheme = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.reportSelectReason,
                  style: sheetTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.report_gmailerrorred_rounded,
                    color: sheetScheme.error),
                title: Text(context.l10n.reportReasonSpam),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitUserReport(profile, 'spam');
                },
              ),
              ListTile(
                leading: Icon(Icons.report_problem_rounded,
                    color: sheetScheme.error),
                title: Text(context.l10n.reportReasonScam),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitUserReport(profile, 'scam');
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.gavel_rounded, color: sheetScheme.error),
                title: Text(context.l10n.reportReasonInappropriate),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitUserReport(profile, 'illegal');
                },
              ),
              ListTile(
                leading: Icon(Icons.copyright_rounded,
                    color: sheetScheme.error),
                title: Text(context.l10n.reportReasonCopyright),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitUserReport(profile, 'copyright');
                },
              ),
              ListTile(
                leading: Icon(Icons.privacy_tip_rounded,
                    color: sheetScheme.error),
                title: Text(context.l10n.reportReasonDoxxing),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitUserReport(profile, 'doxing');
                },
              ),
              ListTile(
                leading: Icon(Icons.warning_amber_rounded,
                    color: sheetScheme.error),
                title: Text(context.l10n.reportReasonThreats),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitUserReport(profile, 'swatting');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitUserReport(ApiProfile profile, String reason) async {
    try {
      await ref.read(reportRepositoryProvider).report(
            chatId: (_resolvedChatId != null && _resolvedChatId! > 0)
                ? _resolvedChatId
                : null,
            reportedUserId: profile.id,
            reason: reason,
          );
      if (!mounted) return;
      HapticService.confirm();
      AppToast.showSuccess(context, context.l10n.reportSentSuccess);
    } catch (e) {
      if (!mounted) return;
      HapticService.destructive();
      AppToast.showError(context, e);
    }
  }
}
