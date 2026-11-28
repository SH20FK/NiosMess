import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
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

  /// The store is the only place that sells or activates anything, so both
  /// entries of the page lead there. The status is reloaded after the return,
  /// which is what the store's own refresh callback used to do.
  Future<void> _openStore() async {
    await openSettingsPage(context, '/settings/plus/store');
    if (mounted) await _loadStatus();
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
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // The first load has no status to show yet; the cached profile answers
    // only after it. Until then the hero holds placeholder rows instead of
    // inventing a state.
    final bool shaping = _loadingStatus && status == null;
    return SettingsShell(
      title: 'Nios+',
      isEmbedded: widget.isEmbedded,
      onRefresh: _loadStatus,
      leading: widget.isEmbedded ? null : SettingsBackButton(onPressed: _close),
      hero: SettingsHeroCard(
        label: 'Nios+',
        leadingIcon: Icons.workspace_premium_rounded,
        child: shaping
            ? const SettingsSkeleton(rows: 1, showLeading: false)
            : Text(
                subtitle,
                style: text.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
      ),
      children: [
        // The failed check, and one way back; the hero above keeps whatever
        // the cached profile already knew.
        if (_statusFailed)
          SettingsErrorSection(
            message: context.l10n.settingsPlusStatusFailed,
            onRetry: _loadStatus,
          ),
        M3Reveal(
          duration: M3Durations.medium2,
          revealed:
              !_loadingStatus &&
              !_statusFailed &&
              status != null &&
              !isPlus &&
              !trialUsed,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
        ),
        // A subscriber keeps the subscription from the hero down; the trial is
        // spent or still on offer, and the page says which.
        // The store is a native page; on the web the row below explains that
        // instead of quietly bouncing back to this screen.
        if (!kIsWeb && (isPlus || inGrace))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: FilledButton.tonalIcon(
              onPressed: _openStore,
              icon: const Icon(Icons.workspace_premium_rounded),
              label: Text(context.l10n.settingsPlusManageSubscription),
            ),
          ),
        if (auth.profile?.aiUsage != null) ...[
          AiUsageIndicatorCard(usage: auth.profile!.aiUsage!),
          const SizedBox(height: AppSpacing.lg),
        ],
        SettingsSection(
          children: <Widget>[
            if (!isPlus && trialUsed)
              SettingsListItem.value(
                icon: Icons.auto_awesome_outlined,
                title: context.l10n.settingsPlusTrialUsed,
              ),
            if (kIsWeb)
              SettingsListItem.value(
                icon: Icons.info_outline_rounded,
                title: context.l10n.auditPlusNativeOnly,
              )
            else
              SettingsListItem.nav(
                key: const ValueKey<String>('settings-plus-store'),
                icon: Icons.storefront_rounded,
                title: context.l10n.auditPlusPurchaseTitle,
                onTap: _openStore,
              ),
          ],
        ),
        // What the subscription gives, grouped by what it changes. One list,
        // read once: the groups are the plan's own three areas.
        SettingsSection(
          // A brand name, written the same in every language.
          title: 'NiosAI',
          accentIcon: Icons.auto_awesome_rounded,
          children: <Widget>[
            SettingsListItem.value(
              icon: Icons.auto_awesome_rounded,
              title: context.l10n.settingsPlusAiBudget,
              subtitle: context.l10n.settingsPlusAiBudgetHint,
            ),
            SettingsListItem.value(
              icon: Icons.psychology_alt_rounded,
              title: 'NiosAI Prime · SPrime',
              subtitle: context.l10n.settingsPlusModelsHint,
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsPlusGroupMessenger,
          accentIcon: Icons.forum_rounded,
          children: <Widget>[
            SettingsListItem.value(
              icon: Icons.attach_file_rounded,
              title: context.l10n.settingsPlusFiles,
              subtitle: context.l10n.settingsPlusFilesHint,
            ),
            SettingsListItem.value(
              icon: Icons.forum_rounded,
              title: context.l10n.settingsPlusCommunities,
              subtitle: context.l10n.settingsPlusCommunitiesHint,
            ),
            SettingsListItem.value(
              icon: Icons.event_repeat_rounded,
              title: context.l10n.settingsPlusGracePeriod,
              subtitle: context.l10n.settingsPlusGracePeriodHint,
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.settingsV2Appearance,
          accentIcon: Icons.emoji_emotions_outlined,
          children: <Widget>[
            SettingsListItem.value(
              icon: Icons.emoji_emotions_outlined,
              title: context.l10n.settingsPlusEmoji,
              subtitle: context.l10n.settingsPlusEmojiHint,
            ),
          ],
        ),
      ],
    );
  }
}
