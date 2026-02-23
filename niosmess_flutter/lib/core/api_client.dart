import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'constants.dart';
import 'utils/json_utils.dart';

class ApiClientException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  ApiClientException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => 'ApiClientException: $message (status: $statusCode)';
}

class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBase,
        responseType: ResponseType.plain,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    if (AppConfig.apiDebug) {
      _dio.interceptors.add(_ApiLoggingInterceptor());
    }
  }

  static final ApiClient instance = ApiClient._();
  late final Dio _dio;

  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data, FormData? form}) async {
    try {
      final res = await _dio.post(path, data: form ?? data);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw ApiClientException(
        _extractErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    } catch (e) {
      throw ApiClientException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw ApiClientException(
        _extractErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    } catch (e) {
      throw ApiClientException('Network error: $e');
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      final parsed = safeJsonDecode<dynamic>(
        data,
        context: 'api_response',
      );
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
      if (parsed is List) return <String, dynamic>{'data': parsed};
      if (parsed != null) return <String, dynamic>{'data': parsed};
      return <String, dynamic>{'data': data};
    }
    return <String, dynamic>{'data': data};
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['message'] ?? data['error'];
      if (detail != null) return detail.toString();
    } else if (data is String) {
      final parsed = safeJsonDecode<dynamic>(
        data,
        context: 'api_error_response',
      );
      if (parsed is Map) {
        final detail = parsed['detail'] ?? parsed['message'] ?? parsed['error'];
        if (detail != null) return detail.toString();
      }
    }
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      return 'Server response timeout. Please try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection. Please check your network.';
    }
    return e.message ?? 'Unknown network error';
  }
}

class _ApiLoggingInterceptor extends Interceptor {
  static const _tsKey = 'nios_ts';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_tsKey] = DateTime.now().millisecondsSinceEpoch;
    _logRequest(options);
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logResponse(response);
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logError(err);
    super.onError(err, handler);
  }

  void _logRequest(RequestOptions options) {
    final uri = options.uri.toString();
    final method = options.method;
    final headers = _redactHeaders(options.headers);
    final query = options.queryParameters;
    final data = options.data;
    final dataPreview = _formatData(data);
    debugPrint(
      '[API] -> $method $uri\n'
      '  headers: $headers\n'
      '  query: $query\n'
      '  data: $dataPreview',
    );
  }

  void _logResponse(Response response) {
    final req = response.requestOptions;
    final elapsed = _elapsedMs(req);
    final status = response.statusCode;
    final uri = req.uri.toString();
    final dataPreview = _formatData(response.data);
    debugPrint(
      '[API] <- $status ${req.method} $uri (${elapsed}ms)\n'
      '  data: $dataPreview',
    );
  }

  void _logError(DioException err) {
    final req = err.requestOptions;
    final elapsed = _elapsedMs(req);
    final status = err.response?.statusCode;
    final uri = req.uri.toString();
    final dataPreview = _formatData(err.response?.data ?? err.message);
    debugPrint(
      '[API] !! ${req.method} $uri (${elapsed}ms)\n'
      '  status: $status\n'
      '  error: ${err.type} ${err.message}\n'
      '  data: $dataPreview',
    );
  }

  int _elapsedMs(RequestOptions options) {
    final ts = options.extra[_tsKey];
    if (ts is int) {
      return DateTime.now().millisecondsSinceEpoch - ts;
    }
    return -1;
  }

  Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    final redacted = <String, dynamic>{};
    headers.forEach((key, value) {
      if (_isSensitiveKey(key)) {
        redacted[key] = '***';
      } else {
        redacted[key] = value;
      }
    });
    return redacted;
  }

  bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('authorization') ||
        lower.contains('token') ||
        lower.contains('password') ||
        lower.contains('session') ||
        lower.contains('secret');
  }

  String _formatData(dynamic data) {
    if (data == null) return 'null';
    if (data is FormData) {
      final fields = <String, dynamic>{};
      for (final f in data.fields) {
        fields[f.key] = _isSensitiveKey(f.key) ? '***' : f.value;
      }
      final files = data.files
          .map((f) => {
                'field': f.key,
                'filename': f.value.filename,
                'length': f.value.length,
              })
          .toList();
      return _truncate('FormData(fields=$fields, files=$files)');
    }
    if (data is Map) {
      final redacted = <String, dynamic>{};
      data.forEach((key, value) {
        final k = key.toString();
        redacted[k] = _isSensitiveKey(k) ? '***' : value;
      });
      return _truncate(redacted.toString());
    }
    if (data is String) {
      return _truncate(data);
    }
    return _truncate(data.toString());
  }

  String _truncate(String input) {
    final max = AppConfig.apiLogMaxBody;
    if (input.length <= max) return input;
    return '${input.substring(0, max)}...<truncated>';
  }
}
