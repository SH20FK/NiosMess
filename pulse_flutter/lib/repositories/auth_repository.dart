import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/models/api/session_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class AuthRepository {
  const AuthRepository(this._ref);

  final Ref _ref;

  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String displayName,
    required String password,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'register',
          payload: <String, dynamic>{
            'email': email,
            'username': username,
            'display_name': displayName,
            'password': password,
          },
        );
    return asStringMap(response);
  }

  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'verify_email',
          payload: <String, dynamic>{'email': email, 'code': code},
        );
    return asStringMap(response);
  }

  Future<AuthLoginResult> login({
    required String identifier,
    required String password,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'login',
          payload: <String, dynamic>{
            'identifier': identifier,
            'password': password,
          },
        );
    return AuthLoginResult.fromJson(asStringMap(response));
  }

  Future<AuthLoginResult> verifyTwoFa({
    required String identifier,
    required String code,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'verify_2fa',
          payload: <String, dynamic>{'identifier': identifier, 'code': code},
        );
    return AuthLoginResult.fromJson(asStringMap(response));
  }

  Future<void> logout() async {
    await _ref.read(webSocketClientProvider).request('logout', payload: <String, dynamic>{});
  }

  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'reset_password_request',
          payload: <String, dynamic>{'email': email},
        );
    return asStringMap(response);
  }

  Future<Map<String, dynamic>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'reset_password_confirm',
          payload: <String, dynamic>{
            'email': email,
            'code': code,
            'new_password': newPassword,
          },
        );
    return asStringMap(response);
  }

  Future<ApiProfile> getMe() async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('me_info', payload: <String, dynamic>{});
    return ApiProfile.fromJson(asStringMap(response));
  }

  Future<ApiProfile> updateProfile({
    String? displayName,
    String? username,
    String? bio,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{};
    if (displayName != null && displayName.isNotEmpty) {
      payload['display_name'] = displayName;
    }
    if (username != null && username.isNotEmpty) {
      payload['username'] = username;
    }
    if (bio != null) {
      payload['bio'] = bio;
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('update_profile', payload: payload);
    return ApiProfile.fromJson(asStringMap(response));
  }

  Future<ApiProfile> getPublicProfile(String username) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'get_profile',
          payload: <String, dynamic>{'username': username.trim()},
        );
    return ApiProfile.fromJson(asStringMap(response));
  }

  Future<ApiProfileEncrypted> getEncryptedProfile(String username) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'get_profile_encrypted',
          payload: <String, dynamic>{'username': username.trim()},
        );
    return ApiProfileEncrypted.fromJson(asStringMap(response));
  }

  Future<String> uploadAvatar(List<int> bytes, String filename) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'upload_avatar',
          payload: <String, dynamic>{
            'data_base64': base64Encode(bytes),
            'filename': filename,
          },
        );
    return asStringMap(response)['avatar_url'] as String? ?? '';
  }

  Future<bool> toggle2fa({
    required bool enabled,
    required String password,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'toggle_2fa',
          payload: <String, dynamic>{'enabled': enabled, 'password': password},
        );
    return asStringMap(response)['two_fa_enabled'] as bool? ?? enabled;
  }

  Future<List<ApiSession>> getSessions() async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('list_sessions', payload: <String, dynamic>{});
    if (response is! List) {
      return const <ApiSession>[];
    }
    return response
        .whereType<Map>()
        .map(
          (Map item) => ApiSession.fromJson(
            item.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> revokeSession(int sessionId) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'kick_session',
          payload: <String, dynamic>{'session_id': sessionId},
        );
  }

  Future<void> setPublicKey(String publicKeyBase64) async {
    await _ref
        .read(webSocketClientProvider)
        .request(
          'set_public_key',
          payload: <String, dynamic>{'public_key': publicKeyBase64},
        );
  }

  Future<Map<String, dynamic>> getPublicKey(int userId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'get_public_key',
          payload: <String, dynamic>{'user_id': userId},
        );
    return asStringMap(response);
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
      return AuthRepository(ref);
    });
