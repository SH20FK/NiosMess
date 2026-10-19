import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

/// Avatars and stickers use the binary transport, independently of chat blobs.
class PublicMediaUploadService {
  PublicMediaUploadService(this._client, this._readToken);

  final http.Client _client;
  final String? Function() _readToken;

  Future<String> upload(Uint8List bytes, {required String filename}) async {
    final token = _readToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(statusCode: 401, message: 'Войдите в аккаунт');
    }
    if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) {
      throw const ApiException(
        statusCode: 413,
        message: 'Недопустимый размер файла',
      );
    }
    final abort = Completer<void>();
    final timer = Timer(const Duration(minutes: 3), () => abort.complete());
    try {
      final request =
          http.AbortableMultipartRequest(
              'POST',
              Uri.parse('${ApiConstants.origin}/api/files/upload'),
              abortTrigger: abort.future,
            )
            ..fields['token'] = token
            ..fields['media_subtype'] = 'media'
            ..files.add(
              http.MultipartFile.fromBytes('file', bytes, filename: filename),
            );
      final response = await _client.send(request);
      final body = await response.stream.bytesToString();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          statusCode: response.statusCode,
          message: response.statusCode == 413
              ? 'Файл превышает допустимый размер'
              : 'Не удалось загрузить файл. Попробуйте ещё раз.',
        );
      }
      final dynamic result = jsonDecode(body);
      final dynamic uploadId = result is Map ? result['upload_id'] : null;
      if (uploadId is! String ||
          !RegExp(r'^[a-f0-9]{32}$').hasMatch(uploadId)) {
        throw const ApiException(
          statusCode: 502,
          message: 'Некорректный ответ загрузки',
        );
      }
      return uploadId;
    } on http.RequestAbortedException {
      throw const ApiException(
        statusCode: 0,
        message: 'Время загрузки истекло',
      );
    } finally {
      timer.cancel();
    }
  }
}

final publicMediaUploadServiceProvider = Provider<PublicMediaUploadService>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return PublicMediaUploadService(
    client,
    () => ref.read(authProvider).session?.accessToken,
  );
});
