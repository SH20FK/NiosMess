class AuthLoginResult {
  const AuthLoginResult({
    this.accessToken,
    this.tokenType,
    this.userId,
    this.username,
    this.displayName,
    this.twoFaRequired = false,
    this.message,
  });

  final String? accessToken;
  final String? tokenType;
  final int? userId;
  final String? username;
  final String? displayName;
  final bool twoFaRequired;
  final String? message;

  bool get isSuccess => accessToken != null && accessToken!.isNotEmpty;

  factory AuthLoginResult.fromJson(Map<String, dynamic> json) {
    final dynamic twoFa = json['two_fa_required'] ?? json['2fa_required'] ?? json['twofa_required'];
    final bool twoFaRequired = twoFa == true || twoFa == 1 || twoFa == 'true' || twoFa == '1';

    return AuthLoginResult(
      accessToken: json['access_token'] as String?,
      tokenType: json['token_type'] as String?,
      userId: json['user_id'] as int?,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      twoFaRequired: twoFaRequired,
      message: json['message'] as String?,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.userId,
    required this.username,
    required this.displayName,
  });

  final String accessToken;
  final int userId;
  final String username;
  final String displayName;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      'user_id': userId,
      'username': username,
      'display_name': displayName,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final String token = (json['access_token'] as String?) ?? '';
    if (token.isEmpty) {
      throw const FormatException('AuthSession: access_token is empty');
    }
    return AuthSession(
      accessToken: token,
      userId: (json['user_id'] as int?) ?? 0,
      username: (json['username'] as String?) ?? '',
      displayName: (json['display_name'] as String?) ?? '',
    );
  }
}
