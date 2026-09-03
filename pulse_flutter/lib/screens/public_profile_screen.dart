import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/repositories/report_repository.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/profile/profile_shared_media_tab_view.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
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

  @override
  void initState() {
    super.initState();
    _checkCacheAndLoad();
  }

  @override
  void didUpdateWidget(covariant PublicProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username) {
      _checkCacheAndLoad();
    }
  }

  void _checkCacheAndLoad() {
    // 1. Try local cache box
    final cached = ref.read(cacheServiceProvider).getCachedProfile(widget.username);
    if (cached != null) {
      _profile = cached;
      _resolveChatId(cached);
    } else {
      // 2. Try auth self profile
      final myProfile = ref.read(authProvider).profile;
      if (myProfile != null &&
          myProfile.username.toLowerCase() == widget.username.toLowerCase()) {
        _profile = myProfile;
        _resolveChatId(myProfile);
      } else {
        // 3. Try finding in active chats
        final chats = ref.read(chatsProvider).value ?? [];
        for (final c in chats) {
          if (c.username != null &&
              c.username!.toLowerCase() == widget.username.toLowerCase()) {
            _profile = ApiProfile(
              id: c.id,
              username: c.username!,
              displayName: c.name,
              bio: '',
              avatarUrl: c.avatarUrl,
            );
            _resolvedChatId = c.id;
            break;
          }
        }
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
      setState(() {
        _profile = profile;
        _loading = false;
        _error = null;
      });

      _resolveChatId(profile);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_profile == null) {
          final errStr = e.toString();
          if (errStr.contains('timed out') || errStr.contains('SocketException')) {
            _error = 'Сервер временно недоступен. Проверьте соединение с интернетом.';
          } else {
            _error = 'Не удалось загрузить профиль. Попробуйте позже.';
          }
        }
      });
    }
  }

  Future<void> _resolveChatId(ApiProfile profile) async {
    // 1. Check existing chats
    final chats = ref.read(chatsProvider).value ?? [];
    for (final c in chats) {
      if (c.chatType == 'direct' &&
          (c.name == profile.displayName ||
              (c.username != null && c.username == profile.username))) {
        if (mounted) setState(() => _resolvedChatId = c.id);
        return;
      }
    }

    // 2. Open / resolve direct chat via repository
    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .openDirectChatByUsername(profile.username);
      if (result != null && result.chatId > 0 && mounted) {
        setState(() => _resolvedChatId = result.chatId);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AuthState auth = ref.watch(authProvider);

    if (_loading && _profile == null) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: Text(context.l10n.profileTitle),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: AppLoadingIndicator()),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: Text(context.l10n.profileTitle),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_off_rounded, size: 48, color: scheme.error),
                ),
                const SizedBox(height: 20),
                Text(
                  _error ?? context.l10n.contactDetailNotFound,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Не удалось получить данные с сервера',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
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

    return Scaffold(
      backgroundColor: scheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton.filledTonal(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/main/chats');
            }
          },
          style: IconButton.styleFrom(
            backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          if (!isMe)
            IconButton.filledTonal(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => _showMoreActionsMenu(profile),
              style: IconButton.styleFrom(
                backgroundColor:
                    scheme.surfaceContainerHigh.withValues(alpha: 0.7),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: 32 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero Avatar & Header ───────────────────────────────
                _buildHeroHeader(context, profile, scheme, textTheme, isMe),
                const SizedBox(height: 16),

                // ── Quick Action Dock ──────────────────────────────────
                if (!isMe) ...[
                  _buildQuickActionDock(context, profile, scheme, textTheme),
                  const SizedBox(height: 20),
                ],

                // ── About & Bio Section ────────────────────────────────
                _buildAboutCard(context, profile, scheme, textTheme),
                const SizedBox(height: 20),

                // ── Shared Media Gallery Tabs ──────────────────────────
                ProfileSharedMediaTabView(
                  chatId: _resolvedChatId,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero Header ───────────────────────────────────────────────────
  Widget _buildHeroHeader(
    BuildContext context,
    ApiProfile profile,
    ColorScheme scheme,
    TextTheme textTheme,
    bool isMe,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Ambient tonal gradient banner
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.35),
                    scheme.tertiary.withValues(alpha: 0.25),
                    scheme.surface,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
            ),

            // Avatar overlapping the banner bottom
            Positioned(
              bottom: -54,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: PulseAvatar(
                      name: profile.displayName,
                      avatarUrl: profile.avatarUrl,
                      radius: 54,
                      fallbackColor: scheme.primaryContainer,
                      textColor: scheme.onPrimaryContainer,
                      borderColor: scheme.surface,
                      borderWidth: 4,
                    ),
                  ),
                  if (profile.badges.isNotEmpty)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: BadgeChip(
                        id: profile.badges.first.id,
                        name: profile.badges.first.name,
                        icon: profile.badges.first.icon,
                        color: profile.badges.first.color,
                        mode: BadgeDisplayMode.avatarBadge,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 62),

        // Display Name + Badges
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  profile.displayName,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (profile.badges.where(BadgeResolver.isStatusBadge).isNotEmpty) ...[
                const SizedBox(width: 6),
                ...profile.badges
                    .where(BadgeResolver.isStatusBadge)
                    .map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: BadgeChip(
                          id: b.id,
                          name: b.name,
                          icon: b.icon,
                          color: b.color,
                          mode: BadgeDisplayMode.statusIcon,
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Username tag
        if (profile.username.isNotEmpty)
          Text(
            '@${profile.username}',
            style: textTheme.titleSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  // ── Quick Action Dock ─────────────────────────────────────────────
  Widget _buildQuickActionDock(
    BuildContext context,
    ApiProfile profile,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.chat_bubble_rounded,
                label: context.l10n.tabChats,
                color: scheme.primary,
                onTap: () {
                  HapticService.tap();
                  context.push('/chat/dm/${profile.username}');
                },
              ),
            ),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.call_rounded,
                label: context.l10n.callsQuickPeople,
                color: scheme.tertiary,
                onTap: () {
                  HapticService.tap();
                  context.push('/call/dm/${profile.username}?isVideo=0');
                },
              ),
            ),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.videocam_rounded,
                label: context.l10n.callsFilterVideo,
                color: scheme.secondary,
                onTap: () {
                  HapticService.tap();
                  context.push('/call/dm/${profile.username}?isVideo=1');
                },
              ),
            ),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.lock_rounded,
                label: context.l10n.settingsSecretChatsButton,
                color: scheme.primary,
                onTap: () {
                  HapticService.tap();
                  context.push('/chat/dm/${profile.username}?isSecret=1');
                },
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  // ── About & Bio Section ─────────────────────────────────────────────
  Widget _buildAboutCard(
    BuildContext context,
    ApiProfile profile,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bio
            if (profile.bio.trim().isNotEmpty) ...[
              Text(
                'О себе',
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
                color: scheme.outlineVariant.withValues(alpha: 0.15),
                height: 1,
              ),
              const SizedBox(height: 16),
            ],

            // Username row with copy
            _buildInfoRow(
              icon: Icons.alternate_email_rounded,
              label: 'Имя пользователя',
              value: '@${profile.username}',
              scheme: scheme,
              textTheme: textTheme,
              onTap: () {
                Clipboard.setData(ClipboardData(text: '@${profile.username}'));
                HapticService.confirm();
                AppToast.showInfo(context, 'Имя пользователя скопировано');
              },
            ),
            const SizedBox(height: 14),

            // Registration Date
            if (profile.createdAt != null)
              _buildInfoRow(
                icon: Icons.calendar_today_rounded,
                label: 'Регистрация',
                value: DateFormat('d MMMM yyyy', 'ru').format(profile.createdAt!),
                scheme: scheme,
                textTheme: textTheme,
              ),

            // Non-status badges
            if (profile.badges.where((b) => !BadgeResolver.isStatusBadge(b)).isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: profile.badges
                    .where((b) => !BadgeResolver.isStatusBadge(b))
                    .map(
                      (badge) => BadgeChip(
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
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme scheme,
    required TextTheme textTheme,
    VoidCallback? onTap,
  }) {
    final row = Row(
      children: [
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
            children: [
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
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: row,
      );
    }
    return row;
  }

  void _showMoreActionsMenu(ApiProfile profile) {
    AppBottomSheets.show<void>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.block_rounded, color: scheme.error),
                title: Text(
                  'Заблокировать @${profile.username}',
                  style: TextStyle(color: scheme.error),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showBlockDialog(profile);
                },
              ),
              ListTile(
                leading: Icon(Icons.flag_rounded, color: scheme.onSurface),
                title: const Text('Пожаловаться'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showReportUserDialog(profile);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showBlockDialog(ApiProfile profile) {
    AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) {
        final TextTheme textTheme = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Заблокировать пользователя',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Вы уверены, что хотите заблокировать @${profile.username}? Вы больше не сможете обмениваться сообщениями.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(ctx).colorScheme.error,
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          HapticService.confirm();
                          AppToast.showSuccess(
                            context,
                            '@${profile.username} заблокирован на этом устройстве',
                          );
                        },
                        child: const Text('Заблокировать'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Отмена'),
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
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        final TextTheme textTheme = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Выберите причину жалобы',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.report_gmailerrorred_rounded, color: scheme.error),
                title: const Text('Спам'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitUserReport(profile, 'spam');
                },
              ),
              ListTile(
                leading: Icon(Icons.report_problem_rounded, color: scheme.error),
                title: const Text('Мошенничество'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitUserReport(profile, 'scam');
                },
              ),
              ListTile(
                leading: Icon(Icons.gavel_rounded, color: scheme.error),
                title: const Text('Неприемлемый контент'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _submitUserReport(profile, 'illegal');
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
        chatId: 0,
        reportedUserId: profile.id,
        reason: reason,
      );
      if (!mounted) return;
      HapticService.confirm();
      AppToast.showSuccess(context, 'Жалоба отправлена');
    } catch (e) {
      if (!mounted) return;
      HapticService.destructive();
      AppToast.showError(context, 'Ошибка: $e');
    }
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              M3Container(
                Shapes.c9_sided_cookie,
                width: 48,
                height: 48,
                color: color.withValues(alpha: 0.15),
                child: Center(
                  child: Icon(icon, size: 22, color: color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
