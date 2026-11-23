import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:universal_io/io.dart' show SocketException;

/// What went wrong, in categories the screen can explain itself. The text of
/// the Nios ID response never reaches the user.
enum PasswordResetFailureKind {
  /// 429: nginx allows 10 requests a minute per address on these endpoints.
  tooManyRequests,

  /// 422: the new password does not meet the Nios ID rule.
  weakPassword,

  /// 400/401: the code is wrong, expired, or out of attempts.
  invalidCode,

  /// The request never reached the server.
  network,

  /// Anything else.
  unknown,
}

class PasswordResetException implements Exception {
  const PasswordResetException(this.kind);

  final PasswordResetFailureKind kind;

  @override
  String toString() => 'PasswordResetException($kind)';
}

/// Password reset for the Nios ID behind the account, through the public
/// endpoints `POST /id/api/v1/password/request` and
/// `POST /id/api/v1/password/reset`. No session is required: the emailed code
/// is the proof. Resetting revokes every central Nios ID session; whether the
/// messenger session of this app survives that is not verified, so the screen
/// never promises it.
class PasswordResetService {
  const PasswordResetService();

  /// Asks Nios ID to email a reset code to [email].
  ///
  /// The endpoint answers `202` even when the address is unknown, so success
  /// never proves the letter was sent. A new request retires the previous
  /// code.
  Future<void> requestCode(String email, {http.Client? client}) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final http.Response response = await httpClient.post(
        Uri.parse(ApiConstants.passwordRequestUrl),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        // The body of a 202 is not needed, and 204 has none: never parsed.
        // Any 2xx counts: the endpoint is documented as 202 and reset as 204,
        // and both mean the request was accepted.
        body: jsonEncode(<String, String>{'email': email}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      throw PasswordResetException(_kindFor(response.statusCode));
    } on PasswordResetException {
      rethrow;
    } on SocketException {
      throw const PasswordResetException(PasswordResetFailureKind.network);
    } on http.ClientException {
      throw const PasswordResetException(PasswordResetFailureKind.network);
    } catch (_) {
      throw const PasswordResetException(PasswordResetFailureKind.unknown);
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Sets [newPassword] with the emailed [code]. Success is `204` without a
  /// body. Every central Nios ID session is revoked on success.
  Future<void> reset({
    required String email,
    required String code,
    required String newPassword,
    http.Client? client,
  }) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final http.Response response = await httpClient.post(
        Uri.parse(ApiConstants.passwordResetUrl),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'email': email,
          'code': code,
          'new_password': newPassword,
        }),
      );
      // Success is a 204 without a body; any other 2xx is accepted too.
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      throw PasswordResetException(_kindFor(response.statusCode));
    } on PasswordResetException {
      rethrow;
    } on SocketException {
      throw const PasswordResetException(PasswordResetFailureKind.network);
    } on http.ClientException {
      throw const PasswordResetException(PasswordResetFailureKind.network);
    } catch (_) {
      throw const PasswordResetException(PasswordResetFailureKind.unknown);
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  static PasswordResetFailureKind _kindFor(int statusCode) {
    switch (statusCode) {
      case 429:
        return PasswordResetFailureKind.tooManyRequests;
      case 422:
        return PasswordResetFailureKind.weakPassword;
      case 400:
      case 401:
        return PasswordResetFailureKind.invalidCode;
      default:
        return PasswordResetFailureKind.unknown;
    }
  }
}

/// Riverpod provider for [PasswordResetService].
final Provider<PasswordResetService> passwordResetServiceProvider =
    Provider<PasswordResetService>((Ref ref) => const PasswordResetService());
