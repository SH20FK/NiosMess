import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nios_admin_flutter/core/localization/l10n.dart';
import 'package:nios_admin_flutter/core/network/api_exception.dart';
import 'package:nios_admin_flutter/models/admin_user.dart';
import 'package:nios_admin_flutter/providers/admin_session_provider.dart';
import 'package:nios_admin_flutter/screens/admin_user_detail_screen.dart';
import 'package:nios_admin_flutter/widgets/admin_badge_token.dart';
import 'package:nios_admin_flutter/widgets/admin_panel.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  int _page = 1;
  String _query = '';
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<AdminUser> _users = const <AdminUser>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await ref
          .read(adminRepositoryProvider)
          .getUsers(page: _page);
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : '$error';
      });
    }
  }

  List<AdminUser> get _filtered {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users
        .where((AdminUser user) {
          final String hay =
              '${user.username} ${user.displayName} ${user.email}'
                  .toLowerCase();
          return hay.contains(q);
        })
        .toList(growable: false);
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.moderationSuccess)));
    } catch (error) {
      if (!mounted) return;
      final String message = error is ApiException ? error.message : '$error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ban(AdminUser user) async {
    final TextEditingController controller = TextEditingController();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.l10n.usersBan),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: context.l10n.usersReason),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.usersBan),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _mutate(
        () => ref
            .read(adminRepositoryProvider)
            .banUser(
              userId: user.id,
              reason: controller.text.trim().isEmpty
                  ? '-'
                  : controller.text.trim(),
            ),
      );
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(context.l10n.retry)),
          ],
        ),
      );
    }

    final List<AdminUser> users = _filtered;

    return ListView(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(context.l10n.usersTitle, style: textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.usersSubtitle,
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdminPanel(
          child: Column(
            children: <Widget>[
              TextField(
                onChanged: (String value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: context.l10n.usersSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Text(context.l10n.usersPage(_page)),
                  const Spacer(),
                  IconButton(
                    onPressed: _page <= 1
                        ? null
                        : () {
                            setState(() => _page -= 1);
                            _load();
                          },
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    onPressed: _users.length < 25
                        ? null
                        : () {
                            setState(() => _page += 1);
                            _load();
                          },
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (users.isEmpty)
          AdminPanel(child: Text(context.l10n.usersNoResults))
        else
          ...users.map((AdminUser user) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AdminPanel(
                child: Column(
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _avatar(user, scheme),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      user.displayName,
                                      style: textTheme.titleLarge,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'dd.MM.yyyy',
                                    ).format(user.createdAt.toLocal()),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${user.username}',
                                style: textTheme.titleMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(user.email, style: textTheme.bodyMedium),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  if (user.isBanned)
                                    _pill(
                                      context,
                                      context.l10n.userStatusBanned,
                                      scheme.error,
                                    ),
                                  if (user.isFrozen)
                                    _pill(
                                      context,
                                      context.l10n.userStatusFrozen,
                                      Colors.orange,
                                    ),
                                  if (user.spamBlock)
                                    _pill(
                                      context,
                                      context.l10n.userStatusSpamBlocked,
                                      Colors.deepOrange,
                                    ),
                                  if (user.twoFaEnabled)
                                    _pill(
                                      context,
                                      context.l10n.userStatus2fa,
                                      scheme.primary,
                                    ),
                                  ...user.badges
                                      .take(3)
                                      .map(
                                        (badge) =>
                                            AdminBadgeToken(badge: badge),
                                      ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AdminUserDetailScreen(userId: user.id),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text(context.l10n.usersOpen),
                        ),
                        if (user.isBanned)
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _mutate(
                                    () => ref
                                        .read(adminRepositoryProvider)
                                        .unbanUser(userId: user.id),
                                  ),
                            child: Text(context.l10n.usersUnban),
                          )
                        else
                          OutlinedButton(
                            onPressed: _busy ? null : () => _ban(user),
                            child: Text(context.l10n.usersBan),
                          ),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _mutate(
                                  () => ref
                                      .read(adminRepositoryProvider)
                                      .setFrozen(
                                        userId: user.id,
                                        frozen: !user.isFrozen,
                                      ),
                                ),
                          child: Text(
                            user.isFrozen
                                ? context.l10n.usersUnfreeze
                                : context.l10n.usersFreeze,
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _mutate(
                                  () => ref
                                      .read(adminRepositoryProvider)
                                      .setSpamBlock(
                                        userId: user.id,
                                        blocked: !user.spamBlock,
                                      ),
                                ),
                          child: Text(
                            user.spamBlock
                                ? context.l10n.usersUnspamblock
                                : context.l10n.usersSpamblock,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _avatar(AdminUser user, ColorScheme scheme) {
    if ((user.avatarUrl ?? '').trim().isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: CachedNetworkImageProvider(user.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: 26,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(
        user.displayName.isEmpty
            ? '?'
            : user.displayName.characters.first.toUpperCase(),
      ),
    );
  }

  Widget _pill(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
