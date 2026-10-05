import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class SettingsPlusScreen extends ConsumerStatefulWidget {
  const SettingsPlusScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  @override
  ConsumerState<SettingsPlusScreen> createState() => _SettingsPlusScreenState();
}

class _SettingsPlusScreenState extends ConsumerState<SettingsPlusScreen> {
  bool _claimingTrial = false;
  bool _loadingStatus = true;
  Map<String, dynamic>? _status;
  int _selectedTierIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final dynamic res = await ref
          .read(webSocketClientProvider)
          .request('get_my_limits', payload: <String, dynamic>{});
      if (mounted) {
        setState(() {
          _status = res is Map ? Map<String, dynamic>.from(res) : null;
          _loadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingStatus = false);
      }
    }
  }

  Future<void> _claimTrial() async {
    if (_claimingTrial) return;
    setState(() => _claimingTrial = true);
    HapticService.selection();

    try {
      await ref
          .read(webSocketClientProvider)
          .request('claim_nios_plus_trial', payload: <String, dynamic>{});
      await ref.read(authProvider.notifier).refreshProfile();
      await _loadStatus();
      if (mounted) {
        AppToast.showSuccess(
          context,
          'Пробный день Nios Plus включён',
        );
      }
    } on ApiException catch (e) {
      await _loadStatus();
      if (mounted) {
        AppToast.showInfo(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Не удалось активировать пробный период');
      }
    } finally {
      if (mounted) {
        setState(() => _claimingTrial = false);
      }
    }
  }

  DateTime? _parseDate(Object? raw) =>
      raw == null ? null : DateTime.tryParse(raw.toString());

  void _onBuyPressed() {
    HapticService.tap();
    AppToast.showInfo(context, 'Оплата пока недоступна');
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Map<String, dynamic>? status = _status;
    final bool isPlus = status != null
        ? status['is_nios_plus'] == true
        : (auth.profile?.isNiosPlus ?? false);
    final bool trialUsed = status != null
        ? status['nios_plus_trial_used'] == true
        : (auth.profile?.niosPlusTrialUsed ?? false);
    final bool inGrace = status?['in_grace_period'] == true;
    final DateTime? expiresAt = _parseDate(status?['nios_plus_expires_at']);
    final DateTime? graceUntil = _parseDate(status?['grace_until']);

    final Widget statusLine = _loadingStatus
        ? const AppLoadingIndicator(size: 22)
        : Text(
            isPlus
                ? (expiresAt != null
                    ? 'Подписка активна до ${formatFullDateTime(expiresAt)}'
                    : 'Подписка активна')
                : inGrace
                    ? (graceUntil != null
                        ? 'Подписка закончилась. Расширенные лимиты сохраняются до ${formatFullDateTime(graceUntil)}'
                        : 'Подписка закончилась, идёт льготный период')
                    : trialUsed
                        ? 'Пробный период уже использован'
                        : 'Подписка не подключена',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          );

    return SettingsShell(
      title: 'Nios Plus',
      isEmbedded: widget.isEmbedded,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Align(alignment: Alignment.centerLeft, child: statusLine),
        ),
        if (!_loadingStatus && !isPlus && !inGrace && !trialUsed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _claimingTrial ? null : _claimTrial,
                child: const Text('Включить пробный день'),
              ),
            ),
          ),
        SettingsSection(
          title: 'Лимиты с подпиской',
          children: <Widget>[
            SettingsListItem.value(
              icon: Icons.upload_file_rounded,
              title: 'Файлы до 100 МБ',
              subtitle: 'Без подписки 30 МБ',
              iconColor: scheme.onSurfaceVariant,
            ),
            SettingsListItem.value(
              icon: Icons.auto_awesome_rounded,
              title: '200 000 символов ИИ за 72 часа',
              subtitle: 'Без подписки 50 000',
              iconColor: scheme.onSurfaceVariant,
            ),
            SettingsListItem.value(
              icon: Icons.campaign_rounded,
              title: '220 публичных каналов и 220 групп',
              subtitle: 'Без подписки по 110',
              iconColor: scheme.onSurfaceVariant,
            ),
            SettingsListItem.value(
              icon: Icons.emoji_emotions_rounded,
              title: '100 наборов эмодзи',
              subtitle: 'Без подписки 50',
              iconColor: scheme.onSurfaceVariant,
            ),
            SettingsListItem.value(
              icon: Icons.verified_rounded,
              title: 'Статус-эмодзи рядом с именем',
              subtitle: 'Виден всем собеседникам',
              iconColor: scheme.onSurfaceVariant,
            ),
            SettingsListItem.value(
              icon: Icons.shield_moon_rounded,
              title: 'Льготный период 5 дней',
              subtitle: 'После окончания подписки лимиты сжимаются через пять дней, данные не удаляются',
              iconColor: scheme.onSurfaceVariant,
            ),
          ],
        ),
        if (!isPlus && !_loadingStatus) ...<Widget>[
          const SizedBox(height: 16),
          SettingsSection(
            title: 'Тариф',
            children: <Widget>[
              for (final (int i, String title, String price) in <(int, String, String)>[
                (0, '1 месяц', '299 ₽ в месяц'),
                (1, '12 месяцев', '199 ₽ в месяц, 2 388 ₽ за год'),
              ])
                ListTile(
                  selected: _selectedTierIndex == i,
                  title: Text(title),
                  subtitle: Text(price),
                  trailing: _selectedTierIndex == i
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    HapticService.selection();
                    setState(() => _selectedTierIndex = i);
                  },
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _onBuyPressed,
                    child: Text(
                      _selectedTierIndex == 1
                          ? 'Оплатить 2 388 ₽'
                          : 'Оплатить 299 ₽',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
