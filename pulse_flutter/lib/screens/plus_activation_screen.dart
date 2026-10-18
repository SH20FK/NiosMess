import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/services/purchase_device_identity.dart';

class PlusActivationScreen extends ConsumerStatefulWidget {
  const PlusActivationScreen({required this.code, super.key});
  final String code;
  @override
  ConsumerState<PlusActivationScreen> createState() => _PlusActivationState();
}

class _PlusActivationState extends ConsumerState<PlusActivationScreen> {
  Map<String, dynamic>? offer;
  String? error;
  bool consent = false, busy = false, done = false;

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
    final client = http.Client();
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
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw StateError(data['detail']?.toString() ?? 'Активация недоступна');
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
    });
    try {
      final data = await _post('preview', {});
      if (mounted) {
        setState(() {
          offer = data;
          done = data['already_redeemed'] == true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
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
      final hash = await PurchaseDeviceIdentity.readHash();
      await _post('redeem', {
        'device_hash': hash,
        'device_hash_consent': true,
        'expected_account': offer!['account'],
      });
      try {
        await ref.read(authProvider.notifier).refreshProfile();
      } catch (_) {
        // Activation is already committed; a profile refresh must not report failure.
      }
      if (mounted) {
        setState(() {
          done = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Активация Nios+')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              if (!PurchaseDeviceIdentity.isSupported)
                const Text(
                  'Откройте ссылку в NiosMess для Android, Windows или Linux.',
                )
              else if (done)
                const Text(
                  'Nios+ активирован. Эта ссылка уже использована для вашего аккаунта.',
                )
              else ...[
                if (offer != null) ...[
                  Text(
                    'Активируем Nios+ на ${offer!['duration']}?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text('Аккаунт: @${offer!['username']}'),
                  const SizedBox(height: 12),
                  if (offer!['plan'] == '14d')
                    const Text(
                      'Промотариф доступен один раз на аккаунт, IP и устройство. Общая сеть может считаться одним IP.',
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: consent,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => consent = v ?? false),
                    title: const Text(
                      'Согласен на передачу SHA-256 идентификатора моего устройства для безопасности покупки',
                    ),
                    subtitle: const Text(
                      'Исходный идентификатор не передаётся. Для ограничения промотарифа сервер также учитывает IP. Хеш позволяет связать активации на этом устройстве.',
                    ),
                  ),
                  FilledButton(
                    onPressed: consent && !busy ? _activate : null,
                    child: const Text('Да, активировать'),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : _load,
                    child: const Text('Проверить статус ещё раз'),
                  ),
                ],
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: AppLoadingIndicator(size: 24),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
