// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/privacy_model.dart';
import 'package:pulse_flutter/providers/privacy_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/common/app_pill_field.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

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
    final TextEditingController idController = TextEditingController();
    final int? id = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => AppDialog(
        title: isAlwaysAllow ? 'Всегда разрешать' : 'Никогда не разрешать',
        subtitle: 'Укажите числовой идентификатор пользователя',
        actions: <AppDialogAction>[
          AppDialogAction(
            label: 'Отмена',
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppDialogAction(
            label: 'Добавить',
            isPrimary: true,
            onPressed: () {
              final int? parsed = int.tryParse(idController.text.trim());
              if (parsed != null) {
                Navigator.of(context).pop(parsed);
              }
            },
          ),
        ],
        child: AppPillField(
          controller: idController,
          keyboardType: TextInputType.number,
          autofocus: true,
          hintText: 'ID пользователя (например, 42)',
        ),
      ),
    );

    if (id == null || !mounted) return;

    setState(() {
      if (isAlwaysAllow) {
        if (!_alwaysAllow.contains(id)) _alwaysAllow.add(id);
      } else {
        if (!_neverAllow.contains(id)) _neverAllow.add(id);
      }
    });

    await ref.read(privacyProvider.notifier).updateRule(
          key: widget.ruleKey,
          policy: _selectedPolicy,
          alwaysAllow: _alwaysAllow,
          neverAllow: _neverAllow,
        );
  }

  Future<void> _removeException(int id, {required bool isAlwaysAllow}) async {
    setState(() {
      if (isAlwaysAllow) {
        _alwaysAllow.remove(id);
      } else {
        _neverAllow.remove(id);
      }
    });

    await ref.read(privacyProvider.notifier).updateRule(
          key: widget.ruleKey,
          policy: _selectedPolicy,
          alwaysAllow: _alwaysAllow,
          neverAllow: _neverAllow,
        );
  }

  @override
  Widget build(BuildContext context) {
    final String title = PrivacyRule.localizedKeyName(widget.ruleKey);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: <Widget>[
          SettingsSection(
            title: 'Кто может видеть / взаимодействовать',
            children: <Widget>[
              RadioListTile<PrivacyPolicy>(
                value: PrivacyPolicy.everyone,
                groupValue: _selectedPolicy,
                title: const Text('Все'),
                subtitle: const Text('Доступно всем пользователям NiosMess'),
                onChanged: (PrivacyPolicy? val) {
                  if (val != null) _savePolicy(val);
                },
              ),
              RadioListTile<PrivacyPolicy>(
                value: PrivacyPolicy.contacts,
                groupValue: _selectedPolicy,
                title: const Text('Мои контакты'),
                subtitle: const Text('Только пользователи из списка диалогов'),
                onChanged: (PrivacyPolicy? val) {
                  if (val != null) _savePolicy(val);
                },
              ),
              RadioListTile<PrivacyPolicy>(
                value: PrivacyPolicy.nobody,
                groupValue: _selectedPolicy,
                title: const Text('Никто'),
                subtitle: const Text('Скрыто от всех (кроме исключений)'),
                onChanged: (PrivacyPolicy? val) {
                  if (val != null) _savePolicy(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: 'Исключения',
            subtitle: 'Исключения имеют приоритет над основным правилом',
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.check_circle_outline_rounded,
                    color: Colors.green.shade600),
                title: const Text('Всегда разрешать'),
                subtitle: Text(_alwaysAllow.isEmpty
                    ? 'Нет добавленных пользователей'
                    : 'Пользователей: ${_alwaysAllow.length}'),
                trailing: IconButton(
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  onPressed: () => _addException(isAlwaysAllow: true),
                  tooltip: 'Добавить пользователя',
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
                      return Chip(
                        label: Text('ID: $id'),
                        deleteIcon: const Icon(Icons.close, size: 16),
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
                title: const Text('Никогда не разрешать'),
                subtitle: Text(_neverAllow.isEmpty
                    ? 'Нет добавленных пользователей'
                    : 'Пользователей: ${_neverAllow.length}'),
                trailing: IconButton(
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  onPressed: () => _addException(isAlwaysAllow: false),
                  tooltip: 'Добавить пользователя',
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
                      return Chip(
                        label: Text('ID: $id'),
                        deleteIcon: const Icon(Icons.close, size: 16),
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
