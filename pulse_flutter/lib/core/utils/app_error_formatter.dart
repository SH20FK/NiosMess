import 'dart:async';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:universal_io/io.dart';

/// Formatted, user-friendly Russian error representation.
class AppFormattedError {
  const AppFormattedError({
    required this.title,
    this.description,
    this.technicalDetails,
  });

  final String title;
  final String? description;
  final String? technicalDetails;

  @override
  String toString() => description != null ? '$title: $description' : title;
}

/// Central error localization engine for NiosMess.
/// Translates technical network exceptions, HTTP status codes,
/// and backend error slugs into clear, empathetic Russian messages.
class AppErrorFormatter {
  AppErrorFormatter._();

  static AppFormattedError format(dynamic error, {String? fallbackTitle}) {
    if (error == null) {
      return AppFormattedError(
        title: fallbackTitle ?? 'Произошла непредвиденная ошибка',
        description: 'Пожалуйста, попробуйте позже',
      );
    }

    if (error is AppFormattedError) {
      return error;
    }

    // 1. SocketException / Network offline
    if (error is SocketException) {
      return AppFormattedError(
        title: 'Нет подключения к интернету',
        description: 'Проверьте сеть Wi-Fi или сотовые данные и повторите попытку.',
        technicalDetails: error.toString(),
      );
    }

    // 2. TimeoutException
    if (error is TimeoutException) {
      return AppFormattedError(
        title: 'Сервер не ответил вовремя',
        description: 'Соединение заняло слишком много времени. Попробуйте ещё раз.',
        technicalDetails: error.toString(),
      );
    }

    // 3. HandshakeException / SSL errors
    if (error is HandshakeException) {
      return AppFormattedError(
        title: 'Ошибка защищённого соединения',
        description: 'Не удалось установить безопасный канал связи с сервером.',
        technicalDetails: error.toString(),
      );
    }

    // 4. ApiException
    if (error is ApiException) {
      return _formatApiException(error);
    }

    // 5. String-based error analysis
    final String raw = error.toString().trim();
    return _formatStringError(raw, fallbackTitle: fallbackTitle);
  }

  static AppFormattedError _formatApiException(ApiException error) {
    final int code = error.statusCode;
    final String msg = error.message.trim().toLowerCase();

    // Specific backend slug matching
    final AppFormattedError? slugError = _matchSlug(msg, technical: error.toString());
    if (slugError != null) return slugError;

    switch (code) {
      case 400:
        return AppFormattedError(
          title: 'Некорректный запрос',
          description: 'Проверьте введённые данные и попробуйте снова.',
          technicalDetails: error.toString(),
        );
      case 401:
        return AppFormattedError(
          title: 'Сессия устарела',
          description: 'Пожалуйста, войдите в аккаунт заново.',
          technicalDetails: error.toString(),
        );
      case 403:
        return AppFormattedError(
          title: 'Доступ ограничен',
          description: 'У вас недостаточно прав для выполнения этого действия.',
          technicalDetails: error.toString(),
        );
      case 404:
        return AppFormattedError(
          title: 'Не найдено',
          description: 'Запрашиваемый чат, сообщение или ресурс не существуют.',
          technicalDetails: error.toString(),
        );
      case 409:
        return AppFormattedError(
          title: 'Конфликт данных',
          description: 'Такая запись или имя пользователя уже занято.',
          technicalDetails: error.toString(),
        );
      case 413:
        return AppFormattedError(
          title: 'Файл слишком большой',
          description: 'Размер выбранного файла превышает допустимый лимит.',
          technicalDetails: error.toString(),
        );
      case 429:
        return AppFormattedError(
          title: 'Слишком много запросов',
          description: 'Пожалуйста, подождите немного перед следующей попыткой.',
          technicalDetails: error.toString(),
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return AppFormattedError(
          title: 'Сервер временно недоступен',
          description: 'Ведутся технические работы или сервер перегружен. Попробуйте позже.',
          technicalDetails: error.toString(),
        );
      default:
        if (code == 0) {
          // Client-side network drop or lost connection
          if (msg.contains('closed') || msg.contains('lost') || msg.contains('fail')) {
            return AppFormattedError(
              title: 'Соединение прервано',
              description: 'Связь с сервером была потеряна. Проверяем подключение...',
              technicalDetails: error.toString(),
            );
          }
        }
        return AppFormattedError(
          title: 'Ошибка связи с сервером',
          description: error.message.isNotEmpty ? error.message : 'Попробуйте повторить действие позже.',
          technicalDetails: error.toString(),
        );
    }
  }

  static AppFormattedError _formatStringError(String raw, {String? fallbackTitle}) {
    final String lower = raw.toLowerCase();

    // Check for common network messages embedded in string
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('no address associated with hostname')) {
      return AppFormattedError(
        title: 'Нет подключения к интернету',
        description: 'Проверьте связь Wi-Fi или сотовые данные и повторите попытку.',
        technicalDetails: raw,
      );
    }

    if (lower.contains('timeoutexception') ||
        lower.contains('timed out') ||
        lower.contains('deadline exceeded')) {
      return AppFormattedError(
        title: 'Сервер не ответил вовремя',
        description: 'Пожалуйста, попробуйте снова через пару секунд.',
        technicalDetails: raw,
      );
    }

    if (lower.contains('handshakeexception') ||
        lower.contains('certificate_verify_failed')) {
      return AppFormattedError(
        title: 'Ошибка безопасного соединения',
        description: 'Не удалось проверить сертификат безопасности сервера.',
        technicalDetails: raw,
      );
    }

    if (lower.contains('connection refused') ||
        lower.contains('connection reset by peer') ||
        lower.contains('connection closed')) {
      return AppFormattedError(
        title: 'Соединение с сервером прервано',
        description: 'Сервер временно не отвечает. Повторите попытку через минуту.',
        technicalDetails: raw,
      );
    }

    // Backend slugs matching
    final AppFormattedError? slugError = _matchSlug(lower, technical: raw);
    if (slugError != null) return slugError;

    // Clean up raw prefixes like "Exception: ", "ApiException(0): "
    String cleaned = raw
        .replaceAll(RegExp(r'^Exception:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^ApiException\(\d+\):\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^ClientException:\s*', caseSensitive: false), '')
        .trim();

    if (cleaned.isEmpty) {
      cleaned = fallbackTitle ?? 'Неизвестная ошибка';
    }

    return AppFormattedError(
      title: fallbackTitle ?? cleaned,
      description: fallbackTitle != null ? cleaned : null,
      technicalDetails: raw != cleaned ? raw : null,
    );
  }

  static AppFormattedError? _matchSlug(String lower, {required String technical}) {
    if (lower.contains('user_not_found') || lower.contains('user not found')) {
      return AppFormattedError(
        title: 'Пользователь не найден',
        description: 'Проверьте правильность логина или ID пользователя.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('chat_not_found') || lower.contains('chat not found')) {
      return AppFormattedError(
        title: 'Чат не найден',
        description: 'Возможно, этот чат был удалён или у вас нет к нему доступа.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('channel_not_found')) {
      return AppFormattedError(
        title: 'Канал не найден',
        description: 'Указанный канал не существует или был удалён.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('already_exists') || lower.contains('username already taken')) {
      return AppFormattedError(
        title: 'Уже занято',
        description: 'Это имя пользователя или ресурс уже существует.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('already_member') || lower.contains('already in chat')) {
      return AppFormattedError(
        title: 'Вы уже в этом чате',
        description: 'Вы уже являетесь участником данной группы.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('not_a_member') || lower.contains('not in chat')) {
      return AppFormattedError(
        title: 'Вы не состоите в этом чате',
        description: 'Для выполнения этого действия необходимо вступить в чат.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('session_expired') || lower.contains('token expired')) {
      return AppFormattedError(
        title: 'Сессия устарела',
        description: 'Пожалуйста, войдите в аккаунт заново.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('rate_limit') || lower.contains('too many requests')) {
      return AppFormattedError(
        title: 'Слишком много запросов',
        description: 'Пожалуйста, подождите немного перед следующей попыткой.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('permission_denied') || lower.contains('access denied')) {
      return AppFormattedError(
        title: 'Недостаточно прав',
        description: 'У вас нет разрешения на выполнение этого действия.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('upload_failed') || lower.contains('upload error')) {
      return AppFormattedError(
        title: 'Ошибка отправки файла',
        description: 'Не удалось загрузить файл на сервер. Попробуйте снова.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('invalid_credentials') || lower.contains('invalid password')) {
      return AppFormattedError(
        title: 'Неверные данные для входа',
        description: 'Проверьте введённый логин и пароль.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('message_not_found')) {
      return AppFormattedError(
        title: 'Сообщение не найдено',
        description: 'Возможно, сообщение уже было удалено отправителем.',
        technicalDetails: technical,
      );
    }
    return null;
  }
}
