import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/services/app_url_launcher.dart';
import 'package:pulse_flutter/providers/token_provider.dart';
import 'package:pulse_flutter/screens/plus_activation_screen.dart';
import 'package:pulse_flutter/services/plus_activation_link.dart';
import 'package:pulse_flutter/services/purchase_device_identity.dart';

const _feeNotice =
    'К цене добавляется комиссия платёжного шлюза. Итоговая сумма будет показана на FunPay перед оплатой.';

class PlusPurchaseOptions extends ConsumerStatefulWidget {
  const PlusPurchaseOptions({
    required this.onChanged,
    this.clientFactory,
    super.key,
  });
  final VoidCallback onChanged;
  final http.Client Function()? clientFactory;
  @override
  ConsumerState<PlusPurchaseOptions> createState() =>
      _PlusPurchaseOptionsState();
}

class _PlusPurchaseOptionsState extends ConsumerState<PlusPurchaseOptions> {
  final _link = TextEditingController();
  List<Map<String, dynamic>> plans = [];
  String? error, linkError, _catalogToken;
  bool loading = true, buying = false;

  @override
  void initState() {
    super.initState();
    if (PurchaseDeviceIdentity.isSupported) _load();
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final token = ref.read(sessionAccessTokenProvider);
    final client = widget.clientFactory?.call() ?? http.Client();
    try {
      if (token == null) throw StateError('Войдите через NiosID');
      final response = await client
          .get(
            Uri.parse('${ApiConstants.devProxyOrigin}/api/plus/catalog'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw StateError('Тарифы недоступны');
      if (token != ref.read(sessionAccessTokenProvider)) {
        return;
      }
      _catalogToken = token;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          plans = (body['plans'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'Не удалось загрузить тарифы. Активация купленной ссылки доступна ниже.';
        });
      }
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _activateLink() async {
    final code = PlusActivationLink.codeFrom(_link.text);
    if (code == null) {
      setState(() {
        linkError = 'Вставьте полную ссылку активации из заказа';
      });
      return;
    }
    setState(() {
      linkError = null;
    });
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PlusActivationScreen(code: code)),
    );
    if (mounted) widget.onChanged();
  }

  Future<void> _buy(String url) async {
    if (buying) return;
    if (_catalogToken != ref.read(sessionAccessTokenProvider)) {
      setState(() {
        plans = [];
        error = 'Аккаунт изменился. Обновите тарифы перед покупкой.';
      });
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'funpay.com' ||
        uri.userInfo.isNotEmpty) {
      setState(() {
        error = 'Адрес товара недоступен. Попробуйте обновить тарифы.';
      });
      return;
    }
    setState(() {
      buying = true;
    });
    bool consent = false;
    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: const Text('Перейти к покупке'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'На FunPay вы получите одноразовую ссылку. Откройте её в NiosMess для активации.',
                ),
                const SizedBox(height: 12),
                const Text(_feeNotice),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: consent,
                  onChanged: (value) => update(() => consent = value ?? false),
                  title: const Text(
                    'Согласен на передачу SHA-256 хеша устройства при активации',
                  ),
                  subtitle: const Text(
                    'Нужен для защиты покупки. Для промотарифа учитываются также аккаунт и IP.',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: consent ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Перейти на FunPay'),
              ),
            ],
          ),
        ),
      );
      if (yes == true && mounted) {
        final opened = await AppUrlLauncher.openUrl(context, url);
        if (!opened && mounted) {
          setState(() {
            error = 'Не удалось открыть FunPay';
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          buying = false;
        });
      }
    }
  }

  String _price(num kopecks) {
    final value = (kopecks / 100)
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.00$'), '')
        .replaceAll('.', ',');
    return '$value ₽';
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Text(
        'Покупка и активация доступны в мобильном и десктопном NiosMess.',
      );
    }
    if (!PurchaseDeviceIdentity.isSupported) {
      return const Text(
        'Покупка и активация пока доступны в приложениях для Android, Windows и Linux.',
      );
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Покупка и продление', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (loading) const LinearProgressIndicator(),
        for (final plan in plans)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${plan['duration']}',
                        style: theme.textTheme.bodyLarge,
                      ),
                      Text(
                        _price(plan['price_kopecks'] as num),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (plan['promo'] == true)
                        Text(
                          'Один раз на аккаунт, IP и устройство',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: !buying && plan['purchase_url'] is String
                      ? () => _buy(plan['purchase_url'] as String)
                      : null,
                  child: const Text('Купить'),
                ),
              ],
            ),
          ),
        if (plans.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(_feeNotice),
          ),
        if (!loading &&
            plans.isNotEmpty &&
            plans.every((p) => p['purchase_url'] == null))
          const Text(
            'Продажи ещё не открыты. Купленную ссылку можно активировать ниже.',
          ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: TextStyle(color: theme.colorScheme.error)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: loading ? null : _load,
              child: const Text('Обновить тарифы'),
            ),
          ),
        ],
        const SizedBox(height: 28),
        Text('Уже купили NiosPlus?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _link,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Ссылка активации',
            errorText: linkError,
          ),
          onSubmitted: (_) => _activateLink(),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _activateLink,
            child: const Text('Проверить подписку'),
          ),
        ),
      ],
    );
  }
}
