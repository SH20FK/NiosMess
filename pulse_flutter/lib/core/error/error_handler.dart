import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppError {
  const AppError({required this.message, this.stackTrace});
  final String message;
  final StackTrace? stackTrace;
}

class ErrorHandlerNotifier extends Notifier<AppError?> {
  @override
  AppError? build() => null;

  void report(String message, [StackTrace? stackTrace]) {
    state = AppError(message: message, stackTrace: stackTrace);
  }

  void clear() => state = null;

  void reportException(Object error, StackTrace stackTrace) {
    final String message = error is Exception ? error.toString() : 'Unknown error';
    state = AppError(message: message, stackTrace: stackTrace);
  }
}

final NotifierProvider<ErrorHandlerNotifier, AppError?> errorHandlerProvider =
    NotifierProvider<ErrorHandlerNotifier, AppError?>(
      ErrorHandlerNotifier.new,
    );
