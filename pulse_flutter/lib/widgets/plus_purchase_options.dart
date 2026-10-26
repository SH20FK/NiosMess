import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
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
    if (PurchaseDeviceIdentity.isSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
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
      if (token == null) throw StateError(context.l10n.auditPlusSignIn);
      final response = await client
          .get(
            Uri.parse('${ApiConstants.devProxyOrigin}/api/plus/catalog'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode != 200) {
        throw StateError(context.l10n.auditPlusCatalogUnavailable);
      }
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
          error = context.l10n.auditPlusCatalogLoadFailed;
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
        linkError = context.l10n.auditPlusActivationLinkInvalid;
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
        error = context.l10n.auditPlusAccountChanged;
      });
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'funpay.com' ||
        uri.userInfo.isNotEmpty) {
      setState(() {
        error = context.l10n.auditPlusProductUnavailable;
      });
      return;
    }
    setState(() {
      buying = true;
    });
    bool consent = false;
    try {
      final yes = await showAppDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AppDialog(
            title: ctx.l10n.auditPlusContinuePurchase,
            icon: Icons.shopping_bag_outlined,
            actions: [
              AppDialogAction(
                label: ctx.l10n.commonCancel,
                onPressed: () => Navigator.pop(ctx),
              ),
              AppDialogAction(
                label: ctx.l10n.auditPlusOpenFunPay,
                isPrimary: true,
                onPressed: consent ? () => Navigator.pop(ctx, true) : null,
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.l10n.auditPlusPurchaseInstructions),
                const SizedBox(height: 12),
                Text(ctx.l10n.auditPlusFeeNotice),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: consent,
                  onChanged: (value) => update(() => consent = value ?? false),
                  title: Text(ctx.l10n.auditPlusDeviceHashConsent),
                  subtitle: Text(ctx.l10n.auditPlusDeviceHashPurpose),
                ),
              ],
            ),
          ),
        ),
      );
      if (yes == true && mounted) {
        final opened = await AppUrlLauncher.openUrl(context, url);
        if (!opened && mounted) {
          setState(() {
            error = context.l10n.auditPlusOpenFailed;
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
      return Text(context.l10n.auditPlusNativeOnly);
    }
    if (!PurchaseDeviceIdentity.isSupported) {
      return Text(context.l10n.auditPlusSupportedPlatforms);
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.auditPlusPurchaseTitle,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (loading) const AppLoadingIndicator(size: 24),
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
                          context.l10n.auditPlusPromoLimit,
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
                  child: Text(context.l10n.auditPlusBuy),
                ),
              ],
            ),
          ),
        if (plans.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(context.l10n.auditPlusFeeNotice),
          ),
        if (!loading &&
            plans.isNotEmpty &&
            plans.every((p) => p['purchase_url'] == null))
          Text(context.l10n.auditPlusSalesPending),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: TextStyle(color: theme.colorScheme.error)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: loading ? null : _load,
              child: Text(context.l10n.auditPlusRefreshPlans),
            ),
          ),
        ],
        const SizedBox(height: 28),
        Text(
          context.l10n.auditPlusAlreadyPurchased,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _link,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: context.l10n.auditPlusActivationLink,
            errorText: linkError,
          ),
          onSubmitted: (_) => _activateLink(),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _activateLink,
            child: Text(context.l10n.auditPlusCheckSubscription),
          ),
        ),
      ],
    );
  }
}
