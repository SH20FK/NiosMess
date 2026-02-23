import 'package:flutter/foundation.dart';

/// Централизованная обработка ошибок
/// Заменяет все catch (_) {} блоки в проекте
class ErrorHandler {
  /// Обработка ошибок с логированием
  static void handle(dynamic error, {StackTrace? stackTrace, String? context}) {
    final errorMessage = 'Error${context != null ? ' in $context' : ''}: $error';

    // Логирование в консоль (debug mode)
    debugPrint(errorMessage);
    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
    }

    // TODO: В продакшене отправлять в Firebase Crashlytics
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }

  /// Обработка Future с fallback значением
  static Future<T> handleAsync<T>(
    Future<T> Function() fn,
    T fallback, {
    String? context,
  }) async {
    try {
      return await fn();
    } catch (e, stack) {
      handle(e, stackTrace: stack, context: context);
      return fallback;
    }
  }

  /// Обработка синхронных операций
  static T handleSync<T>(
    T Function() fn,
    T fallback, {
    String? context,
  }) {
    try {
      return fn();
    } catch (e, stack) {
      handle(e, stackTrace: stack, context: context);
      return fallback;
    }
  }

  /// Показать пользователю понятное сообщение об ошибке
  static String getUserMessage(dynamic error) {
    if (error.toString().contains('SocketException')) {
      return 'Нет подключения к интернету';
    }
    if (error.toString().contains('TimeoutException')) {
      return 'Превышено время ожидания';
    }
    if (error.toString().contains('FormatException')) {
      return 'Ошибка формата данных';
    }
    if (error.toString().contains('401') || error.toString().contains('Unauthorized')) {
      return 'Необходима авторизация';
    }
    if (error.toString().contains('403') || error.toString().contains('Forbidden')) {
      return 'Доступ запрещён';
    }
    if (error.toString().contains('404') || error.toString().contains('Not Found')) {
      return 'Данные не найдены';
    }
    if (error.toString().contains('500')) {
      return 'Ошибка сервера';
    }
    return 'Произошла ошибка. Попробуйте позже';
  }
}

/// Extension для упрощения использования
extension FutureErrorHandler<T> on Future<T> {
  /// Обработка ошибок с fallback
  Future<T> handleError(T fallback, {String? context}) {
    return ErrorHandler.handleAsync(() => this, fallback, context: context);
  }
}
