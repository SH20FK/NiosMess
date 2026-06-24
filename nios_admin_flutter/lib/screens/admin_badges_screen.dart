import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nios_admin_flutter/core/localization/l10n.dart';
import 'package:nios_admin_flutter/core/network/api_exception.dart';
import 'package:nios_admin_flutter/models/admin_badge.dart';
import 'package:nios_admin_flutter/providers/admin_session_provider.dart';
import 'package:nios_admin_flutter/widgets/admin_badge_token.dart';
import 'package:nios_admin_flutter/widgets/admin_panel.dart';

class AdminBadgesScreen extends ConsumerStatefulWidget {
  const AdminBadgesScreen({super.key});

  @override
  ConsumerState<AdminBadgesScreen> createState() => _AdminBadgesScreenState();
}

class _AdminBadgesScreenState extends ConsumerState<AdminBadgesScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<AdminBadge> _badges = const <AdminBadge>[];

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
      final badges = await ref.read(adminRepositoryProvider).getBadges();
      if (!mounted) return;
      setState(() {
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

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final iconController = TextEditingController(text: 'V');
    final colorController = TextEditingController(text: '#0d6fad');

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.l10n.badgesCreate),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: context.l10n.badgeName),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: context.l10n.badgeDescription,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: iconController,
                decoration: InputDecoration(labelText: context.l10n.badgeIcon),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: colorController,
                decoration: InputDecoration(labelText: context.l10n.badgeColor),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _mutate(
        () => ref
            .read(adminRepositoryProvider)
            .createBadge(
              name: nameController.text.trim(),
              description: descriptionController.text.trim(),
              icon: iconController.text.trim(),
              color: colorController.text.trim(),
            ),
      );
    }

    nameController.dispose();
    descriptionController.dispose();
    iconController.dispose();
    colorController.dispose();
  }

  Future<void> _showUserActionDialog(
    AdminBadge badge, {
    required bool revoke,
  }) async {
    final controller = TextEditingController();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          revoke ? context.l10n.badgeRevoke : context.l10n.badgeAward,
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.l10n.badgeUserId),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              revoke ? context.l10n.badgeRevoke : context.l10n.badgeAward,
            ),
          ),
        ],
      ),
    );
    final int? userId = int.tryParse(controller.text.trim());
    if (confirm == true && userId != null) {
      await _mutate(
        () => revoke
            ? ref
                  .read(adminRepositoryProvider)
                  .revokeBadge(userId: userId, badgeId: badge.id)
            : ref
                  .read(adminRepositoryProvider)
                  .awardBadge(userId: userId, badgeId: badge.id),
      );
    }
    controller.dispose();
  }

  Future<void> _deleteBadge(AdminBadge badge) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.l10n.badgeDeleteConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _mutate(
        () => ref.read(adminRepositoryProvider).deleteBadge(badge.id),
      );
    }
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

    return ListView(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.badgesTitle,
                    style: textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.badgesSubtitle,
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.badgesCreate),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_badges.isEmpty)
          AdminPanel(child: Text(context.l10n.badgesNoResults))
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _badges
                .map((AdminBadge badge) {
                  return SizedBox(
                    width: 360,
                    child: AdminPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              AdminBadgeToken(badge: badge, showName: true),
                              const Spacer(),
                              Text(
                                DateFormat(
                                  'dd.MM.yyyy',
                                ).format(badge.createdAt.toLocal()),
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            badge.description.isEmpty
                                ? context.l10n.emptyDescription
                                : badge.description,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _showUserActionDialog(
                                        badge,
                                        revoke: false,
                                      ),
                                child: Text(context.l10n.badgeAward),
                              ),
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _showUserActionDialog(
                                        badge,
                                        revoke: true,
                                      ),
                                child: Text(context.l10n.badgeRevoke),
                              ),
                              FilledButton.tonal(
                                onPressed: _busy
                                    ? null
                                    : () => _deleteBadge(badge),
                                child: Text(context.l10n.delete),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
      ],
    );
  }
}
