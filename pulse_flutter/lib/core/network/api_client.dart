import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/network/api_exception.dart';

Map<String, dynamic> asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic val) => MapEntry(key.toString(), val),
    );
  }
  return <String, dynamic>{};
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.readToken,
    this.onUnauthorized,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String? Function() readToken;
  final VoidCallback? onUnauthorized;
  final http.Client _http;
  static const Duration connectTimeout = Duration(seconds: 10);

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _request('GET', path, query: query, auth: auth);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _request('POST', path, body: body, query: query, auth: auth);
  }

  Future<dynamic> postMultipart(
    String path, {
    Map<String, String>? fields,
    String? fileField,
    List<int>? fileBytes,
    String? fileName,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final Uri uri = _buildUri(path, query: query);
    final Map<String, String> headers = _buildHeaders(
      auth: auth,
      withJson: false,
    );

    final http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers);

    if (fields != null && fields.isNotEmpty) {
      request.fields.addAll(fields);
    }

    if (fileField != null && fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: fileName ?? 'chunk.bin',
        ),
      );
    }

    http.Response response;
    try {
      final http.StreamedResponse streamed = await request.send();
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException(statusCode: 0, message: 'Превышено время ожидания ответа от сервера');
    } catch (error) {
      throw ApiException(statusCode: 0, message: _networkErrorMessage(error));
    }

    final dynamic payload = await _tryDecode(response.body);
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractError(payload, response.body),
        payload: payload,
      );
    }

    return payload;
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _request('PATCH', path, body: body, query: query, auth: auth);
  }

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _request('DELETE', path, body: body, query: query, auth: auth);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final Uri uri = _buildUri(path, query: query);
    final Map<String, String> headers = _buildHeaders(
      auth: auth,
      withJson: body != null,
    );

    http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await _http.get(uri, headers: headers).timeout(connectTimeout);
        case 'POST':
          response = await _http.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          ).timeout(connectTimeout);
        case 'PATCH':
          response = await _http.patch(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          ).timeout(connectTimeout);
        case 'DELETE':
          response = await _http.delete(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          ).timeout(connectTimeout);
        default:
          throw ApiException(
            statusCode: 0,
            message: 'Неподдерживаемый метод запроса',
          );
      }
    } on TimeoutException {
      throw ApiException(statusCode: 0, message: 'Превышено время ожидания ответа от сервера');
    } catch (error) {
      throw ApiException(statusCode: 0, message: _networkErrorMessage(error));
    }

    final dynamic payload = await _tryDecode(response.body);
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractError(payload, response.body),
        payload: payload,
      );
    }

    return payload;
  }

  Uri _buildUri(String path, {Map<String, String>? query}) {
    final bool absolute =
        path.startsWith('http://') || path.startsWith('https://');
    final Uri rawUri = absolute ? Uri.parse(path) : Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) {
      return rawUri;
    }
    return rawUri.replace(
      queryParameters: <String, String>{...rawUri.queryParameters, ...query},
    );
  }

  Map<String, String> _buildHeaders({
    required bool auth,
    required bool withJson,
  }) {
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
    };
    if (withJson) {
      headers['Content-Type'] = 'application/json';
    }

    if (auth) {
      final String? token = readToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> _tryDecode(String body) async {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      return await compute(jsonDecode, body);
    } catch (_) {
      return body;
    }
  }

  String _extractError(dynamic payload, String body) {
    if (payload is Map<String, dynamic>) {
      final Object? detail = payload['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
      final Object? message = payload['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    if (body.trim().isNotEmpty) {
      return body; // Возвращаем тело только если уверены, что оно полезно. Часто тут HTML от 502/404.
    }
    return 'Произошла неизвестная ошибка';
  }

  String _networkErrorMessage(Object error) {
    if (error is SocketException) {
      final String lowered = error.message.toLowerCase();
      if (lowered.contains('failed host lookup') ||
          lowered.contains('no address associated with hostname')) {
        return 'Ошибка DNS: невозможно разрешить адрес сервера.';
      }
      return 'Ошибка сетевого подключения.';
    }

    final String text = '$error';
    final String lowered = text.toLowerCase();
    if (lowered.contains('failed host lookup') ||
        lowered.contains('no address associated with hostname')) {
      return 'Ошибка DNS: невозможно разрешить адрес сервера.';
    }

    return 'Проблема с сетью: проверьте интернет-соединение.';
  }
}
