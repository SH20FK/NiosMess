import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Centralized error state managed via Riverpod.
class AppError {
  const AppError({required this.message, this.stackTrace});
  final String message;
  final StackTrace? stackTrace;
}

class ErrorHandlerNotifier extends StateNotifier<AppError?> {
  ErrorHandlerNotifier() : super(null);

  void report(String message, [StackTrace? stackTrace]) {
    state = AppError(message: message, stackTrace: stackTrace);
  }

  void clear() => state = null;

  void reportException(Object error, StackTrace stackTrace) {
    final String message = error is Exception ? error.toString() : 'Unknown error';
    state = AppError(message: message, stackTrace: stackTrace);
  }
}

final StateNotifierProvider<ErrorHandlerNotifier, AppError?> errorHandlerProvider =
    StateNotifierProvider<ErrorHandlerNotifier, AppError?>(
      (Ref ref) => ErrorHandlerNotifier(),
    );
