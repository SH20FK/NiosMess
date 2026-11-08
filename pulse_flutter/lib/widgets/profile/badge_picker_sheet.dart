import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/modal/app_modal_content.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class BadgePickerSheet extends ConsumerStatefulWidget {
  const BadgePickerSheet({this.initialSelectedBadgeIds = const [], super.key});
  final List<int> initialSelectedBadgeIds;

  static Future<List<int>?> show(
    BuildContext context, {
    List<int> initialSelectedBadgeIds = const [],
  }) {
    Widget builder(BuildContext context) =>
        BadgePickerSheet(initialSelectedBadgeIds: initialSelectedBadgeIds);
    return MediaQuery.sizeOf(context).width >= Breakpoints.medium
        ? AppModal.showDialog<List<int>>(
            context: context,
            maxWidth: 480,
            builder: builder,
            isDismissible: false,
          )
        : AppModal.showSheet<List<int>>(
            context: context,
            builder: builder,
            isDismissible: false,
            enableDrag: false,
            showDragHandle: false,
          );
  }

  @override
  ConsumerState<BadgePickerSheet> createState() => _BadgePickerSheetState();
}

typedef BadgeSelectorDialog = BadgePickerSheet;

class _BadgePickerSheetState extends ConsumerState<BadgePickerSheet> {
  List<ApiBadge> _badges = const [];
  final Set<int> _selected = {};
  bool _loading = true;
  bool _failed = false;
  bool _saving = false;
  bool _allowPop = false;
  late final int? _accountId;
  late final String? _token;

  @override
  void initState() {
    super.initState();
    final session = ref.read(authProvider).session;
    _accountId = session?.userId;
    _token = session?.accessToken;
    _selected.addAll(widget.initialSelectedBadgeIds.take(2));
    _load();
  }

  bool get _ownsSession {
    final current = ref.read(authProvider).session;
    return current?.userId == _accountId &&
        current?.accessToken == _token &&
        !ref.read(authProvider.notifier).isLoggingOut;
  }

  Future<void> _load() async {
    if (!_ownsSession) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final badges = await ref.read(authRepositoryProvider).getMyBadges();
      if (!mounted || !_ownsSession) return;
      setState(() {
        _badges = badges.where((badge) => badge.id > 0).toList(growable: false);
        final available = _badges.map((badge) => badge.id).toSet();
        _selected.removeWhere((id) => !available.contains(id));
        _loading = false;
      });
    } catch (_) {
      if (mounted && _ownsSession) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _toggle(int id) {
    if (_saving || !_ownsSession) return;
    if (!_selected.contains(id) && _selected.length >= 2) {
      AppToast.showError(context, context.l10n.settingsBadgePickerLimit);
      return;
    }
    setState(
      () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
    );
  }

  Future<void> _close() async {
    if (_saving) return;
    final initial = widget.initialSelectedBadgeIds.take(2).toSet();
    if (_ownsSession &&
        !_loading &&
        !_failed &&
        (initial.length != _selected.length ||
            !initial.containsAll(_selected))) {
      final discard = await showAppConfirmDialog(
        context: context,
        title: context.l10n.commonDiscardChanges,
        subtitle: context.l10n.commonDiscardChangesDesc,
        confirmLabel: context.l10n.commonDiscardChangesConfirm,
        cancelLabel: context.l10n.commonCancel,
        destructive: true,
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_saving || _loading || _failed || !_ownsSession || _accountId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(authRepositoryProvider)
          .setVisibleBadges(_selected.toList(growable: false));
      if (!mounted || !_ownsSession) return;
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted || !_ownsSession) return;
      setState(() => _allowPop = true);
      Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted && _ownsSession) {
        AppToast.showError(context, context.l10n.settingsBadgePickerSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  IconData _icon(ApiBadge badge) => switch (badge.icon.toLowerCase().trim()) {
    'star' => Icons.star_rounded,
    'shield' => Icons.shield_rounded,
    'code' => Icons.code_rounded,
    'bug' => Icons.pest_control_rounded,
    'workspace_premium' || 'crown' => Icons.workspace_premium_rounded,
    _ => Icons.verified_rounded,
  };

  @override
  Widget build(BuildContext context) {
    ref.watch(
      authProvider.select(
        (state) => (state.session?.userId, state.session?.accessToken),
      ),
    );
    final l = context.l10n;
    final owns = _ownsSession;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _close();
      },
      child: AppModalContent(
        title: l.settingsBadgePickerTitle,
        subtitle: owns
            ? l.settingsBadgePickerHint
            : l.settingsProfileAccountChanged,
        icon: Icons.verified_outlined,
        actions: [
          AppDialogAction(
            label: l.commonCancel,
            onPressed: _saving ? null : _close,
          ),
          if (owns)
            AppDialogAction(
              label: l.commonSave,
              isPrimary: true,
              isLoading: _saving,
              onPressed: _saving || _loading || _failed || _accountId == null ? null : _save,
            ),
        ],
        child: !owns
            ? const SizedBox.shrink()
            : _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: AppLoadingIndicator()),
              )
            : _failed
            ? SettingsSection(
                children: [
                  SettingsListItem.nav(
                    icon: Icons.refresh_rounded,
                    title: l.settingsBadgePickerLoadFailed,
                    value: l.commonRetry,
                    onTap: _load,
                  ),
                ],
              )
            : _badges.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(l.settingsBadgePickerEmpty),
              )
            : SettingsSection(
                title:
                    '${l.settingsBadgePickerSelected}: ${_selected.length}/2',
                children: [
                  for (final badge in _badges)
                    SettingsListItem(
                      icon: _icon(badge),
                      title: badge.name,
                      subtitle: badge.description,
                      isSection: true,
                      isSelected: _selected.contains(badge.id),
                      enabled: !_saving,
                      trailing: Icon(
                        _selected.contains(badge.id)
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                      ),
                      onTap: () => _toggle(badge.id),
                    ),
                ],
              ),
      ),
    );
  }
}
