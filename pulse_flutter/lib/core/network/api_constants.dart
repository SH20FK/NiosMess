class ApiConstants {
  const ApiConstants._();

  static const String origin = 'https://ni-os.ru';
  static const String baseUrl = 'https://ni-os.ru/api/v1';

  static String resolve(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final String raw = url.trim();
    if (raw.startsWith('http')) return raw;
    return '$origin${raw.startsWith('/') ? '' : '/'}$raw';
  }
}
