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
        AppToast.showError(context, 'Не удалось активировать пробный период: $e');
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
    AppToast.showInfo(context, 'Пока не реализовано)');
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
      title: 'Nios Plus & AI',
      isEmbedded: widget.isEmbedded,
      children: <Widget>[
        // Hero Star Banner
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primary.withValues(alpha: 0.18),
                scheme.tertiary.withValues(alpha: 0.12),
                scheme.surfaceContainerLow,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.28),
              width: 1.2,
            ),
          ),
          child: Column(
            children: <Widget>[
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.stars_rounded,
                  color: scheme.onPrimary,
                  size: 38,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Nios Plus',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isPlus
                    ? 'Спасибо, что поддерживаете NiosMess!'
                    : 'Больше места для файлов, больше запросов к ИИ и расширенные лимиты',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              if (_loadingStatus) ...<Widget>[
                const SizedBox(height: 16),
                const AppLoadingIndicator(size: 22),
              ] else if (isPlus) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.check_circle_rounded, size: 16, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        'Nios Plus активен',
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (expiresAt != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Действует до ${formatFullDateTime(expiresAt)}',
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ] else if (inGrace) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  graceUntil != null
                      ? 'Подписка закончилась. Расширенные лимиты сохраняются до ${formatFullDateTime(graceUntil)}'
                      : 'Подписка закончилась, идёт льготный период',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ] else if (trialUsed) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Пробный период уже использован',
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ] else ...<Widget>[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _claimingTrial ? null : _claimTrial,
                    icon: _claimingTrial
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: AppLoadingIndicator(size: 18),
                          )
                        : const Icon(Icons.flash_on_rounded, size: 18),
                    label: Text(
                      _claimingTrial
                          ? 'Активация...'
                          : 'Попробовать бесплатно на 1 день',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        SettingsSection(
          title: 'Что даёт Nios Plus',
          children: <Widget>[
            SettingsListItem.value(
              icon: Icons.upload_file_rounded,
              title: 'Файлы до 100 МБ',
              subtitle: 'Вместо 30 МБ на бесплатном тарифе',
              iconColor: scheme.primary,
            ),
            SettingsListItem.value(
              icon: Icons.auto_awesome_rounded,
              title: '200 000 символов ИИ за 72 часа',
              subtitle: 'Вместо 50 000 — в четыре раза больше запросов к ассистенту',
              iconColor: scheme.tertiary,
            ),
            SettingsListItem.value(
              icon: Icons.campaign_rounded,
              title: '220 публичных каналов и 220 групп',
              subtitle: 'Вместо 110 каналов и 110 групп',
              iconColor: scheme.primary,
            ),
            SettingsListItem.value(
              icon: Icons.emoji_emotions_rounded,
              title: '100 наборов эмодзи',
              subtitle: 'Вместо 50 собственных наборов',
              iconColor: scheme.secondary,
            ),
            SettingsListItem.value(
              icon: Icons.verified_rounded,
              title: 'Статус-эмодзи рядом с именем',
              subtitle: 'Любой значок из официальных наборов, видно всем собеседникам',
              iconColor: scheme.tertiary,
            ),
            SettingsListItem.value(
              icon: Icons.shield_moon_rounded,
              title: 'Льготный период 5 дней',
              subtitle: 'После окончания подписки ничего не удаляется — лимиты сжимаются только спустя пять дней',
              iconColor: scheme.primary,
            ),
          ],
        ),

        // Pricing Tiers (if not already subscribed)
        if (!isPlus && !_loadingStatus) ...<Widget>[
          const SizedBox(height: 16),
          SettingsSection(
            title: 'Тарифные планы',
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _TierCard(
                        title: '1 месяц',
                        price: '299 ₽',
                        period: 'в месяц',
                        isSelected: _selectedTierIndex == 0,
                        scheme: scheme,
                        textTheme: textTheme,
                        onTap: () {
                          HapticService.selection();
                          setState(() => _selectedTierIndex = 0);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TierCard(
                        title: '12 месяцев',
                        price: '199 ₽',
                        period: 'в месяц',
                        badge: 'СКИДКА 40%',
                        isSelected: _selectedTierIndex == 1,
                        scheme: scheme,
                        textTheme: textTheme,
                        onTap: () {
                          HapticService.selection();
                          setState(() => _selectedTierIndex = 1);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _onBuyPressed,
                    child: Text(
                      _selectedTierIndex == 1
                          ? 'Подключить за 2 388 ₽ / год'
                          : 'Подключить за 299 ₽ / месяц',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    required this.isSelected,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  final String title;
  final String price;
  final String period;
  final String? badge;
  final bool isSelected;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer.withValues(alpha: 0.6)
              : scheme.surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.25),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (badge != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              title,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            Text(
              period,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
