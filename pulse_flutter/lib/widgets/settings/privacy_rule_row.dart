import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/widgets/settings/settings_pane_scope.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/features/settings/presentation/settings_row.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/widgets/common/app_action_menu_item.dart';
import 'package:pulse_flutter/widgets/motion/m3_entrance.dart';
import 'package:pulse_flutter/widgets/settings/settings_list_item.dart';

/// One visibility rule: who is allowed. The answer is picked from a menu on
/// the row itself; the rule's own screen is kept for per-person exceptions.
class PrivacyRuleRow extends ConsumerStatefulWidget {
  const PrivacyRuleRow({
    required this.ruleKey,
    required this.anchor,
    required this.icon,
    required this.title,
    this.enabled = true,
    super.key,
  });

  /// Server key of the rule, such as `last_seen`.
  final String ruleKey;

  /// Search anchor of the row.
  final String anchor;
  final IconData icon;
  final String title;
  final bool enabled;

  @override
  ConsumerState<PrivacyRuleRow> createState() => _PrivacyRuleRowState();
}

class _PrivacyRuleRowState extends ConsumerState<PrivacyRuleRow> {
  final MenuController _menu = MenuController();

  Future<void> _choose(PrivacyPolicy policy) async {
    if (policy == ref.read(privacyProvider).policyFor(widget.ruleKey)) return;
    HapticService.selection();
    try {
      // Exceptions of the rule are kept: only the base answer changes.
      await ref
          .read(privacyProvider.notifier)
          .updateRule(key: widget.ruleKey, policy: policy);
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, context.l10n.settingsPrivacySaveFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final PrivacyPolicy current = ref.watch(
      privacyProvider.select((PrivacyState s) => s.policyFor(widget.ruleKey)),
    );
    return MenuAnchor(
      controller: _menu,
      menuChildren: <Widget>[
        // The menu is mounted anew on every opening, so the options rise
        // into place one after another each time.
        for (final (int index, PrivacyPolicy policy)
            in PrivacyPolicy.values.indexed)
          M3Entrance(
            delay: Duration(milliseconds: 20 * index),
            offsetY: 6,
            child: Semantics(
              checked: policy == current,
              inMutuallyExclusiveGroup: true,
              child: AppActionMenuItem(
                label: policy.localized(l),
                icon: policy == current
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                onPressed: () => unawaited(_choose(policy)),
              ).toMenuItem(context),
            ),
          ),
        const Divider(height: 8),
        M3Entrance(
          delay: Duration(milliseconds: 20 * PrivacyPolicy.values.length),
          offsetY: 6,
          child: AppActionMenuItem(
            label: l.privacyExceptions,
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => openSettingsPage(
              context,
              '/settings/privacy/rule/${widget.ruleKey}',
            ),
          ).toMenuItem(context),
        ),
      ],
      child: SettingsAnchor(
        id: widget.anchor,
        child: SettingsListItem(
          key: ValueKey<String>('settings-privacy-rule-${widget.ruleKey}'),
          type: SettingsListItemType.choice,
          icon: widget.icon,
          title: widget.title,
          value: current.localized(l),
          enabled: widget.enabled,
          onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
        ),
      ),
    );
  }
}
