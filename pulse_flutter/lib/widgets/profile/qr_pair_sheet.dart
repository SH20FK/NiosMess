import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/nios_link_models.dart';
import 'package:pulse_flutter/services/nios_link_service.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Material 3 Expressive bottom sheet for linking secondary devices via QR code (NiosLink Pair).
class QrPairSheet extends ConsumerStatefulWidget {
  const QrPairSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) => const QrPairSheet(),
    );
  }

  @override
  ConsumerState<QrPairSheet> createState() => _QrPairSheetState();
}

class _QrPairSheetState extends ConsumerState<QrPairSheet> {
  NiosPairSession? _session;
  bool _isLoading = true;
  bool _isConfirmed = false;
  String? _errorMessage;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initPairing();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initPairing() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final NiosLinkService service = ref.read(niosLinkServiceProvider);
      final NiosPairSession session = await service.initPairSession();
      if (!mounted) return;

      setState(() {
        _session = session;
        _isLoading = false;
      });

      _startPolling(session.token);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Не удалось создать сессию: $e';
      });
    }
  }

  void _startPolling(String token) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (Timer timer) async {
      try {
        final NiosLinkService service = ref.read(niosLinkServiceProvider);
        final Map<String, dynamic> res = await service.pollPair(token);
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (res['status'] == 'confirmed') {
          timer.cancel();
          HapticService.confirm();
          setState(() {
            _isConfirmed = true;
          });
          AppToast.showSuccess(context, 'Устройство успешно связано!');
          Future<void>.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) Navigator.of(context).pop();
          });
        } else if (res['status'] == 'expired') {
          timer.cancel();
          setState(() {
            _errorMessage = 'Срок действия QR-кода истёк. Обновите для создания нового.';
          });
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            'Подключение устройства',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Отсканируйте код с мобильного устройства в NiosMess для мгновенного входа',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          if (_isLoading)
            const SizedBox(
              height: 220,
              child: Center(
                child: AppLoadingIndicator(size: 40),
              ),
            )
          else if (_isConfirmed)
            Container(
              height: 220,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Успешно авторизовано!',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            )
          else if (_errorMessage != null)
            Container(
              height: 220,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: scheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: scheme.error),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: _initPairing,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            )
          else if (_session != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(24),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: _session!.nativeUrl,
                  version: QrVersions.auto,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF000000),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Color(0xFF000000),
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Код действителен 3 минуты',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
