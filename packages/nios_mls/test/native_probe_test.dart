import 'dart:typed_data';
import 'package:openmls/openmls.dart';
import 'package:test/test.dart';

void main() {
  test('native OpenMLS initializes SQLCipher engine', () async {
    await Openmls.init();
    final engine = await MlsEngine.create(
      dbPath: ':memory:',
      encryptionKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
    );
    await engine.close();
  });
}
