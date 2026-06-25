import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/repositories/badge_repository.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/empty_state_widget.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';

class BadgeScreen extends ConsumerStatefulWidget {
  const BadgeScreen({super.key});

  @override
  ConsumerState<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends ConsumerState<BadgeScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _showAdmin = false;
  bool _loading = false;
  List<ApiBadge> _badges = [];
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    setState(() { _loading = true; _error = null; });
    try {
      final badges = await ref.read(badgeRepositoryProvider).listBadges();
      if (!mounted) return;
      setState(() { _badges = badges; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _createBadge() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    final iconCtl = TextEditingController(text: '✓');
    final colorCtl = TextEditingController(text: '#4f46e5');

    final result = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: context.l10n.badgeCreateTitle,
        icon: Icons.workspace_premium_rounded,
        actions: [
          AppDialogAction(label: context.l10n.commonCancel, onPressed: () => Navigator.of(ctx).pop(false)),
          AppDialogAction(label: context.l10n.badgeActionCreate, isPrimary: true, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
        child: AppDialogFormContent(
          fields: [
            AppDialogField(controller: nameCtl, label: context.l10n.badgeFieldName),
            AppDialogField(controller: descCtl, label: context.l10n.badgeFieldDescription),
            AppDialogField(controller: iconCtl, label: context.l10n.badgeFieldIcon),
            AppDialogField(controller: colorCtl, label: context.l10n.badgeFieldColor),
          ],
        ),
      ),
    );

    if (result != true) {
      nameCtl.dispose(); descCtl.dispose(); iconCtl.dispose(); colorCtl.dispose();
      return;
    }

    try {
      await ref.read(badgeRepositoryProvider).createBadge(
        adminPassword: password,
        name: nameCtl.text.trim(),
        description: descCtl.text.trim(),
        icon: iconCtl.text.trim(),
        color: colorCtl.text.trim(),
      );
      nameCtl.dispose(); descCtl.dispose(); iconCtl.dispose(); colorCtl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Badge created')));
      _loadBadges();
    } catch (e) {
      nameCtl.dispose(); descCtl.dispose(); iconCtl.dispose(); colorCtl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteBadge(int badgeId) async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;
    try {
      await ref.read(badgeRepositoryProvider).deleteBadge(adminPassword: password, badgeId: badgeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.badgeDeleted(badgeId))));
      _loadBadges();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _awardBadge() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    final userIdCtl = TextEditingController();
    final badgeIdCtl = TextEditingController();

    final result = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: context.l10n.badgeAwardTitle,
        icon: Icons.person_add_rounded,
        actions: [
          AppDialogAction(label: context.l10n.commonCancel, onPressed: () => Navigator.of(ctx).pop(false)),
          AppDialogAction(label: context.l10n.badgeActionAward, isPrimary: true, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
        child: AppDialogFormContent(
          fields: [
            AppDialogField(controller: userIdCtl, label: context.l10n.badgeFieldUserId, keyboardType: TextInputType.number),
            AppDialogField(controller: badgeIdCtl, label: context.l10n.badgeFieldBadgeId, keyboardType: TextInputType.number),
          ],
        ),
      ),
    );

    if (result != true) {
      userIdCtl.dispose(); badgeIdCtl.dispose();
      return;
    }

    final userId = int.tryParse(userIdCtl.text.trim());
    final badgeId = int.tryParse(badgeIdCtl.text.trim());
    userIdCtl.dispose(); badgeIdCtl.dispose();

    if (userId == null || badgeId == null) return;

    try {
      await ref.read(badgeRepositoryProvider).awardBadge(adminPassword: password, userId: userId, badgeId: badgeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.badgeAwarded(badgeId, userId))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SettingsScaffold(
      title: 'Badges',
      children: [
        SettingsNavBanner(
          icon: Icons.verified_rounded,
          title: 'Badges',
          subtitle: 'View and manage profile badges.',
          iconColor: Colors.amber,
        ),
        SettingsSection(
          title: 'Available Badges',
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
            if (_badges.isEmpty && !_loading)
              EmptyStateWidget(
                icon: Icons.workspace_premium_rounded,
                title: context.l10n.badgeNoBadges,
                subtitle: context.l10n.emptyStateNoItemsDesc,
              ),
            if (!_loading)
              ..._badges.map((badge) => ListTile(
                leading: BadgeChip(id: badge.id, name: badge.name, icon: badge.icon, color: badge.color, interactive: false),
                title: Text(badge.name, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('ID: ${badge.id}', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                trailing: _showAdmin
                    ? IconButton(
                        icon: Icon(Icons.delete_rounded, color: scheme.error),
                        onPressed: () => _deleteBadge(badge.id),
                      )
                    : null,
              )),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton.icon(
                  onPressed: _loading ? null : _loadBadges,
                  icon: Icon(Icons.refresh_rounded),
                  label: Text(context.l10n.badgeListRefresh),
                ),
              ),
            ),
          ],
        ),
        if (_showAdmin)
          SettingsSection(
            title: 'Admin Actions',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: context.l10n.badgeAdminPassword, prefixIcon: const Icon(Icons.lock_rounded)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(child: FilledButton.icon(onPressed: _createBadge, icon: const Icon(Icons.add_rounded), label: Text(context.l10n.badgeActionCreate))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: _awardBadge, icon: const Icon(Icons.person_add_rounded), label: Text(context.l10n.badgeActionAward))),
                  ],
                ),
              ),
            ],
          ),
        SettingsSwitchTile(
          icon: Icons.admin_panel_settings_rounded,
          title: context.l10n.badgeAdminMode,
          subtitle: context.l10n.badgeAdminSubtitle,
          value: _showAdmin,
          onChanged: (v) => setState(() => _showAdmin = v),
          iconColor: Colors.red,
        ),
      ],
    );
  }
}
