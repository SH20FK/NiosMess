import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nios_admin_flutter/core/network/admin_api_client.dart';
import 'package:nios_admin_flutter/core/network/api_exception.dart';
import 'package:nios_admin_flutter/repositories/admin_repository.dart';

const String adminApiBaseUrl = 'https://ni-os.ru/api/v1';

class AdminSessionState {
  const AdminSessionState({
    required this.unlocked,
    required this.busy,
    required this.password,
    required this.error,
    required this.hydrated,
  });

  const AdminSessionState.initial()
    : unlocked = false,
      busy = false,
      password = null,
      error = null,
      hydrated = false;

  final bool unlocked;
  final bool busy;
  final String? password;
  final String? error;
  final bool hydrated;

  AdminSessionState copyWith({
    bool? unlocked,
    bool? busy,
    String? password,
    bool clearPassword = false,
    String? error,
    bool clearError = false,
    bool? hydrated,
  }) {
    return AdminSessionState(
      unlocked: unlocked ?? this.unlocked,
      busy: busy ?? this.busy,
      password: clearPassword ? null : (password ?? this.password),
      error: clearError ? null : (error ?? this.error),
      hydrated: hydrated ?? this.hydrated,
    );
  }
}

class AdminSessionNotifier extends Notifier<AdminSessionState> {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _passKey = 'admin.password';

  @override
  AdminSessionState build() {
    _load();
    return const AdminSessionState.initial();
  }

  Future<void> _load() async {
    final String? savedPassword = await _storage.read(key: _passKey);
    if (savedPassword != null && savedPassword.isNotEmpty) {
      await unlock(savedPassword, save: false);
    }
    state = state.copyWith(hydrated: true);
  }

  Future<bool> unlock(String password, {bool save = true}) async {
    final String trimmed = password.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        error: 'Admin password is empty',
        clearPassword: true,
      );
      return false;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final AdminRepository repo = AdminRepository(
        AdminApiClient(baseUrl: adminApiBaseUrl, readPassword: () => trimmed),
      );
      await repo.validatePassword(passwordOverride: trimmed);
      
      if (save) {
        await _storage.write(key: _passKey, value: trimmed);
      }

      state = state.copyWith(
        unlocked: true,
        busy: false,
        password: trimmed,
        clearError: true,
      );
      return true;
    } catch (error) {
      final String message = error is ApiException ? error.message : '$error';
      state = state.copyWith(
        busy: false,
        unlocked: false,
        clearPassword: true,
        error: message,
      );
      if (save) {
        await _storage.delete(key: _passKey);
      }
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _passKey);
    state = const AdminSessionState.initial().copyWith(hydrated: true);
  }
}

final NotifierProvider<AdminSessionNotifier, AdminSessionState>
adminSessionProvider =
    NotifierProvider<AdminSessionNotifier, AdminSessionState>(
      AdminSessionNotifier.new,
    );

final Provider<AdminRepository> adminRepositoryProvider =
    Provider<AdminRepository>((Ref ref) {
      final String? password = ref.watch(
        adminSessionProvider.select((s) => s.password),
      );
      return AdminRepository(
        AdminApiClient(baseUrl: adminApiBaseUrl, readPassword: () => password),
      );
    });

