import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// The one dependency shared by every disk-backed cache.
///
/// Box opens may run in parallel only after this future has completed. Failed
/// initialization is reported to the caller and may be retried.
class HiveBootstrap {
  HiveBootstrap._();

  static Future<void>? _initialization;

  static Future<void> ensureInitialized() =>
      _initialization ??= _initialize().catchError((Object error) {
        _initialization = null;
        throw error;
      });

  static Future<void> _initialize() async {
    if (kIsWeb) return;
    // Embedders and tests may already have selected an explicit directory via
    // Hive.init. Check it through the public API without opening a box or
    // replacing that directory with path_provider's default.
    try {
      await Hive.boxExists('niosmess_bootstrap_probe');
      return;
    } on HiveError catch (error) {
      if (!error.message.contains('initialize Hive')) rethrow;
    } on ArgumentError catch (error) {
      // Hive 2.2's boxExists validates an uninitialized home path this way.
      if (error.name != 'path' || error.invalidValue != null) rethrow;
    }
    await Hive.initFlutter();
  }

  @visibleForTesting
  static void resetForTesting() => _initialization = null;
}
