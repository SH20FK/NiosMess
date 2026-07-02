import 'dart:convert';
import 'dart:developer' show log;
import 'package:cryptography/cryptography.dart';

void main() async {
  log('Testing cryptography package inside project...');
  final algorithm = AesGcm.with256bits();

  // Test AES key (32 bytes)
  final keyBytes = List<int>.generate(32, (i) => i);
  final secretKey = SecretKey(keyBytes);

  final message = 'Hello, NiosMess WebSocket Encryption!';
  final messageBytes = utf8.encode(message);

  log('Original message: $message');

  // Encrypt
  final secretBox = await algorithm.encrypt(
    messageBytes,
    secretKey: secretKey,
  );

  final ciphertextBase64 = base64Encode(secretBox.cipherText);
  final ivBase64 = base64Encode(secretBox.nonce);
  final tagBase64 = base64Encode(secretBox.mac.bytes);

  log('Ciphertext (Base64): $ciphertextBase64');
  log('IV (Base64): $ivBase64');
  log('Tag (Base64): $tagBase64');

  // Decrypt
  final decodedCiphertext = base64Decode(ciphertextBase64);
  final decodedIv = base64Decode(ivBase64);
  final decodedTag = base64Decode(tagBase64);

  final secretBoxToDecrypt = SecretBox(
    decodedCiphertext,
    nonce: decodedIv,
    mac: Mac(decodedTag),
  );

  final decryptedBytes = await algorithm.decrypt(
    secretBoxToDecrypt,
    secretKey: secretKey,
  );

  final decryptedMessage = utf8.decode(decryptedBytes);
  log('Decrypted message: $decryptedMessage');

  if (decryptedMessage == message) {
    log('SUCCESS! Cryptography works as expected.');
  } else {
    log('FAILURE! Decrypted message mismatch.');
  }
}
