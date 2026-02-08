import 'package:dio/dio.dart';
import 'constants.dart';

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
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
  }

  static final ApiClient instance = ApiClient._();
  late final Dio _dio;

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
    return <String, dynamic>{'data': data};
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['message'] ?? data['error'];
      if (detail != null) return detail.toString();
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
