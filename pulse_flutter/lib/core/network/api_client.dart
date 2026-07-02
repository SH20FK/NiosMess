import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/core/exceptions/api_exception.dart';

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
  static const Duration _timeout = Duration(seconds: 15);

  Future<dynamic> get(String path, {Map<String, String>? query}) {
    return _request('GET', path, query: query);
  }

  Future<dynamic> post(String path, {Object? body, Map<String, String>? query}) {
    return _request('POST', path, body: body, query: query);
  }

  Future<dynamic> put(String path, {Object? body, Map<String, String>? query}) {
    return _request('PUT', path, body: body, query: query);
  }

  Future<dynamic> patch(String path, {Object? body, Map<String, String>? query}) {
    return _request('PATCH', path, body: body, query: query);
  }

  Future<dynamic> delete(String path, {Map<String, String>? query}) {
    return _request('DELETE', path, query: query);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final Uri uri = _buildUri(path, query: query);
    final Map<String, String> headers = _buildHeaders(body: body);

    try {
      final http.Response response;
      switch (method) {
        case 'GET':
          response = await _http.get(uri, headers: headers).timeout(_timeout);
        case 'POST':
          response = await _http
              .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(_timeout);
        case 'PUT':
          response = await _http
              .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(_timeout);
        case 'PATCH':
          response = await _http
              .patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(_timeout);
        case 'DELETE':
          response = await _http.delete(uri, headers: headers).timeout(_timeout);
        default:
          throw ApiException(statusCode: 0, message: 'Unsupported method: $method');
      }

      if (response.statusCode == 401) {
        onUnauthorized?.call();
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String bodyText = response.body;
        String errorMessage = 'Server error (${response.statusCode})';
        try {
          final dynamic json = jsonDecode(bodyText);
          if (json is Map<String, dynamic>) {
            errorMessage = json['message'] as String? ??
                json['error'] as String? ??
                json['detail'] as String? ??
                errorMessage;
          }
        } catch (_) {}
        throw ApiException(statusCode: response.statusCode, message: errorMessage);
      }

      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(statusCode: 0, message: 'Request timed out');
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'Network error: $e');
    }
  }

  Uri _buildUri(String path, {Map<String, String>? query}) {
    final Uri rawUri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return rawUri;
    return rawUri.replace(queryParameters: {...rawUri.queryParameters, ...query});
  }

  Map<String, String> _buildHeaders({Object? body}) {
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
    };
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    final String? token = readToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  void close() {
    _http.close();
  }

  Future<List<int>> postBytes(String path, {Object? body, Map<String, String>? query}) async {
    final Uri uri = _buildUri(path, query: query);
    final Map<String, String> headers = _buildHeaders(body: body);

    try {
      final http.Response response = await _http
          .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(statusCode: response.statusCode, message: 'Upload failed');
      }
      return response.bodyBytes;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(statusCode: 0, message: 'Request timed out');
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'Network error: $e');
    }
  }
}
