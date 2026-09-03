import 'ephemeral_storage_stub.dart'
    if (dart.library.html) 'ephemeral_storage_web.dart';

/// Storage keys for ephemeral OAuth 2.0 PKCE session parameters.
const String pkceVerifierKey = 'nios_oauth_verifier';
const String pkceStateKey = 'nios_oauth_state';
const String pkceNonceKey = 'nios_oauth_nonce';

/// Cross-platform ephemeral storage for short-lived OAuth 2.0 PKCE artifacts.
///
/// On Web: Uses browser sessionStorage with graceful fallback to in-memory store.
/// On Native / VM / Tests: Uses in-memory storage.
///
/// Security guarantee: PKCE verifiers, states, and nonces are strictly ephemeral
/// and never written to permanent storage (FlutterSecureStorage or SharedPreferences).
abstract class EphemeralStorage {
  /// Default platform-specific factory constructor.
  factory EphemeralStorage() => createEphemeralStorage();

  /// Creates a pure in-memory ephemeral store (useful for tests and headless execution).
  factory EphemeralStorage.inMemory() => MemoryEphemeralStorage();

  /// Persists PKCE session parameters (verifier, state, optional nonce).
  void savePkceSession({
    required String verifier,
    required String state,
    String? nonce,
  });

  /// Retrieves the stored PKCE code verifier if present.
  String? getVerifier();

  /// Retrieves the stored OAuth state parameter if present.
  String? getState();

  /// Retrieves the stored OAuth nonce parameter if present.
  String? getNonce();

  /// Clears all stored ephemeral PKCE parameters.
  void clear();
}

/// In-memory implementation of [EphemeralStorage] available across all platforms.
class MemoryEphemeralStorage implements EphemeralStorage {
  final Map<String, String> _store = <String, String>{};

  @override
  void savePkceSession({
    required String verifier,
    required String state,
    String? nonce,
  }) {
    _store[pkceVerifierKey] = verifier;
    _store[pkceStateKey] = state;
    if (nonce != null && nonce.isNotEmpty) {
      _store[pkceNonceKey] = nonce;
    } else {
      _store.remove(pkceNonceKey);
    }
  }

  @override
  String? getVerifier() => _store[pkceVerifierKey];

  @override
  String? getState() => _store[pkceStateKey];

  @override
  String? getNonce() => _store[pkceNonceKey];

  @override
  void clear() {
    _store.remove(pkceVerifierKey);
    _store.remove(pkceStateKey);
    _store.remove(pkceNonceKey);
  }
}
