import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nios_admin_flutter/core/localization/l10n.dart';
import 'package:nios_admin_flutter/core/network/api_exception.dart';
import 'package:nios_admin_flutter/models/admin_badge.dart';
import 'package:nios_admin_flutter/models/admin_user.dart';
import 'package:nios_admin_flutter/providers/admin_session_provider.dart';
import 'package:nios_admin_flutter/widgets/admin_badge_token.dart';
import 'package:nios_admin_flutter/widgets/admin_panel.dart';

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  const AdminUserDetailScreen({required this.userId, super.key});

  final int userId;

  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  AdminUser? _user;
  List<AdminBadge> _badges = const <AdminBadge>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;

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
      final repo = ref.read(adminRepositoryProvider);
      final AdminUser user = await repo.getUser(widget.userId);
      final List<AdminBadge> badges = await repo.getBadges();
      if (!mounted) return;
      setState(() {
        _user = user;
        _badges = badges;
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

  Future<void> _runAction(Future<void> Function() action) async {
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

  Future<void> _showBanDialog() async {
    final TextEditingController controller = TextEditingController();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
        );
      },
    );
    if (confirm != true) {
      controller.dispose();
      return;
    }
    await _runAction(
      () => ref
          .read(adminRepositoryProvider)
          .banUser(
            userId: widget.userId,
            reason: controller.text.trim().isEmpty
                ? '-'
                : controller.text.trim(),
          ),
    );
    controller.dispose();
  }

  Future<void> _showAwardDialog() async {
    int? selectedBadgeId = _badges.isNotEmpty ? _badges.first.id : null;
    if (_badges.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              title: Text(context.l10n.userDetailAwardBadge),
              content: DropdownButtonFormField<int>(
                initialValue: selectedBadgeId,
                items: _badges
                    .map(
                      (AdminBadge badge) => DropdownMenuItem<int>(
                        value: badge.id,
                        child: Text(badge.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (int? value) =>
                    setStateDialog(() => selectedBadgeId = value),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.l10n.userDetailAwardBadge),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true && selectedBadgeId != null) {
      await _runAction(
        () => ref
            .read(adminRepositoryProvider)
            .awardBadge(userId: widget.userId, badgeId: selectedBadgeId!),
      );
    }
  }

  Future<void> _revokeBadge(AdminBadge badge) async {
    await _runAction(
      () => ref
          .read(adminRepositoryProvider)
          .revokeBadge(userId: widget.userId, badgeId: badge.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.userDetailTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                AdminPanel(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _avatar(scheme),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _user!.displayName,
                              style: textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@${_user!.username}',
                              style: textTheme.titleMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_user!.email, style: textTheme.bodyMedium),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _statusChip(
                                  context,
                                  context.l10n.userStatusActive,
                                  _user!.isActive,
                                  Colors.green,
                                ),
                                _statusChip(
                                  context,
                                  context.l10n.userStatusBanned,
                                  _user!.isBanned,
                                  scheme.error,
                                ),
                                _statusChip(
                                  context,
                                  context.l10n.userStatusFrozen,
                                  _user!.isFrozen,
                                  Colors.orange,
                                ),
                                _statusChip(
                                  context,
                                  context.l10n.userStatusSpamBlocked,
                                  _user!.spamBlock,
                                  Colors.deepOrange,
                                ),
                                _statusChip(
                                  context,
                                  context.l10n.userStatus2fa,
                                  _user!.twoFaEnabled,
                                  scheme.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AdminPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.userDetailActions,
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (_user!.isBanned)
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _runAction(
                                      () => ref
                                          .read(adminRepositoryProvider)
                                          .unbanUser(userId: widget.userId),
                                    ),
                              icon: const Icon(Icons.lock_open_rounded),
                              label: Text(context.l10n.usersUnban),
                            )
                          else
                            FilledButton.tonalIcon(
                              onPressed: _busy ? null : _showBanDialog,
                              icon: const Icon(Icons.gpp_bad_rounded),
                              label: Text(context.l10n.usersBan),
                            ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _runAction(
                                    () => ref
                                        .read(adminRepositoryProvider)
                                        .setFrozen(
                                          userId: widget.userId,
                                          frozen: !_user!.isFrozen,
                                        ),
                                  ),
                            icon: const Icon(Icons.ac_unit_rounded),
                            label: Text(
                              _user!.isFrozen
                                  ? context.l10n.usersUnfreeze
                                  : context.l10n.usersFreeze,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _runAction(
                                    () => ref
                                        .read(adminRepositoryProvider)
                                        .setSpamBlock(
                                          userId: widget.userId,
                                          blocked: !_user!.spamBlock,
                                        ),
                                  ),
                            icon: const Icon(
                              Icons.report_gmailerrorred_rounded,
                            ),
                            label: Text(
                              _user!.spamBlock
                                  ? context.l10n.usersUnspamblock
                                  : context.l10n.usersSpamblock,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AdminPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              context.l10n.userDetailBadges,
                              style: textTheme.titleLarge,
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : _showAwardDialog,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(context.l10n.userDetailAwardBadge),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_user!.badges.isEmpty)
                        Text(context.l10n.badgesNoResults)
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _user!.badges
                              .map(
                                (AdminBadge badge) => InkWell(
                                  onTap: _busy
                                      ? null
                                      : () => _revokeBadge(badge),
                                  borderRadius: BorderRadius.circular(999),
                                  child: AdminBadgeToken(
                                    badge: badge,
                                    showName: true,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        '${context.l10n.createdAt}: ${DateFormat('dd.MM.yyyy HH:mm').format(_user!.createdAt.toLocal())}',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _avatar(ColorScheme scheme) {
    final String? avatarUrl = _user!.avatarUrl;
    if ((avatarUrl ?? '').trim().isEmpty) {
      return CircleAvatar(
        radius: 34,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(
          _user!.displayName.isEmpty
              ? '?'
              : _user!.displayName.characters.first.toUpperCase(),
        ),
      );
    }
    return CircleAvatar(
      radius: 34,
      backgroundImage: CachedNetworkImageProvider(avatarUrl!),
    );
  }

  Widget _statusChip(
    BuildContext context,
    String label,
    bool active,
    Color color,
  ) {
    if (!active) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
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
