import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/storage/cache_service.dart';
import 'package:pulse_flutter/core/utils/shared_utilities.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/models/api/chat_actions_models.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/models/api/session_model.dart';
import 'package:pulse_flutter/models/api/working_hours_model.dart';
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

  Future<AuthLoginResult> loginNiosId({
    required String oauthAccessToken,
    required String deviceInfo,
  }) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'login_nios_id',
          payload: <String, dynamic>{
            'oauth_access_token': oauthAccessToken,
            'device_info': deviceInfo,
          },
        );
    return AuthLoginResult.fromJson(asStringMap(response));
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

  Future<void> unregisterFcmToken(String fcmToken) async {
    await _ref.read(webSocketClientProvider).request(
      'unregister_fcm_token',
      payload: <String, dynamic>{'fcm_token': fcmToken},
    );
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
    final ApiProfile profile = ApiProfile.fromJson(asStringMap(response));
    await _ref.read(cacheServiceProvider).saveProfile(profile);
    return profile;
  }

  Future<ApiProfile> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? phoneNumber,
    String? birthday,
    WorkingHours? workingHours,
    bool clearPhoneNumber = false,
    bool clearBirthday = false,
    bool clearWorkingHours = false,
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
    if (clearPhoneNumber) {
      payload['phone_number'] = null;
    } else if (phoneNumber != null) {
      payload['phone_number'] =
          phoneNumber.trim().isEmpty ? null : phoneNumber.trim();
    }
    if (clearBirthday) {
      payload['birthday'] = null;
    } else if (birthday != null) {
      payload['birthday'] =
          birthday.trim().isEmpty ? null : birthday.trim();
    }
    if (clearWorkingHours) {
      payload['working_hours'] = null;
    } else if (workingHours != null) {
      payload['working_hours'] = workingHours.toJson();
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('update_profile', payload: payload);
    final ApiProfile profile = ApiProfile.fromJson(asStringMap(response));
    await _ref.read(cacheServiceProvider).saveProfile(profile);
    return profile;
  }

  Future<List<ApiBadge>> getMyBadges() async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('get_my_badges', payload: <String, dynamic>{});
    final Map<String, dynamic> map = asStringMap(response);
    final dynamic badgesRaw = map['badges'];
    if (badgesRaw is List) {
      return badgesRaw
          .whereType<Map>()
          .map((dynamic item) => ApiBadge.fromJson(asStringMap(item)))
          .toList(growable: false);
    }
    return const <ApiBadge>[];
  }

  Future<List<int>> setVisibleBadges(List<int> badgeIds) async {
    final List<int> trimmed = badgeIds.take(2).toList(growable: false);
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('set_visible_badges', payload: <String, dynamic>{'badge_ids': trimmed});
    final Map<String, dynamic> map = asStringMap(response);
    final dynamic idsRaw = map['badge_ids'];
    if (idsRaw is List) {
      return idsRaw.whereType<int>().toList(growable: false);
    }
    return trimmed;
  }

  Future<ApiProfile> getPublicProfile(String username) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'get_profile',
          payload: <String, dynamic>{'username': username.trim()},
        );
    final ApiProfile profile = ApiProfile.fromJson(asStringMap(response));
    await _ref.read(cacheServiceProvider).saveProfile(profile);
    return profile;
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

  Future<String> uploadAvatar(
    dynamic fileBytes, {
    required String filename,
    bool isVideo = false,
  }) async {
    final List<int> bytes;
    if (fileBytes is Uint8List) {
      bytes = fileBytes.toList();
    } else if (fileBytes is List<int>) {
      bytes = fileBytes;
    } else {
      throw ArgumentError('fileBytes must be List<int> or Uint8List');
    }

    if (bytes.length > 8 * 1024 * 1024) {
      throw Exception('Размер аватара не должен превышать 8 МБ');
    }

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'upload_avatar',
          payload: <String, dynamic>{
            'data_base64': base64Encode(bytes),
            'filename': filename,
            if (isVideo) 'is_video': true,
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

  Future<ApiPublicKeyResult> getPublicKey(int userId) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'get_public_key',
          payload: <String, dynamic>{'user_id': userId},
        );
    return ApiPublicKeyResult.fromJson(asStringMap(response));
  }

  Future<ApiEraseSecretResult> eraseSecret(String publicKeyBase64) async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request(
          'erase_secret',
          payload: <String, dynamic>{'public_key': publicKeyBase64},
        );
    return ApiEraseSecretResult.fromJson(asStringMap(response));
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
      return AuthRepository(ref);
    });
