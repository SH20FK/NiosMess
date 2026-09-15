// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/widgets/common/user_search_picker_sheet.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class PrivacyRuleDetailScreen extends ConsumerStatefulWidget {
  const PrivacyRuleDetailScreen({
    required this.ruleKey,
    super.key,
  });

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
  final Map<int, ApiSearchUser> _userCache = <int, ApiSearchUser>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final PrivacyState state = ref.read(privacyProvider);
    final PrivacyRule rule = state.rules[widget.ruleKey] ??
        PrivacyRule(key: widget.ruleKey, policy: PrivacyPolicy.everyone);
    _selectedPolicy = rule.policy;
    _alwaysAllow = List<int>.from(rule.alwaysAllow);
    _neverAllow = List<int>.from(rule.neverAllow);

    final chats = ref.read(chatsProvider).value ?? const [];
    for (final chat in chats) {
      if (chat.chatType == 'direct') {
        final int uid = chat.partnerUserId ?? chat.id;
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

    Future<void>.microtask(() async {
      final List<int> missingIds = <int>{..._alwaysAllow, ..._neverAllow}
          .where((int id) => !_userCache.containsKey(id))
          .toList();
      if (missingIds.isEmpty) return;
      for (final int id in missingIds) {
        try {
          final dynamic res = await ref.read(webSocketClientProvider).request(
            'get_profile',
            payload: <String, dynamic>{'user_id': id},
          );
          if (res is Map && mounted) {
            final Map<String, dynamic> map = asStringMap(res);
            map['id'] = id;
            final ApiSearchUser user = ApiSearchUser.fromJson(map);
            setState(() {
              _userCache[id] = user;
            });
          }
        } catch (_) {}
      }
    });

    ref.listenManual<PrivacyState>(privacyProvider, (previous, next) {
      if (!mounted || _saving) return;
      final PrivacyRule? newRule = next.rules[widget.ruleKey];
      if (newRule != null && newRule != previous?.rules[widget.ruleKey]) {
        setState(() {
          _selectedPolicy = newRule.policy;
          _alwaysAllow = List<int>.from(newRule.alwaysAllow);
          _neverAllow = List<int>.from(newRule.neverAllow);
        });
      }
    });
  }

  Future<void> _savePolicy(PrivacyPolicy policy) async {
    setState(() {
      _selectedPolicy = policy;
      _saving = true;
    });

    try {
      await ref.read(privacyProvider.notifier).updateRule(
            key: widget.ruleKey,
            policy: policy,
            alwaysAllow: _alwaysAllow,
            neverAllow: _neverAllow,
          );
    } catch (e) {
      if (mounted) AppToast.showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addException({required bool isAlwaysAllow}) async {
    final Set<int> alreadyExcluded = isAlwaysAllow
        ? _alwaysAllow.toSet()
        : _neverAllow.toSet();

    final ApiSearchUser? picked = await showUserSearchPickerSheet(
      context,
      title: isAlwaysAllow
          ? context.l10n.privacyAlwaysAllow
          : context.l10n.privacyNeverAllow,
      subtitle: context.l10n.privacySelectUserSubtitle,
      hintText: context.l10n.searchByUsernameOrNameHint,
      excludedUserIds: alreadyExcluded,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _userCache[picked.id] = picked;
      if (isAlwaysAllow) {
        if (!_alwaysAllow.contains(picked.id)) _alwaysAllow.add(picked.id);
        _neverAllow.remove(picked.id);
      } else {
        if (!_neverAllow.contains(picked.id)) _neverAllow.add(picked.id);
        _alwaysAllow.remove(picked.id);
      }
    });

    try {
      await ref.read(privacyProvider.notifier).updateRule(
            key: widget.ruleKey,
            policy: _selectedPolicy,
            alwaysAllow: _alwaysAllow,
            neverAllow: _neverAllow,
          );
    } catch (e) {
      if (mounted) AppToast.showError(context, e);
    }
  }

  Future<void> _removeException(int id, {required bool isAlwaysAllow}) async {
    setState(() {
      if (isAlwaysAllow) {
        _alwaysAllow.remove(id);
      } else {
        _neverAllow.remove(id);
      }
    });

    try {
      await ref.read(privacyProvider.notifier).updateRule(
            key: widget.ruleKey,
            policy: _selectedPolicy,
            alwaysAllow: _alwaysAllow,
            neverAllow: _neverAllow,
          );
    } catch (e) {
      if (mounted) AppToast.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = PrivacyRule.localizedKeyName(widget.ruleKey, context.l10n);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: AppLoadingIndicator(size: 18),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: <Widget>[
          SettingsSection(
            title: context.l10n.privacyWhoCanInteract,
            children: <Widget>[
              RadioListTile<PrivacyPolicy>(
                value: PrivacyPolicy.everyone,
                groupValue: _selectedPolicy,
                title: Text(context.l10n.privacyPolicyEveryone),
                subtitle: Text(context.l10n.privacyPolicyEveryoneDesc),
                onChanged: (PrivacyPolicy? val) {
                  if (val != null) _savePolicy(val);
                },
              ),
              RadioListTile<PrivacyPolicy>(
                value: PrivacyPolicy.contacts,
                groupValue: _selectedPolicy,
                title: Text(context.l10n.privacyPolicyContacts),
                subtitle: Text(context.l10n.privacyPolicyContactsDesc),
                onChanged: (PrivacyPolicy? val) {
                  if (val != null) _savePolicy(val);
                },
              ),
              RadioListTile<PrivacyPolicy>(
                value: PrivacyPolicy.nobody,
                groupValue: _selectedPolicy,
                title: Text(context.l10n.privacyPolicyNobody),
                subtitle: Text(context.l10n.privacyPolicyNobodyDesc),
                onChanged: (PrivacyPolicy? val) {
                  if (val != null) _savePolicy(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: context.l10n.privacyExceptions,
            subtitle: context.l10n.privacyExceptionsDesc,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.check_circle_outline_rounded,
                    color: scheme.primary),
                title: Text(context.l10n.privacyAlwaysAllow),
                subtitle: Text(_alwaysAllow.isEmpty
                    ? context.l10n.privacyNoAddedUsers
                    : context.l10n.privacyUsersCount(_alwaysAllow.length)),
                trailing: IconButton(
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  onPressed: () => _addException(isAlwaysAllow: true),
                  tooltip: context.l10n.privacyAddUserTooltip,
                ),
              ),
              if (_alwaysAllow.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _alwaysAllow.map((int id) {
                      final ApiSearchUser? user = _userCache[id];
                      final String label = user != null && user.username.isNotEmpty
                          ? '@${user.username}'
                          : (user?.displayName ?? 'ID: $id');
                      return Chip(
                        avatar: user != null
                            ? PulseAvatar(
                                radius: 11,
                                name: user.displayName,
                                avatarUrl: user.avatarUrl,
                              )
                            : const Icon(Icons.person_outline_rounded, size: 16),
                        label: Text(label),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        onDeleted: () =>
                            _removeException(id, isAlwaysAllow: true),
                      );
                    }).toList(),
                  ),
                ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.do_not_disturb_on_outlined,
                    color: scheme.error),
                title: Text(context.l10n.privacyNeverAllow),
                subtitle: Text(_neverAllow.isEmpty
                    ? context.l10n.privacyNoAddedUsers
                    : context.l10n.privacyUsersCount(_neverAllow.length)),
                trailing: IconButton(
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  onPressed: () => _addException(isAlwaysAllow: false),
                  tooltip: context.l10n.privacyAddUserTooltip,
                ),
              ),
              if (_neverAllow.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _neverAllow.map((int id) {
                      final ApiSearchUser? user = _userCache[id];
                      final String label = user != null && user.username.isNotEmpty
                          ? '@${user.username}'
                          : (user?.displayName ?? 'ID: $id');
                      return Chip(
                        avatar: user != null
                            ? PulseAvatar(
                                radius: 11,
                                name: user.displayName,
                                avatarUrl: user.avatarUrl,
                              )
                            : const Icon(Icons.person_outline_rounded, size: 16),
                        label: Text(label),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        onDeleted: () =>
                            _removeException(id, isAlwaysAllow: false),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
