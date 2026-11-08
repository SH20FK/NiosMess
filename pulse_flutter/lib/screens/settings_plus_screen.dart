import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/widgets/plus_purchase_options.dart';
import 'package:pulse_flutter/widgets/motion/m3_reveal.dart';
import 'package:pulse_flutter/widgets/profile/ai_usage_card.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsPlusScreen extends ConsumerStatefulWidget {
  const SettingsPlusScreen({this.isEmbedded = false, super.key});
  final bool isEmbedded;
  @override
  ConsumerState<SettingsPlusScreen> createState() => _SettingsPlusScreenState();
}

class _SettingsPlusScreenState extends ConsumerState<SettingsPlusScreen> {
  bool _claimingTrial = false;
  bool _loadingStatus = true;
  bool _statusFailed = false;
  Map<String, dynamic>? _status;
  int _generation = 0;
  int _statusRequest = 0;
  ProviderSubscription<(int?, String?)>? _accountSubscription;

  (int?, String?) get _account {
    final session = ref.read(authProvider).session;
    return (session?.userId, session?.accessToken);
  }

  bool _isCurrent(int generation, (int?, String?) account) =>
      mounted &&
      generation == _generation &&
      account == _account &&
      !ref.read(authProvider.notifier).isLoggingOut;

  @override
  void initState() {
    super.initState();
    _accountSubscription = ref.listenManual(
      authProvider.select(
        (auth) => (auth.session?.userId, auth.session?.accessToken),
      ),
      (previous, next) {
        if (previous == next) return;
        _generation++;
        setState(() {
          _status = null;
          _claimingTrial = false;
        });
        unawaited(_loadStatus());
      },
    );
    unawaited(_loadStatus());
  }

  @override
  void dispose() {
    _generation++;
    _accountSubscription?.close();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final account = _account;
    final generation = _generation;
    final request = ++_statusRequest;
    setState(() {
      _loadingStatus = true;
      _statusFailed = false;
    });
    try {
      if (account.$1 == null || (account.$2 ?? '').isEmpty) {
        throw StateError('unauthenticated');
      }
      final response = await ref
          .read(webSocketClientProvider)
          .request('get_my_limits', payload: <String, dynamic>{});
      if (!_isCurrent(generation, account) || request != _statusRequest) return;
      if (response is! Map) throw const FormatException('invalid_limits');
      final status = Map<String, dynamic>.from(response);
      if (status['is_nios_plus'] is! bool) {
        throw const FormatException('invalid_limits');
      }
      setState(() => _status = status);
    } catch (_) {
      if (_isCurrent(generation, account) && request == _statusRequest) {
        setState(() => _statusFailed = true);
      }
    } finally {
      if (_isCurrent(generation, account) && request == _statusRequest) {
        setState(() => _loadingStatus = false);
      }
    }
  }

  Future<void> _claimTrial() async {
    if (_claimingTrial || _loadingStatus || _statusFailed || _status == null) {
      return;
    }
    final account = _account;
    final generation = _generation;
    if (!_isCurrent(generation, account) || account.$1 == null) return;
    setState(() => _claimingTrial = true);
    HapticService.selection();
    try {
      await ref
          .read(webSocketClientProvider)
          .request(
            'claim_nios_plus_trial',
            payload: <String, dynamic>{},
            maxRetries: 0,
          );
      if (!_isCurrent(generation, account)) return;
      await ref.read(authProvider.notifier).refreshProfile();
      if (!_isCurrent(generation, account)) return;
      await _loadStatus();
      if (mounted && _isCurrent(generation, account)) {
        AppToast.showSuccess(context, context.l10n.settingsPlusTrialActivated);
      }
    } catch (_) {
      if (!_isCurrent(generation, account)) return;
      await _loadStatus();
      if (mounted && _isCurrent(generation, account)) {
        AppToast.showError(context, context.l10n.settingsPlusTrialFailed);
      }
    } finally {
      if (_isCurrent(generation, account)) {
        setState(() => _claimingTrial = false);
      }
    }
  }

  DateTime? _parseDate(Object? raw) =>
      raw == null ? null : DateTime.tryParse(raw.toString());

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/main/chats');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final status = _status;
    final isPlus =
        status?['is_nios_plus'] == true ||
        (status == null && (auth.profile?.isNiosPlus ?? false));
    final trialUsed =
        status?['nios_plus_trial_used'] == true ||
        (status == null && (auth.profile?.niosPlusTrialUsed ?? false));
    final inGrace = status?['in_grace_period'] == true;
    final expiresAt = _parseDate(status?['nios_plus_expires_at']);
    final graceUntil = _parseDate(status?['grace_until']);
    final subtitle = isPlus
        ? expiresAt == null
              ? context.l10n.settingsPlusActive
              : context.l10n.settingsPlusActiveUntil(
                  formatFullDateTime(expiresAt),
                )
        : inGrace
        ? graceUntil == null
              ? context.l10n.settingsPlusGrace
              : context.l10n.settingsPlusGraceUntil(
                  formatFullDateTime(graceUntil),
                )
        : context.l10n.settingsPlusSummary;
    return SettingsShell(
      title: 'Nios+',
      isEmbedded: widget.isEmbedded,
      onRefresh: _loadStatus,
      leading: widget.isEmbedded
          ? null
          : IconButton(
              tooltip: context.l10n.groupBack,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _close,
            ),
      children: [
        SettingsSection(
          children: [
            SettingsListItem(
              type: SettingsListItemType.value,
              icon: Icons.workspace_premium_rounded,
              title: _loadingStatus ? context.l10n.commonLoading : 'Nios+',
              subtitle: _statusFailed
                  ? context.l10n.settingsPlusStatusFailed
                  : subtitle,
              pending: _loadingStatus,
            ),
            if (_statusFailed)
              SettingsListItem(
                type: SettingsListItemType.action,
                icon: Icons.refresh_rounded,
                title: context.l10n.commonRetry,
                onTap: _loadStatus,
              ),
          ],
        ),
        if (auth.profile?.aiUsage != null) ...[
          AiUsageIndicatorCard(usage: auth.profile!.aiUsage!),
          const SizedBox(height: 16),
        ],
        SettingsSection(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: PlusPurchaseOptions(
                key: ValueKey(_account),
                onChanged: _loadStatus,
              ),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsPlusBenefits,
          children: [
            for (final row in <(IconData, String, String)>[
              (
                Icons.auto_awesome_rounded,
                context.l10n.settingsPlusAiBudget,
                context.l10n.settingsPlusAiBudgetHint,
              ),
              (
                Icons.psychology_alt_rounded,
                'NiosAI Prime · SPrime',
                context.l10n.settingsPlusModelsHint,
              ),
              (
                Icons.attach_file_rounded,
                context.l10n.settingsPlusFiles,
                context.l10n.settingsPlusFilesHint,
              ),
              (
                Icons.forum_rounded,
                context.l10n.settingsPlusCommunities,
                context.l10n.settingsPlusCommunitiesHint,
              ),
              (
                Icons.emoji_emotions_outlined,
                context.l10n.settingsPlusEmoji,
                context.l10n.settingsPlusEmojiHint,
              ),
              (
                Icons.event_repeat_rounded,
                context.l10n.settingsPlusGracePeriod,
                context.l10n.settingsPlusGracePeriodHint,
              ),
            ])
              SettingsInfoTile(icon: row.$1, title: row.$2, subtitle: row.$3),
          ],
        ),
        M3Reveal(
          duration: M3Durations.medium2,
          revealed:
              !_loadingStatus &&
              !_statusFailed &&
              status != null &&
              !isPlus &&
              !trialUsed,
          child: FilledButton.icon(
            onPressed: _claimingTrial ? null : _claimTrial,
            icon: _claimingTrial
                ? const AppLoadingIndicator(size: 20)
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(
              _claimingTrial
                  ? context.l10n.settingsPlusTrialPending
                  : context.l10n.settingsPlusTrial,
            ),
          ),
        ),
      ],
    );
  }
}
