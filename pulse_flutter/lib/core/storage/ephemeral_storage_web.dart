// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'ephemeral_storage.dart';

EphemeralStorage createEphemeralStorage() => WebEphemeralStorage();

/// Web implementation of [EphemeralStorage] using browser `sessionStorage`.
///
/// Falls back gracefully to an in-memory dictionary if `sessionStorage` access is restricted
/// (e.g. security-restricted iframe or storage disabled).
class WebEphemeralStorage implements EphemeralStorage {
  final Map<String, String> _fallbackStore = <String, String>{};

  @override
  void savePkceSession({
    required String verifier,
    required String state,
    String? nonce,
  }) {
    try {
      html.window.sessionStorage[pkceVerifierKey] = verifier;
      html.window.sessionStorage[pkceStateKey] = state;
      if (nonce != null && nonce.isNotEmpty) {
        html.window.sessionStorage[pkceNonceKey] = nonce;
      } else {
        html.window.sessionStorage.remove(pkceNonceKey);
      }
    } catch (_) {
      _fallbackStore[pkceVerifierKey] = verifier;
      _fallbackStore[pkceStateKey] = state;
      if (nonce != null && nonce.isNotEmpty) {
        _fallbackStore[pkceNonceKey] = nonce;
      } else {
        _fallbackStore.remove(pkceNonceKey);
      }
    }
  }

  @override
  String? getVerifier() {
    try {
      return html.window.sessionStorage[pkceVerifierKey] ?? _fallbackStore[pkceVerifierKey];
    } catch (_) {
      return _fallbackStore[pkceVerifierKey];
    }
  }

  @override
  String? getState() {
    try {
      return html.window.sessionStorage[pkceStateKey] ?? _fallbackStore[pkceStateKey];
    } catch (_) {
      return _fallbackStore[pkceStateKey];
    }
  }

  @override
  String? getNonce() {
    try {
      return html.window.sessionStorage[pkceNonceKey] ?? _fallbackStore[pkceNonceKey];
    } catch (_) {
      return _fallbackStore[pkceNonceKey];
    }
  }

  @override
  void clear() {
    try {
      html.window.sessionStorage.remove(pkceVerifierKey);
      html.window.sessionStorage.remove(pkceStateKey);
      html.window.sessionStorage.remove(pkceNonceKey);
    } catch (_) {
      // Ignore if sessionStorage is not accessible
    }
    _fallbackStore.remove(pkceVerifierKey);
    _fallbackStore.remove(pkceStateKey);
    _fallbackStore.remove(pkceNonceKey);
  }
}
