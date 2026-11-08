import 'dart:isolate';
import 'dart:typed_data';

/// The action type for RPC commands dispatched to the background Headless Core Isolate.
enum WorkerAction {
  ping,
  initStorage,
  encryptPayload,
  decryptPayloadBatch,
  hashMediaStream,
  searchHistory,
  walCheckpoint,
  shutdown,
}

/// A request dispatched from the UI isolate to the background Headless Core Isolate.
final class WorkerRequest {
  final int id;
  final WorkerAction action;
  final Map<String, dynamic> payload;
  final TransferableTypedData? transferableBytes;

  const WorkerRequest({
    required this.id,
    required this.action,
    this.payload = const <String, dynamic>{},
    this.transferableBytes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'action': action.name,
    'payload': payload,
    'bytes': transferableBytes,
  };
}

/// A response sent back from the background Headless Core Isolate to the UI isolate.
final class WorkerResponse {
  final int id;
  final bool success;
  final dynamic data;
  final String? error;
  final TransferableTypedData? transferableBytes;

  const WorkerResponse({
    required this.id,
    required this.success,
    this.data,
    this.error,
    this.transferableBytes,
  });

  /// Extracts underlying Uint8List safely without copying memory twice.
  Uint8List? get materialBytes =>
      transferableBytes?.materialize().asUint8List();

  factory WorkerResponse.ok(
    int id, {
    dynamic data,
    TransferableTypedData? bytes,
  }) => WorkerResponse(
    id: id,
    success: true,
    data: data,
    transferableBytes: bytes,
  );

  factory WorkerResponse.fail(int id, String error) => WorkerResponse(
    id: id,
    success: false,
    error: error,
  );
}

/// Asynchronous stream event emitted by the worker isolate without a direct RPC trigger.
final class WorkerEvent {
  final String type;
  final Map<String, dynamic> payload;

  const WorkerEvent({
    required this.type,
    this.payload = const <String, dynamic>{},
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'payload': payload,
  };
}
