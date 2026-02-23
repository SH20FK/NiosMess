class AppConfig {
  // Default backend.
  // Override via: --dart-define=NIOS_API_BASE=http://your-host:5058
  static const String apiBase = String.fromEnvironment(
    'NIOS_API_BASE',
    defaultValue: 'https://web.sa2rn.fun',
  );

  // Enable verbose API logs via: --dart-define=NIOS_API_DEBUG=true
  static const bool apiDebug = bool.fromEnvironment(
    'NIOS_API_DEBUG',
    defaultValue: false,
  );

  // Max body characters to print in logs.
  static const int apiLogMaxBody = int.fromEnvironment(
    'NIOS_API_LOG_BODY',
    defaultValue: 2000,
  );
}
