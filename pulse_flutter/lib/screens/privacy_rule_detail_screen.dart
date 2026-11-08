import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/widgets/common/user_search_picker_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class PrivacyRuleDetailScreen extends ConsumerStatefulWidget {
  const PrivacyRuleDetailScreen({required this.ruleKey, super.key});
  final String ruleKey;
  @override
  ConsumerState<PrivacyRuleDetailScreen> createState() =>
      _PrivacyRuleDetailScreenState();
}

class _PrivacyRuleDetailScreenState
    extends ConsumerState<PrivacyRuleDetailScreen> {
  late PrivacyPolicy _selectedPolicy;
  late List<int> _alwaysAllow;
  late List<int> _neverAllow;
  final _userCache = <int, ApiSearchUser>{};
  bool _saving = false;
  bool _picking = false;
  int _generation = 0;
  ProviderSubscription<PrivacyState>? _privacySubscription;
  ProviderSubscription<(int?, String?)>? _accountSubscription;

  @override
  void initState() {
    super.initState();
    _readRule();
    final chats = ref.read(chatsProvider).value ?? const [];
    for (final chat in chats) {
      if (chat.chatType == 'direct' && chat.partnerUserId != null) {
        final uid = chat.partnerUserId!;
        _userCache[uid] = ApiSearchUser(
          id: uid,
          username: chat.username ?? '',
          displayName: chat.name,
          avatarUrl: chat.avatarUrl,
          bio: chat.description,
          badges: chat.partnerBadges,
        );
      }
    }
    _loadMissingUsers();
    _privacySubscription = ref.listenManual(privacyProvider, (previous, next) {
      if (!mounted || _saving) return;
      if (next.rules[widget.ruleKey] != previous?.rules[widget.ruleKey]) {
        setState(_readRule);
      }
    });
    _accountSubscription = ref.listenManual(
      authProvider.select((a) => (a.session?.userId, a.session?.accessToken)),
      (_, _) {
        _generation++;
        _userCache.clear();
        if (mounted) {
          setState(() {
            _saving = false;
            _picking = false;
            _readRule();
          });
        }
      },
    );
  }

  void _readRule() {
    final rule =
        ref.read(privacyProvider).rules[widget.ruleKey] ??
        PrivacyRule(key: widget.ruleKey, policy: PrivacyPolicy.everyone);
    _selectedPolicy = rule.policy;
    _alwaysAllow = List.of(rule.alwaysAllow);
    _neverAllow = List.of(rule.neverAllow);
  }

  Future<void> _loadMissingUsers() async {
    final generation = _generation;
    final missing = {
      ..._alwaysAllow,
      ..._neverAllow,
    }.where((id) => !_userCache.containsKey(id)).toList();
    for (final id in missing) {
      if (!mounted || generation != _generation) return;
      try {
        final response = await ref
            .read(webSocketClientProvider)
            .request('get_profile', payload: {'user_id': id});
        if (!mounted || generation != _generation) return;
        if (response is Map) {
          final map = asStringMap(response)..['id'] = id;
          setState(() => _userCache[id] = ApiSearchUser.fromJson(map));
        }
      } catch (_) {
        // Unknown identities keep their numeric ID; never guess a chat ID.
      }
    }
  }

  Future<void> _saveRule({
    PrivacyPolicy? policy,
    List<int>? alwaysAllow,
    List<int>? neverAllow,
  }) async {
    if (_saving) return;
    final generation = _generation;
    setState(() {
      _selectedPolicy = policy ?? _selectedPolicy;
      _alwaysAllow = alwaysAllow ?? _alwaysAllow;
      _neverAllow = neverAllow ?? _neverAllow;
      _saving = true;
    });
    try {
      await ref
          .read(privacyProvider.notifier)
          .updateRule(
            key: widget.ruleKey,
            policy: _selectedPolicy,
            alwaysAllow: _alwaysAllow,
            neverAllow: _neverAllow,
          );
    } catch (_) {
      if (mounted && generation == _generation) {
        AppToast.showError(context, context.l10n.settingsPrivacySaveFailed);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _saving = false;
          _readRule();
        });
      }
    }
  }

  Future<void> _addException({required bool isAlwaysAllow}) async {
    if (_saving || _picking) return;
    final generation = _generation;
    setState(() => _picking = true);
    final picked = await showUserSearchPickerSheet(
      context,
      title: isAlwaysAllow
          ? context.l10n.privacyAlwaysAllow
          : context.l10n.privacyNeverAllow,
      subtitle: context.l10n.privacySelectUserSubtitle,
      hintText: context.l10n.searchByUsernameOrNameHint,
      excludedUserIds: (isAlwaysAllow ? _alwaysAllow : _neverAllow).toSet(),
    );
    if (!mounted || generation != _generation) return;
    setState(() => _picking = false);
    if (picked == null) return;
    _userCache[picked.id] = picked;
    await _saveRule(
      alwaysAllow: isAlwaysAllow
          ? {..._alwaysAllow, picked.id}.toList()
          : _alwaysAllow.where((id) => id != picked.id).toList(),
      neverAllow: !isAlwaysAllow
          ? {..._neverAllow, picked.id}.toList()
          : _neverAllow.where((id) => id != picked.id).toList(),
    );
  }

  @override
  void dispose() {
    _generation++;
    _privacySubscription?.close();
    _accountSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final privacy = ref.watch(privacyProvider);
    final busy =
        _saving ||
        _picking ||
        privacy.pendingRules.isNotEmpty ||
        privacy.pendingUsers.isNotEmpty;
    return SettingsShell(
      title: PrivacyRule.localizedKeyName(widget.ruleKey, context.l10n),
      actions: [
        if (_saving)
          const Padding(
            padding: EdgeInsets.all(16),
            child: AppLoadingIndicator(size: 22),
          ),
      ],
      children: [
        SettingsSection(
          title: context.l10n.privacyWhoCanInteract,
          children: [
            for (final policy in PrivacyPolicy.values)
              Semantics(
                checked: _selectedPolicy == policy,
                inMutuallyExclusiveGroup: true,
                child: SettingsListItem(
                  icon: _selectedPolicy == policy
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  title: policy.localized(context.l10n),
                  subtitle: switch (policy) {
                    PrivacyPolicy.everyone =>
                      context.l10n.privacyPolicyEveryoneDesc,
                    PrivacyPolicy.contacts =>
                      context.l10n.privacyPolicyContactsDesc,
                    PrivacyPolicy.nobody =>
                      context.l10n.privacyPolicyNobodyDesc,
                  },
                  type: SettingsListItemType.action,
                  isSelected: _selectedPolicy == policy,
                  enabled: !busy,
                  onTap: () => _saveRule(policy: policy),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  context.l10n.privacyExceptions,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.privacyExceptionsDesc,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _exceptionSection(true, busy),
        _exceptionSection(false, busy),
      ],
    );
  }

  Widget _exceptionSection(bool isAlwaysAllow, bool busy) {
    final ids = isAlwaysAllow ? _alwaysAllow : _neverAllow;
    return SettingsSection(
      title: isAlwaysAllow
          ? context.l10n.privacyAlwaysAllow
          : context.l10n.privacyNeverAllow,
      children: [
        SettingsListItem(
          icon: Icons.person_add_alt_1_rounded,
          title: context.l10n.privacyAddUserTooltip,
          subtitle: ids.isEmpty
              ? context.l10n.privacyNoAddedUsers
              : context.l10n.privacyUsersCount(ids.length),
          type: SettingsListItemType.action,
          enabled: !busy,
          onTap: () => _addException(isAlwaysAllow: isAlwaysAllow),
        ),
        if (ids.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in ids)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: InputChip(
                        avatar: _userCache[id] != null
                            ? PulseAvatar(
                                radius: 12,
                                name: _userCache[id]!.displayName,
                                avatarUrl: _userCache[id]!.avatarUrl,
                              )
                            : const Icon(
                                Icons.person_outline_rounded,
                                size: 20,
                              ),
                        label: Text(
                          _userCache[id]?.displayName ?? 'ID: $id',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        deleteButtonTooltipMessage: context.l10n.commonDelete,
                        onDeleted: busy
                            ? null
                            : () => _saveRule(
                                alwaysAllow: isAlwaysAllow
                                    ? ids.where((value) => value != id).toList()
                                    : null,
                                neverAllow: !isAlwaysAllow
                                    ? ids.where((value) => value != id).toList()
                                    : null,
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
