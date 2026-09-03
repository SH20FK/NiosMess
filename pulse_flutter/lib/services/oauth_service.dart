import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:universal_io/io.dart' show SocketException;

/// Service managing OAuth 2.0 PKCE token exchanges and central Nios ID session checks.
class OAuthService {
  const OAuthService();

  /// Probes the central Nios ID session status via `GET /id/api/v1/account`.
  ///
  /// Returns `false` ONLY if the HTTP status code is 401 Unauthorized (meaning no active
  /// central session exists or it has been terminated).
  ///
  /// Returns `true` for 200 OK or when a network exception occurs (ensuring network
  /// flakes or offline mode do not eject an already authenticated local session).
  Future<bool> checkCentralNiosIdSession({http.Client? client}) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final http.Response response = await httpClient.get(
        Uri.parse(ApiConstants.accountCheckUrl),
        headers: const <String, String>{
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 401) {
        return false;
      }
      return true;
    } catch (_) {
      // Network errors / offline must not kick the user out
      return true;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Exchanges an authorization code and PKCE verifier for a short-lived OAuth access token
  /// via `POST /oauth/token`.
  ///
  /// Sends `application/x-www-form-urlencoded` body containing:
  /// - `grant_type`: `authorization_code`
  /// - `code`: [code]
  /// - `client_id`: [ApiConstants.clientId] (`niosmess_web`)
  /// - `redirect_uri`: [ApiConstants.redirectUri] (`https://ni-os.ru/web`)
  /// - `code_verifier`: [verifier]
  ///
  /// Throws [ApiException] if token exchange fails (e.g. invalid_grant or invalid code).
  Future<NiosOAuthTokenResponse> exchangeAuthCode({
    required String code,
    required String verifier,
    http.Client? client,
  }) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final http.Response response = await httpClient.post(
        Uri.parse(ApiConstants.oauthTokenUrl),
        headers: const <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: <String, String>{
          'grant_type': 'authorization_code',
          'code': code,
          'client_id': ApiConstants.clientId,
          'redirect_uri': ApiConstants.redirectUri,
          'code_verifier': verifier,
        },
      );

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Invalid response from OAuth token endpoint',
        );
      }

      final NiosOAuthTokenResponse tokenResponse = NiosOAuthTokenResponse.fromJson(data);

      if (response.statusCode < 200 || response.statusCode >= 300 || !tokenResponse.isSuccess) {
        final String errorMessage = tokenResponse.errorDescription ??
            tokenResponse.error ??
            'OAuth token exchange failed with status ${response.statusCode}';
        throw ApiException(
          statusCode: response.statusCode,
          message: errorMessage,
        );
      }

      return tokenResponse;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error during OAuth token exchange: $e',
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Requests a device authorization grant via RFC 8628 `POST /oauth/device/code`.
  Future<NiosDeviceCodeResponse> requestDeviceCode({http.Client? client}) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final http.Response response = await httpClient.post(
        Uri.parse(ApiConstants.oauthDeviceCodeUrl),
        headers: const <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: <String, String>{
          'client_id': ApiConstants.clientId,
          'scope': ApiConstants.scopes,
        },
      );

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Invalid response from device code endpoint',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String error = data['error_description']?.toString() ??
            data['error']?.toString() ??
            'Failed to request device authorization code (${response.statusCode})';
        throw ApiException(
          statusCode: response.statusCode,
          message: error,
        );
      }

      return NiosDeviceCodeResponse.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error during device code request: $e',
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Polls `POST /oauth/token` for completion of the RFC 8628 device authorization.
  ///
  /// Returns `null` if [isCancelled] returns true, or throws [ApiException] on fatal error/timeout.
  ///
  /// Automatically retries on transient [SocketException] (e.g. `Failed host lookup` right after
  /// the app goes to background when opening the browser on Android). Up to [_kMaxNetworkRetries]
  /// consecutive network-level failures are tolerated before giving up.
  static const int _kMaxNetworkRetries = 5;

  Future<NiosOAuthTokenResponse?> pollDeviceToken({
    required String deviceCode,
    int intervalSeconds = 5,
    int maxDurationSeconds = 600,
    bool Function()? isCancelled,
    http.Client? client,
  }) async {
    final http.Client httpClient = client ?? http.Client();
    final DateTime deadline = DateTime.now().add(Duration(seconds: maxDurationSeconds));
    Duration delay = Duration(seconds: intervalSeconds < 1 ? 5 : intervalSeconds);
    int networkFailures = 0;

    // Initial delay: gives Android time to restore network context after the app
    // transitions to the background when the browser is opened for device auth.
    await Future<void>.delayed(delay);

    try {
      while (DateTime.now().isBefore(deadline)) {
        if (isCancelled?.call() == true) {
          return null;
        }

        http.Response response;
        try {
          response = await httpClient.post(
            Uri.parse(ApiConstants.oauthTokenUrl),
            headers: const <String, String>{
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: <String, String>{
              'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
              'client_id': ApiConstants.clientId,
              'device_code': deviceCode,
            },
          );
          networkFailures = 0; // reset on successful connection
        } on SocketException {
          // Transient network error (e.g. DNS lookup failure while app is backgrounded).
          // Retry up to _kMaxNetworkRetries times before giving up.
          networkFailures++;
          if (networkFailures > _kMaxNetworkRetries) {
            throw ApiException(
              statusCode: 0,
              message: 'Нет соединения с Nios ID. Проверьте интернет и попробуйте снова.',
            );
          }
          await Future<void>.delayed(delay);
          continue;
        } catch (e) {
          // Other transient errors (e.g. http.ClientException wrapping SocketException).
          networkFailures++;
          if (networkFailures > _kMaxNetworkRetries) {
            throw ApiException(statusCode: 0, message: 'Ошибка сети: $e');
          }
          await Future<void>.delayed(delay);
          continue;
        }

        Map<String, dynamic> data;
        try {
          data = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {
          // If non-JSON or proxy error during poll, wait and retry
          await Future<void>.delayed(delay);
          continue;
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final NiosOAuthTokenResponse tokenResponse = NiosOAuthTokenResponse.fromJson(data);
          if (tokenResponse.isSuccess) {
            return tokenResponse;
          }
        }

        final String? error = data['error']?.toString();
        if (error == 'slow_down') {
          delay = Duration(seconds: delay.inSeconds + 5);
          await Future<void>.delayed(delay);
          continue;
        }

        if (error == 'authorization_pending') {
          await Future<void>.delayed(delay);
          continue;
        }

        if (error == 'access_denied') {
          throw ApiException(
            statusCode: 400,
            message: 'Вход отклонён в Nios ID',
          );
        }

        if (error == 'expired_token') {
          throw ApiException(
            statusCode: 400,
            message: 'Время авторизации истекло. Пожалуйста, попробуйте снова.',
          );
        }

        final String errorMsg = data['error_description']?.toString() ??
            error ??
            'Device authorization failed (${response.statusCode})';
        throw ApiException(
          statusCode: response.statusCode,
          message: errorMsg,
        );
      }

      throw ApiException(
        statusCode: 408,
        message: 'Время ожидания подтверждения истекло',
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Terminates the central Nios ID session via `POST /id/api/v1/logout`.
  ///
  /// Returns `true` if the server acknowledged the logout (2xx), or `false` on failure.
  /// Any exceptions are handled gracefully so caller can proceed with local cleanup.
  Future<bool> logoutCentralNiosId({http.Client? client}) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final http.Response response = await httpClient.post(
        Uri.parse(ApiConstants.centralLogoutUrl),
        headers: const <String, String>{
          'Accept': 'application/json',
        },
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}

/// Riverpod provider for [OAuthService].
final Provider<OAuthService> oauthServiceProvider = Provider<OAuthService>((Ref ref) {
  return const OAuthService();
});
