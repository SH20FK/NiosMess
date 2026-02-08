import 'package:dio/dio.dart';
import 'constants.dart';

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
    final res = await _dio.post(path, data: form ?? data);
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    final res = await _dio.get(path, queryParameters: query);
    return _asMap(res.data);
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{'data': data};
  }
}
