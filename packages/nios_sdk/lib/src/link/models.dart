import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

enum DeliveryFact {
  localDurable,
  mailboxStored,
  recipientStored,
  recipientApplied,
  userRead,
}

/// Metadata is authenticated, including the direction and protocol domain.
class EnvelopeContext {
  const EnvelopeContext({
    required this.senderId,
    required this.recipientId,
    required this.sessionId,
    required this.operationId,
    required this.sequence,
    this.kind = 'operation',
  });

  final String senderId;
  final String recipientId;
  final String sessionId;
  final String operationId;
  final int sequence;
  final String kind;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'kind': kind,
    'sender': senderId,
    'recipient': recipientId,
    'session': sessionId,
    'id': operationId,
    'sequence': sequence,
  };

  Uint8List get associatedData =>
      Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory EnvelopeContext.fromJson(Map<String, dynamic> json) {
    if (json['v'] != 1 || !const {'operation', 'ack'}.contains(json['kind'])) {
      throw const FormatException('Unsupported envelope version or domain');
    }
    for (final name in ['sender', 'recipient', 'session', 'id']) {
      final value = json[name];
      if (value is! String || value.isEmpty || value.length > 256) {
        throw FormatException('Invalid envelope $name');
      }
    }
    final sequence = json['sequence'];
    if (sequence is! int || sequence < 1 || sequence > 9007199254740991) {
      throw const FormatException('Invalid envelope sequence');
    }
    return EnvelopeContext(
      senderId: json['sender'] as String,
      recipientId: json['recipient'] as String,
      sessionId: json['session'] as String,
      operationId: json['id'] as String,
      sequence: sequence,
      kind: json['kind'] as String,
    );
  }
}

class EncryptedEnvelope {
  EncryptedEnvelope({
    required this.context,
    required List<int> nonce,
    required List<int> ciphertext,
    required List<int> mac,
    List<int>? signature,
  }) : nonce = Uint8List.fromList(nonce).asUnmodifiableView(),
       ciphertext = Uint8List.fromList(ciphertext).asUnmodifiableView(),
       mac = Uint8List.fromList(mac).asUnmodifiableView(),
       signature = signature == null
           ? null
           : Uint8List.fromList(signature).asUnmodifiableView() {
    if (this.nonce.length != 12 ||
        this.mac.length != 16 ||
        ciphertext.length > 1048576) {
      throw const FormatException('Invalid AES-GCM envelope bounds');
    }
    if (this.signature != null && this.signature!.length != 64) {
      throw const FormatException('Invalid Ed25519 signature size');
    }
  }

  final EnvelopeContext context;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List mac;
  final Uint8List? signature;

  Map<String, dynamic> toJson() => {
    ...context.toJson(),
    'nonce': base64Encode(nonce),
    'ciphertext': base64Encode(ciphertext),
    'mac': base64Encode(mac),
    if (signature != null) 'signature': base64Encode(signature!),
  };

  factory EncryptedEnvelope.fromJson(Map<String, dynamic> json) =>
      EncryptedEnvelope(
        context: EnvelopeContext.fromJson(json),
        nonce: base64Decode(json['nonce'] as String),
        ciphertext: base64Decode(json['ciphertext'] as String),
        mac: base64Decode(json['mac'] as String),
        signature: json['signature'] == null
            ? null
            : base64Decode(json['signature'] as String),
      );

  String get digest =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();

  Uint8List get signatureInput => Uint8List.fromList(
    utf8.encode(
      'nios-link-device-envelope-signature-v1\u0000${jsonEncode({...context.toJson(), 'nonce': base64Encode(nonce), 'ciphertext': base64Encode(ciphertext), 'mac': base64Encode(mac)})}',
    ),
  );
}

class DurableOperation {
  const DurableOperation({required this.context, required this.payload});
  final EnvelopeContext context;
  final Map<String, dynamic> payload;
}

class SavedOperation {
  SavedOperation({
    required this.context,
    required this.preparedEnvelope,
    required Set<DeliveryFact> facts,
    required this.attempts,
    required this.nextAttemptAt,
    this.errorCode,
  }) : facts = Set.unmodifiable(facts);

  final EnvelopeContext context;
  final EncryptedEnvelope? preparedEnvelope;
  bool get isPrepared => preparedEnvelope != null;

  /// Available only after a trusted peer key has prepared the immutable bytes.
  EncryptedEnvelope get envelope =>
      preparedEnvelope ??
      (throw StateError(
        'Operation is durably saved while awaiting a peer key',
      ));
  final Set<DeliveryFact> facts;
  final int attempts;
  final DateTime nextAttemptAt;
  final String? errorCode;

  String get operationId => context.operationId;
  bool get applied => facts.contains(DeliveryFact.recipientApplied);
}

/// Reducers must be deterministic and perform no external side effects.
/// Their returned state and the deduplication record are committed together.
typedef OperationReducer =
    Map<String, dynamic> Function(
      Map<String, dynamic> previous,
      DurableOperation operation,
    );

class LinkEvent {
  const LinkEvent(this.operationId, this.facts, {this.errorCode});
  final String operationId;
  final Set<DeliveryFact> facts;
  final String? errorCode;
}
