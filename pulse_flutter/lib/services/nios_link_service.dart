import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/nios_link_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';

final Provider<NiosLinkService> niosLinkServiceProvider =
    Provider<NiosLinkService>((Ref ref) {
  return NiosLinkService(ref);
});

class NiosLinkService {
  NiosLinkService(this._ref, {http.Client? client})
      : _client = client ?? http.Client();

  final Ref _ref;
  final http.Client _client;

  String? _getToken() {
    return _ref.read(authProvider).session?.accessToken;
  }

  /// Parses any incoming URI (native nios:// or web fallback https://ni-os.ru/l/...) into NiosLinkParsed.
  static NiosLinkParsed? parseLink(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    Uri? uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    // 1. Native scheme: nios://<type>/<token> or nios://device/pair/<token>
    if (uri.scheme.toLowerCase() == 'nios') {
      final String host = uri.host.toLowerCase();
      final List<String> segments =
          uri.pathSegments.where((String s) => s.isNotEmpty).toList();

      if (host == 'device' && segments.isNotEmpty && segments.first == 'pair') {
        final String token = segments.length > 1 ? segments[1] : '';
        return NiosLinkParsed(
          rawUri: uri,
          type: NiosLinkType.pair,
          token: token,
          queryParams: uri.queryParameters,
        );
      }

      if (host.isNotEmpty) {
        final NiosLinkType type = NiosLinkType.fromString(host);
        final String token = segments.isNotEmpty ? segments.first : '';
        return NiosLinkParsed(
          rawUri: uri,
          type: type,
          token: token,
          queryParams: uri.queryParameters,
        );
      }
    }

    // 2. Web fallback: https://ni-os.ru/l/<type>/<token>
    final String host = uri.host.toLowerCase();
    if (host == 'ni-os.ru' || host == 'www.ni-os.ru' || host == 'localhost') {
      final List<String> segments =
          uri.pathSegments.where((String s) => s.isNotEmpty).toList();

      if (segments.length >= 3 && segments[0] == 'l') {
        final NiosLinkType type = NiosLinkType.fromString(segments[1]);
        final String token = segments[2];
        return NiosLinkParsed(
          rawUri: uri,
          type: type,
          token: token,
          queryParams: uri.queryParameters,
        );
      } else if (segments.length >= 2 && segments[0] == 'l') {
        // Direct token under /l/<token>
        final String token = segments[1];
        NiosLinkType guessedType = NiosLinkType.unknown;
        if (token.startsWith('nl_chat_')) guessedType = NiosLinkType.chat;
        if (token.startsWith('nl_msg_')) guessedType = NiosLinkType.message;
        if (token.startsWith('nl_file_')) guessedType = NiosLinkType.file;
        if (token.startsWith('nl_pair_')) guessedType = NiosLinkType.pair;
        if (token.startsWith('nl_tx_')) guessedType = NiosLinkType.transfer;

        return NiosLinkParsed(
          rawUri: uri,
          type: guessedType,
          token: token,
          queryParams: uri.queryParameters,
        );
      }
    }

    return null;
  }

  /// Resolves an opaque token against the server.
  Future<NiosLinkResolution> resolveLink(
    String token, {
    bool consumeIfSingleUse = true,
  }) async {
    final Uri uri = Uri.parse('${ApiConstants.origin}/api/links/resolve');
    final String? authToken = _getToken();

    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(<String, dynamic>{
        'token': token,
        'consume_if_single_use': consumeIfSingleUse,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String msg = 'Не удалось разрешить ссылку';
      try {
        final Map err = jsonDecode(response.body) as Map;
        if (err['detail'] != null) msg = err['detail'].toString();
      } catch (_) {}
      throw ApiException(statusCode: response.statusCode, message: msg);
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return NiosLinkResolution.fromJson(data);
  }

  /// Generates a new signed NiosLink token.
  Future<Map<String, String>> createLink({
    required String tokenType,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? extraPayload,
    bool isSingleUse = false,
    int? expiresInSeconds,
    String audience = 'niosmess_client',
  }) async {
    final String? authToken = _getToken();
    final Uri uri = Uri.parse('${ApiConstants.origin}/api/links/create');

    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(<String, dynamic>{
        'token_type': tokenType,
        'target_type': targetType,
        'target_id': targetId,
        'extra_payload': ?extraPayload,
        'is_single_use': isSingleUse,
        'expires_in_seconds': ?expiresInSeconds,
        'audience': audience,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Не удалось создать ссылку: ${response.body}',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return <String, String>{
      'token': (data['token'] as String?) ?? '',
      'native_url': (data['native_url'] as String?) ?? '',
      'web_url': (data['web_url'] as String?) ?? '',
    };
  }

  /// Initiates a QR pairing session for desktop/web.
  Future<NiosPairSession> initPairSession() async {
    final Uri uri = Uri.parse('${ApiConstants.origin}/api/links/pair/init');
    final http.Response response = await _client.post(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Ошибка создания сессии сопряжения',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return NiosPairSession.fromJson(data);
  }

  /// Confirms pairing request on the primary mobile device.
  Future<bool> confirmPair(String pairToken) async {
    final String? authToken = _getToken();
    if (authToken == null) return false;

    final Uri uri = Uri.parse('${ApiConstants.origin}/api/links/pair/confirm');
    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(<String, dynamic>{
        'pair_token': pairToken,
      }),
    );

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// Polled by secondary device (desktop/web) while awaiting approval.
  Future<Map<String, dynamic>> pollPair(String pairToken) async {
    final Uri uri = Uri.parse('${ApiConstants.origin}/api/links/pair/poll?token=$pairToken');
    final http.Response response = await _client.get(uri);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return <String, dynamic>{'status': 'error'};
  }

  /// High-level dispatcher that resolves a link and triggers the appropriate in-app action.
  Future<bool> handleIncomingLink(BuildContext context, String rawUrl) async {
    final NiosLinkParsed? parsed = parseLink(rawUrl);
    if (parsed == null || !parsed.isValid) return false;

    HapticService.selection();

    try {
      // Show light loading toast while resolving
      final NiosLinkResolution res = await resolveLink(parsed.token);

      if (!context.mounted) return true;

      switch (parsed.type) {
        case NiosLinkType.chat:
        case NiosLinkType.invite:
          if (res.chatId != null) {
            context.push('/chat/${res.chatId}');
            return true;
          }
          break;

        case NiosLinkType.message:
          if (res.chatId != null) {
            final String route = res.messageId != null
                ? '/chat/${res.chatId}?highlightMessageId=${res.messageId}'
                : '/chat/${res.chatId}';
            context.push(route);
            return true;
          }
          break;

        case NiosLinkType.pair:
          // Show device pairing confirmation bottom sheet
          _showPairingApprovalDialog(context, parsed.token);
          return true;

        case NiosLinkType.file:
          AppToast.showSuccess(
            context,
            'Файл готов к загрузке: ${res.filename ?? "документ"}',
          );
          return true;

        case NiosLinkType.transfer:
          AppToast.showSuccess(context, 'Передача файла возобновлена');
          return true;

        case NiosLinkType.unknown:
          break;
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }

    return false;
  }

  void _showPairingApprovalDialog(BuildContext context, String pairToken) {
    showAppConfirmDialog(
      context: context,
      title: 'Подключение устройства',
      subtitle:
          'Разрешить новому устройству (Компьютер / Браузер) вход в ваш аккаунт NiosMess через QR-код?',
      confirmLabel: 'Подключить',
      cancelLabel: 'Отклонить',
      icon: Icons.qr_code_scanner_rounded,
      destructive: false,
    ).then((bool? confirmed) async {
      if (confirmed == true && context.mounted) {
        final bool success = await confirmPair(pairToken);
        if (context.mounted) {
          if (success) {
            HapticService.confirm();
            AppToast.showSuccess(context, 'Устройство успешно подключено!');
          } else {
            AppToast.showError(context, 'Не удалось авторизовать устройство');
          }
        }
      }
    });
  }
}
