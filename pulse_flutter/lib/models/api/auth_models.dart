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

    final dynamic rawSession = json['session'];
    final Map<String, dynamic> sessionMap = rawSession is Map<String, dynamic>
        ? rawSession
        : rawSession is Map
            ? rawSession.map((dynamic k, dynamic v) => MapEntry(k.toString(), v))
            : <String, dynamic>{};

    final dynamic rawUser = json['user'];
    final Map<String, dynamic> userMap = rawUser is Map<String, dynamic>
        ? rawUser
        : rawUser is Map
            ? rawUser.map((dynamic k, dynamic v) => MapEntry(k.toString(), v))
            : <String, dynamic>{};

    final dynamic rawUserId = json['user_id'] ?? json['id'] ?? userMap['id'] ?? userMap['user_id'];
    final int? userId = rawUserId is int
        ? rawUserId
        : rawUserId is num
            ? rawUserId.toInt()
            : int.tryParse(rawUserId?.toString() ?? '');

    final String? username = (json['username'] ?? userMap['username'])?.toString();
    final String? displayName = (json['display_name'] ?? json['name'] ?? userMap['display_name'] ?? userMap['name'])?.toString();
    final String? accessToken = (json['access_token'] ?? sessionMap['access_token'] ?? json['token'] ?? sessionMap['token'])?.toString();

    return AuthLoginResult(
      accessToken: accessToken,
      tokenType: json['token_type'] as String?,
      userId: userId,
      username: username,
      displayName: displayName,
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
    this.niosId,
  });

  final String accessToken;
  final int userId;
  final String username;
  final String displayName;
  final String? niosId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      'user_id': userId,
      'username': username,
      'display_name': displayName,
      if (niosId != null) 'nios_id': niosId,
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
      niosId: json['nios_id'] as String?,
    );
  }

  AuthSession copyWith({
    String? accessToken,
    int? userId,
    String? username,
    String? displayName,
    String? niosId,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      niosId: niosId ?? this.niosId,
    );
  }
}

/// OAuth 2.0 Token response model from `POST /oauth/token`.
class NiosOAuthTokenResponse {
  const NiosOAuthTokenResponse({
    this.accessToken,
    this.tokenType,
    this.expiresIn,
    this.scope,
    this.idToken,
    this.error,
    this.errorDescription,
  });

  final String? accessToken;
  final String? tokenType;
  final int? expiresIn;
  final String? scope;
  final String? idToken;
  final String? error;
  final String? errorDescription;

  bool get isSuccess => accessToken != null && accessToken!.isNotEmpty && error == null;

  factory NiosOAuthTokenResponse.fromJson(Map<String, dynamic> json) {
    final dynamic expires = json['expires_in'];
    final int? expiresIn = expires is int
        ? expires
        : (expires != null ? int.tryParse(expires.toString()) : null);

    return NiosOAuthTokenResponse(
      accessToken: json['access_token'] as String?,
      tokenType: json['token_type'] as String?,
      expiresIn: expiresIn,
      scope: json['scope'] as String?,
      idToken: json['id_token'] as String?,
      error: json['error'] as String?,
      errorDescription: (json['error_description'] ??
          json['error_message'] ??
          json['message']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (accessToken != null) 'access_token': accessToken,
      if (tokenType != null) 'token_type': tokenType,
      if (expiresIn != null) 'expires_in': expiresIn,
      if (scope != null) 'scope': scope,
      if (idToken != null) 'id_token': idToken,
      if (error != null) 'error': error,
      if (errorDescription != null) 'error_description': errorDescription,
    };
  }
}

/// RFC 8628 Device Authorization Response model from `POST /oauth/device/code`.
class NiosDeviceCodeResponse {
  const NiosDeviceCodeResponse({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    this.expiresIn = 600,
    this.interval = 5,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final String verificationUriComplete;
  final int expiresIn;
  final int interval;

  factory NiosDeviceCodeResponse.fromJson(Map<String, dynamic> json) {
    final dynamic expires = json['expires_in'];
    final int expiresIn = expires is int
        ? expires
        : (expires != null ? int.tryParse(expires.toString()) ?? 600 : 600);

    final dynamic interv = json['interval'];
    final int interval = interv is int
        ? interv
        : (interv != null ? int.tryParse(interv.toString()) ?? 5 : 5);

    return NiosDeviceCodeResponse(
      deviceCode: (json['device_code'] as String?) ?? '',
      userCode: (json['user_code'] as String?) ?? '',
      verificationUri: (json['verification_uri'] as String?) ?? 'https://ni-os.ru/id/device',
      verificationUriComplete: (json['verification_uri_complete'] as String?) ??
          'https://ni-os.ru/id/device?user_code=${json['user_code'] ?? ''}',
      expiresIn: expiresIn,
      interval: interval,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'device_code': deviceCode,
      'user_code': userCode,
      'verification_uri': verificationUri,
      'verification_uri_complete': verificationUriComplete,
      'expires_in': expiresIn,
      'interval': interval,
    };
  }
}
