class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message, this.payload});

  final int statusCode;
  final String message;
  final Object? payload;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
