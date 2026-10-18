import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/services/purchase_device_identity.dart';

class PlusActivationScreen extends ConsumerStatefulWidget {
  const PlusActivationScreen({
    required this.code,
    this.clientFactory,
    this.deviceHashReader,
    this.onActivated,
    super.key,
  });
  final String code;
  final http.Client Function()? clientFactory;
  final Future<String> Function()? deviceHashReader;
  final Future<void> Function()? onActivated;
  @override
  ConsumerState<PlusActivationScreen> createState() => _PlusActivationState();
}

class _PlusActivationState extends ConsumerState<PlusActivationScreen> {
  Map<String, dynamic>? offer;
  String? error;
  bool consent = false, busy = false, done = false, activatedNow = false;
  DateTime? expiresAt;

  @override
  void initState() {
    super.initState();
    if (PurchaseDeviceIdentity.isSupported) _load();
  }

  Future<Map<String, dynamic>> _post(
    String action,
    Map<String, dynamic> body,
  ) async {
    final token = ref.read(sessionAccessTokenProvider);
    if (token == null) throw StateError('Войдите через NiosID');
    final client = widget.clientFactory?.call() ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('${ApiConstants.devProxyOrigin}/api/plus/$action'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'code': widget.code, ...body}),
          )
          .timeout(const Duration(seconds: 30));
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw StateError(data['detail']?.toString() ?? 'Активация недоступна');
      }
      if (token != ref.read(sessionAccessTokenProvider)) {
        throw StateError('Аккаунт изменился. Проверьте ссылку заново.');
      }
      return data;
    } finally {
      client.close();
    }
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
      offer = null;
      consent = false;
    });
    try {
      final data = await _post('preview', {});
      if (mounted) {
        setState(() {
          offer = data;
          done = data['already_redeemed'] == true;
          expiresAt = DateTime.tryParse(
            data['granted_until']?.toString() ?? '',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is StateError
              ? e.message.toString()
              : 'Не удалось связаться с сервером. Попробуйте ещё раз.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _activate() async {
    if (!consent ||
        busy ||
        !PurchaseDeviceIdentity.isSupported ||
        offer == null) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final hash =
          await (widget.deviceHashReader?.call() ??
              PurchaseDeviceIdentity.readHash());
      final result = await _post('redeem', {
        'device_hash': hash,
        'device_hash_consent': true,
        'expected_account': offer!['account'],
      });
      try {
        if (widget.onActivated != null) {
          await widget.onActivated!();
        } else {
          await ref.read(authProvider.notifier).refreshProfile();
        }
      } catch (_) {
        // Activation is already committed; a profile refresh must not report failure.
      }
      if (mounted) {
        setState(() {
          done = true;
          activatedNow = true;
          expiresAt = DateTime.tryParse(result['expires_at']?.toString() ?? '');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is StateError
              ? e.message.toString()
              : 'Не удалось связаться с сервером. Попробуйте ещё раз.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/settings/plus');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;
    final background = theme.scaffoldBackgroundColor;
    final panel = scheme.surfaceContainerLow;
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: background,
          foregroundColor: ink,
          leadingWidth: 96,
          leading: TextButton(onPressed: _close, child: const Text('Назад')),
        ),
        body: LayoutBuilder(
          builder: (context, viewport) {
            final wide = viewport.maxWidth >= Breakpoints.medium;
            final detail = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!PurchaseDeviceIdentity.isSupported)
                  const Text(
                    'Активация доступна в NiosMess для Android, Windows и Linux.',
                  )
                else if (done) ...[
                  Text(
                    activatedNow
                        ? 'Подписка активирована'
                        : 'Ссылка уже активирована',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Аккаунт: @${offer?['username'] ?? ''}',
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (expiresAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Действует до ${formatFullDateTime(expiresAt!)}',
                      style: TextStyle(color: muted),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _close,
                    style: _buttonStyle(scheme),
                    child: const Text('Готово'),
                  ),
                ] else ...[
                  Text(
                    offer == null
                        ? (busy
                              ? 'Проверяем ссылку'
                              : 'Не удалось проверить ссылку')
                        : 'Активировать на ${offer!['duration']}?',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (offer != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Аккаунт NiosID',
                      style: TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${offer!['username']}',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (offer!['plan'] == '14d') ...[
                      const SizedBox(height: 16),
                      Text(
                        'Промотариф доступен один раз на аккаунт, IP и устройство. Общая сеть может считаться одним IP.',
                        style: TextStyle(color: muted, fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 20),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: consent,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => consent = value ?? false),
                      title: const Text(
                        'Разрешаю передать SHA-256 хеш устройства',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Для безопасности покупки. Исходный идентификатор не передаётся; хеш связывает активации на этом устройстве.',
                          style: TextStyle(color: muted, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: consent && !busy ? _activate : null,
                      style: _buttonStyle(scheme),
                      child: Text(
                        busy ? 'Активируем…' : 'Активировать NiosPlus',
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy ? null : _load,
                      child: const Text('Проверить ссылку ещё раз'),
                    ),
                  ],
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: AppLoadingIndicator(size: 24),
                    ),
                ],
              ],
            );
            final intro = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NiosPlus',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: wide ? 44 : 36,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Активация подписки',
                  style: TextStyle(color: muted, fontSize: 16),
                ),
              ],
            );
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 32 : 24,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Material(
                        color: panel,
                        borderRadius: BorderRadius.circular(28),
                        child: Padding(
                          padding: EdgeInsets.all(wide ? 40 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nios',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 36),
                              if (wide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: intro),
                                    const SizedBox(width: 64),
                                    Expanded(child: detail),
                                  ],
                                )
                              else ...[
                                intro,
                                const SizedBox(height: 32),
                                detail,
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(ColorScheme scheme) => FilledButton.styleFrom(
    backgroundColor: scheme.primary,
    foregroundColor: scheme.onPrimary,
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: const StadiumBorder(),
  );
}
