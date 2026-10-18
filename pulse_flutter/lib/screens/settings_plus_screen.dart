import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/plus_purchase_options.dart';

class SettingsPlusScreen extends ConsumerStatefulWidget {
  const SettingsPlusScreen({this.isEmbedded = false, super.key});

  final bool isEmbedded;

  @override
  ConsumerState<SettingsPlusScreen> createState() => _SettingsPlusScreenState();
}

class _SettingsPlusScreenState extends ConsumerState<SettingsPlusScreen> {
  bool _claimingTrial = false;
  bool _loadingStatus = true;
  Map<String, dynamic>? _status;

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
          'Пробный период Nios+ на 1 день активирован',
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

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/main/chats');
    }
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

    return SettingsShell(
      title: 'NiosPlus',
      isEmbedded: widget.isEmbedded,
      leading: widget.isEmbedded
          ? null
          : TextButton(
              onPressed: _close,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('Назад'),
            ),
      children: <Widget>[
        if (_loadingStatus)
          const AppLoadingIndicator(size: 24)
        else if (isPlus)
          Text(
            expiresAt == null
                ? 'Подписка активна'
                : 'Действует до ${formatFullDateTime(expiresAt)}',
          )
        else if (inGrace)
          Text(
            graceUntil == null
                ? 'Подписка закончилась. Настройки каналов, групп и эмодзи пока сохранены.'
                : 'Настройки каналов, групп и эмодзи сохраняются до ${formatFullDateTime(graceUntil)}',
          )
        else
          const Text(
            '300 Ниосиков для NiosAI, доступ к Prime и SPrime, файлы до 100 МБ и расширенные возможности мессенджера.',
          ),
        const SizedBox(height: 28),
        PlusPurchaseOptions(onChanged: _loadStatus),
        const SizedBox(height: 32),
        Text('В подписке', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final row in <(String, String)>[
          (
            '300 Ниосиков за 3 дня',
            'Вместо 50 на Free. Общий бюджет NiosMess, бота и основной группы моделей на сайте NiosAI. Расход зависит от модели и длины диалога.',
          ),
          (
            'NiosAI Prime и SPrime',
            'Доступ к моделям для сложных вопросов, подробного анализа и работы с кодом.',
          ),
          ('Файлы до 100 МБ', 'Вместо 30 МБ на Free.'),
          (
            '220 публичных каналов и 220 групп',
            'Вместо 110 каналов и 110 групп на Free.',
          ),
          (
            '100 наборов эмодзи',
            'Вместо 50 на Free. Можно установить статус-эмодзи рядом с именем.',
          ),
          (
            '5 дней на продление',
            'После окончания подписки настройки каналов, групп и собственных наборов эмодзи сохраняются ещё 5 дней. Затем превышающие Free-лимит станут приватными. Данные не удаляются.',
          ),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.$1,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.$2,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        if (!_loadingStatus && !isPlus && !trialUsed) ...[
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _claimingTrial ? null : _claimTrial,
              child: Text(
                _claimingTrial
                    ? 'Активация…'
                    : 'Попробовать бесплатно на 1 день',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
