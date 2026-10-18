import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';

/// Read only after explicit consent. Raw identifiers never leave this device.
class PurchaseDeviceIdentity {
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isWindows || Platform.isLinux);
  static Future<String> readHash() async {
    if (kIsWeb) throw StateError('Активация доступна только в приложении');
    if (Platform.isAndroid) {
      final hash = await const MethodChannel(
        'app.niosmess/system',
      ).invokeMethod<String>('getPurchaseDeviceHash');
      if (hash != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) return hash;
    } else if (Platform.isWindows) {
      final result = await Process.run('reg.exe', [
        'query',
        r'HKLM\SOFTWARE\Microsoft\Cryptography',
        '/v',
        'MachineGuid',
        '/reg:64',
      ]).timeout(const Duration(seconds: 5));
      final match = RegExp(
        r'MachineGuid\s+REG_SZ\s+([a-zA-Z0-9-]+)',
      ).firstMatch(result.stdout.toString());
      if (result.exitCode == 0 && match != null) {
        return sha256
            .convert(
              utf8.encode(
                'niosmess-purchase-v1\u0000windows\u0000${match.group(1)!.toLowerCase()}',
              ),
            )
            .toString();
      }
    } else if (Platform.isLinux) {
      final id = (await File('/etc/machine-id').readAsString()).trim();
      if (RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
        return sha256
            .convert(utf8.encode('niosmess-purchase-v1\u0000linux\u0000$id'))
            .toString();
      }
    }
    throw StateError(
      'Не удалось получить идентификатор устройства. Активация не выполнена.',
    );
  }
}
