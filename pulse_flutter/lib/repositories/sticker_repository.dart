import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/web_socket_provider.dart';

class StickerRepository {
  const StickerRepository(this._ref);

  final Ref _ref;

  /// Retrieves all sticker sets in the user's active collection.
  Future<List<ApiStickerSet>> listStickerSets() async {
    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('list_sticker_sets', payload: const <String, dynamic>{});

    if (response is Map && response['sets'] is List) {
      return (response['sets'] as List)
          .whereType<Map>()
          .map(
            (Map m) => ApiStickerSet.fromJson(
              m.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList(growable: false);
    } else if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (Map m) => ApiStickerSet.fromJson(
              m.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList(growable: false);
    }

    return const <ApiStickerSet>[];
  }

  /// Retrieves a specific sticker set by its ID.
  Future<ApiStickerSet?> getStickerSet(int setId) async {
    final dynamic response = await _ref.read(webSocketClientProvider).request(
      'get_sticker_set',
      payload: <String, dynamic>{'set_id': setId},
    );

    if (response is Map) {
      final dynamic rawSet = response['set'] ??
          response['sticker_set'] ??
          response['data'] ??
          response['result'] ??
          response;
      if (rawSet is Map) {
        return ApiStickerSet.fromJson(
          rawSet.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
        );
      }
    }
    return null;
  }

  /// Creates a new public or personal sticker set.
  /// The first uploaded sticker automatically becomes the pack cover.
  Future<ApiStickerSet> createStickerSet({
    required String name,
    required String title,
    bool isPublic = true,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'name': name.trim(),
      'title': title.trim(),
      'is_public': isPublic,
    };

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('create_sticker_set', payload: payload);

    if (response is! Map) {
      throw ApiException(
        statusCode: 500,
        message: 'Invalid server response for create_sticker_set',
      );
    }

    return ApiStickerSet.fromJson(
      response.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
    );
  }

  /// Uploads a sticker (image or video) with optional emoji association.
  Future<ApiSticker> addSticker({
    required int setId,
    required String filename,
    required String dataBase64,
    int? width,
    int? height,
    int? durationSeconds,
    String? emoji,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'set_id': setId,
      'filename': filename,
      'data_base64': dataBase64,
    };
    if (width != null) payload['width'] = width;
    if (height != null) payload['height'] = height;
    if (durationSeconds != null) payload['duration_seconds'] = durationSeconds;
    if (emoji != null && emoji.isNotEmpty) payload['emoji'] = emoji;

    final dynamic response = await _ref
        .read(webSocketClientProvider)
        .request('add_sticker', payload: payload);

    if (response is! Map) {
      throw ApiException(
        statusCode: 500,
        message: 'Invalid server response for add_sticker',
      );
    }

    return ApiSticker.fromJson(
      response.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
    );
  }

  /// Adds another user's public sticker pack to the current user's collection.
  Future<void> saveStickerSet(int setId) async {
    await _ref
        .read(webSocketClientProvider)
        .request('save_sticker_set', payload: <String, dynamic>{'set_id': setId});
  }

  /// Removes a sticker pack from the personal collection.
  /// If [deletePermanently] is true (author only), deletes the pack completely from the server.
  Future<void> removeStickerSet(
    int setId, {
    bool deletePermanently = false,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'set_id': setId,
      if (deletePermanently) 'delete_permanently': true,
    };

    await _ref
        .read(webSocketClientProvider)
        .request('remove_sticker_set', payload: payload);
  }

  /// Permanently deletes an individual sticker from a pack (author only).
  Future<void> deleteSticker(int stickerId) async {
    await _ref.read(webSocketClientProvider).request(
      'delete_sticker',
      payload: <String, dynamic>{'sticker_id': stickerId},
    );
  }
}

final Provider<StickerRepository> stickerRepositoryProvider =
    Provider<StickerRepository>((Ref ref) => StickerRepository(ref));
