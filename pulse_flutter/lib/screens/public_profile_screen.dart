import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';
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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant PublicProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ApiProfile profile = await ref
          .read(authRepositoryProvider)
          .getPublicProfile(widget.username);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AuthState auth = ref.watch(authProvider);

    if (_loading) {
      return Scaffold(
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
        body: const PulseScaffoldBody(
          maxWidth: 980,
          child: Center(child: AppLoadingIndicator()),
        ),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
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
        body: PulseScaffoldBody(
          maxWidth: 980,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.error_outline, size: 48, color: scheme.error),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? context.l10n.commonRetry,
                    style: textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  PulseButton(
                    label: context.l10n.commonRetry,
                    icon: Icons.refresh,
                    onPressed: _loadProfile,
                  ),
                ],
              ),
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
        title: Text(context.l10n.profileTitle),
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 920,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              0,
              0,
              0,
              28 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: <Widget>[
              // Обложка профиля + Карточка пользователя
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  // Баннер-обложка
                  Container(
                    height: 190,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          scheme.primary.withValues(alpha: 0.8),
                          scheme.tertiary.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(28),
                      ),
                    ),
                  ),
                  // Карточка с аватаром
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.screenHorizontalPadding,
                      110,
                      AppConstants.screenHorizontalPadding,
                      0,
                    ),
                    child: Material(
                      color: scheme.surfaceContainerLow.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(24),
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.16),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: <Widget>[
                            Hero(
                              tag: 'user-avatar-${profile.username}',
                              child: Stack(
                                children: [
                                  PulseAvatar(
                                    name: profile.displayName,
                                    avatarUrl: profile.avatarUrl,
                                    radius: 44,
                                    fallbackColor: scheme.primaryContainer,
                                    textColor: scheme.onPrimaryContainer,
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
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    profile.displayName,
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (profile.badges.where((b) => BadgeResolver.isStatusBadge(b)).isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  ...profile.badges.where((b) => BadgeResolver.isStatusBadge(b)).map((b) => Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: BadgeChip(
                                      id: b.id, name: b.name, icon: b.icon, color: b.color,
                                      mode: BadgeDisplayMode.statusIcon,
                                    ),
                                  )),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile.username.isEmpty ? '' : '@${profile.username}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _profileTag(
                                  context,
                                  icon: Icons.alternate_email_rounded,
                                  label: profile.username,
                                ),
                                _profileTag(
                                  context,
                                  icon: isMe
                                      ? Icons.visibility_rounded
                                      : Icons.public_rounded,
                                  label: isMe
                                      ? context.l10n.profilePublicView
                                      : context.l10n.profilePublicProfile,
                                ),
                              ],
                            ),
                            if (profile.badges.where((b) => !BadgeResolver.isStatusBadge(b)).isNotEmpty) ...<Widget>[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                alignment: WrapAlignment.center,
                                children: profile.badges.where((b) => !BadgeResolver.isStatusBadge(b))
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
                            const SizedBox(height: 16),
                            _softInset(
                              context,
                              child: Text(
                                profile.bio.trim().isEmpty
                                    ? context.l10n.commonNoDescription
                                    : profile.bio.trim(),
                                textAlign: TextAlign.center,
                                style: textTheme.bodyLarge?.copyWith(
                                  color: profile.bio.trim().isEmpty
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fade(duration: 260.ms).slideY(begin: 0.04, end: 0, duration: 260.ms),
                ],
              ),

              if (!isMe) ...<Widget>[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.screenHorizontalPadding,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: PulseButton(
                          label: context.l10n.profileMessage,
                          icon: Icons.message_rounded,
                          onPressed: () => context.go('/chat/dm/${profile.username}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PulseButton(
                          label: context.l10n.settingsSecretChatsButton,
                          icon: Icons.lock_rounded,
                          onPressed: () => context.go('/chat/dm/${profile.username}?isSecret=1'),
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 60.ms).fade(duration: 260.ms).slideY(begin: 0.04, end: 0, duration: 260.ms),
              ],

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenHorizontalPadding,
                ),
                child: _panel(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(context.l10n.profileAbout, style: textTheme.titleLarge),
                      const SizedBox(height: 12),
                      _infoRow(
                        context,
                        icon: Icons.person_outline_rounded,
                        label: context.l10n.profileDisplayName,
                        value: profile.displayName,
                      ),
                      const SizedBox(height: 12),
                      _infoRow(
                        context,
                        icon: Icons.alternate_email_rounded,
                        label: context.l10n.profileUsername,
                        value: '@${profile.username}',
                      ),
                      const SizedBox(height: 12),
                      _infoRow(
                        context,
                        icon: Icons.notes_rounded,
                        label: context.l10n.profileDescription,
                        value: profile.bio.trim().isEmpty
                            ? context.l10n.commonNoDescription
                            : profile.bio.trim(),
                        multiline: true,
                      ),
                    ],
                  ),
                ),
              ).animate(delay: 90.ms).fade(duration: 260.ms).slideY(begin: 0.04, end: 0, duration: 260.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileTag(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label, style: textTheme.labelLarge),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool multiline = false,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: multiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.16),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _softInset(BuildContext context, {required Widget child}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
