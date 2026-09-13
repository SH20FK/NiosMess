import 'dart:async';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:universal_io/io.dart';

/// Formatted, user-friendly error representation.
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
/// and backend error slugs into clear, localized messages.
class AppErrorFormatter {
  AppErrorFormatter._();

  static AppFormattedError format(
    dynamic error, {
    String? fallbackTitle,
    AppLocalizations? l10n,
  }) {
    if (error == null) {
      return AppFormattedError(
        title: fallbackTitle ?? (l10n?.errorUnknown ?? 'Произошла непредвиденная ошибка'),
        description: l10n?.errorTryAgainLater ?? 'Пожалуйста, попробуйте позже',
      );
    }

    if (error is AppFormattedError) {
      return error;
    }

    // 1. SocketException / Network offline
    if (error is SocketException) {
      return AppFormattedError(
        title: l10n?.errorNoInternet ?? 'Нет подключения к интернету',
        description: l10n?.errorNoInternetDesc ??
            'Проверьте сеть Wi-Fi или сотовые данные и повторите попытку.',
        technicalDetails: error.toString(),
      );
    }

    // 2. TimeoutException
    if (error is TimeoutException) {
      return AppFormattedError(
        title: l10n?.errorServerTimeout ?? 'Сервер не ответил вовремя',
        description: l10n?.errorServerTimeoutDesc ??
            'Соединение заняло слишком много времени. Попробуйте ещё раз.',
        technicalDetails: error.toString(),
      );
    }

    // 3. HandshakeException / SSL errors
    if (error is HandshakeException) {
      return AppFormattedError(
        title: l10n?.errorTlsHandshake ?? 'Ошибка защищённого соединения',
        description: l10n?.errorTlsHandshakeDesc ??
            'Не удалось установить безопасный канал связи с сервером.',
        technicalDetails: error.toString(),
      );
    }

    // 4. ApiException
    if (error is ApiException) {
      return _formatApiException(error, l10n: l10n);
    }

    // 5. String-based error analysis
    final String raw = error.toString().trim();
    return _formatStringError(raw, fallbackTitle: fallbackTitle, l10n: l10n);
  }

  static AppFormattedError _formatApiException(
    ApiException error, {
    AppLocalizations? l10n,
  }) {
    final int code = error.statusCode;
    final String msg = error.message.trim().toLowerCase();

    // Specific backend slug matching
    final AppFormattedError? slugError =
        _matchSlug(msg, technical: error.toString(), l10n: l10n);
    if (slugError != null) return slugError;

    switch (code) {
      case 400:
        return AppFormattedError(
          title: l10n?.errorUnknown ?? 'Некорректный запрос',
          description: l10n?.errorServerCommunication ??
              'Проверьте введённые данные и попробуйте снова.',
          technicalDetails: error.toString(),
        );
      case 401:
        return AppFormattedError(
          title: l10n?.errorSessionExpired ?? 'Сессия устарела',
          description: l10n?.errorSessionExpiredDesc ??
              'Пожалуйста, войдите в аккаунт заново.',
          technicalDetails: error.toString(),
        );
      case 403:
        return AppFormattedError(
          title: l10n?.errorPermissionDenied ?? 'Доступ ограничен',
          description: l10n?.errorPermissionDeniedDesc ??
              'У вас недостаточно прав для выполнения этого действия.',
          technicalDetails: error.toString(),
        );
      case 404:
        return AppFormattedError(
          title: l10n?.errorChatNotFound ?? 'Не найдено',
          description: l10n?.errorChatNotFoundDesc ??
              'Запрашиваемый чат, сообщение или ресурс не существуют.',
          technicalDetails: error.toString(),
        );
      case 409:
        return AppFormattedError(
          title: l10n?.errorAlreadyTaken ?? 'Конфликт данных',
          description: l10n?.errorAlreadyTakenDesc ??
              'Такая запись или имя пользователя уже занято.',
          technicalDetails: error.toString(),
        );
      case 413:
        return AppFormattedError(
          title: l10n?.errorFileUploadFailed ?? 'Файл слишком большой',
          description: l10n?.errorFileUploadFailedDesc ??
              'Размер выбранного файла превышает допустимый лимит.',
          technicalDetails: error.toString(),
        );
      case 429:
        return AppFormattedError(
          title: l10n?.errorRateLimited ?? 'Слишком много запросов',
          description: l10n?.errorRateLimitedDesc ??
              'Пожалуйста, подождите немного перед следующей попыткой.',
          technicalDetails: error.toString(),
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return AppFormattedError(
          title: l10n?.errorServerUnavailable ?? 'Сервер временно недоступен',
          description: l10n?.errorServerUnavailableDesc ??
              'Ведутся технические работы или сервер перегружен. Попробуйте позже.',
          technicalDetails: error.toString(),
        );
      default:
        if (code == 0) {
          // Client-side network drop or lost connection
          if (msg.contains('closed') || msg.contains('lost') || msg.contains('fail')) {
            return AppFormattedError(
              title: l10n?.errorConnectionLost ?? 'Соединение прервано',
              description: l10n?.errorConnectionLostDesc ??
                  'Связь с сервером была потеряна. Проверяем подключение...',
              technicalDetails: error.toString(),
            );
          }
        }
        return AppFormattedError(
          title: l10n?.errorServerCommunication ?? 'Ошибка связи с сервером',
          description: error.message.isNotEmpty
              ? error.message
              : (l10n?.errorTryAgainLater ?? 'Попробуйте повторить действие позже.'),
          technicalDetails: error.toString(),
        );
    }
  }

  static AppFormattedError _formatStringError(
    String raw, {
    String? fallbackTitle,
    AppLocalizations? l10n,
  }) {
    final String lower = raw.toLowerCase();

    // Check for common network messages embedded in string
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('no address associated with hostname')) {
      return AppFormattedError(
        title: l10n?.errorNoInternet ?? 'Нет подключения к интернету',
        description: l10n?.errorNoInternetDesc ??
            'Проверьте связь Wi-Fi или сотовые данные и повторите попытку.',
        technicalDetails: raw,
      );
    }

    if (lower.contains('timeoutexception') ||
        lower.contains('timed out') ||
        lower.contains('deadline exceeded')) {
      return AppFormattedError(
        title: l10n?.errorServerTimeout ?? 'Сервер не ответил вовремя',
        description: l10n?.errorServerTimeoutDesc ??
            'Пожалуйста, попробуйте снова через пару секунд.',
        technicalDetails: raw,
      );
    }

    if (lower.contains('handshakeexception') ||
        lower.contains('certificate_verify_failed')) {
      return AppFormattedError(
        title: l10n?.errorTlsHandshake ?? 'Ошибка безопасного соединения',
        description: l10n?.errorTlsHandshakeDesc ??
            'Не удалось проверить сертификат безопасности сервера.',
        technicalDetails: raw,
      );
    }

    if (lower.contains('connection refused') ||
        lower.contains('connection reset by peer') ||
        lower.contains('connection closed')) {
      return AppFormattedError(
        title: l10n?.errorServerReset ?? 'Соединение с сервером прервано',
        description: l10n?.errorServerResetDesc ??
            'Сервер временно не отвечает. Повторите попытку через минуту.',
        technicalDetails: raw,
      );
    }

    // Backend slugs matching
    final AppFormattedError? slugError =
        _matchSlug(lower, technical: raw, l10n: l10n);
    if (slugError != null) return slugError;

    // Clean up raw prefixes like "Exception: ", "ApiException(0): "
    String cleaned = raw
        .replaceAll(RegExp(r'^Exception:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^ApiException\(\d+\):\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^ClientException:\s*', caseSensitive: false), '')
        .trim();

    if (cleaned.isEmpty) {
      cleaned = fallbackTitle ?? (l10n?.errorUnknown ?? 'Неизвестная ошибка');
    }

    return AppFormattedError(
      title: fallbackTitle ?? cleaned,
      description: fallbackTitle != null ? cleaned : null,
      technicalDetails: raw != cleaned ? raw : null,
    );
  }

  static AppFormattedError? _matchSlug(
    String lower, {
    required String technical,
    AppLocalizations? l10n,
  }) {
    if (lower.contains('user_not_found') || lower.contains('user not found')) {
      return AppFormattedError(
        title: l10n?.errorUserNotFound ?? 'Пользователь не найден',
        description: l10n?.errorUserNotFoundDesc ??
            'Проверьте правильность логина или ID пользователя.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('chat_not_found') || lower.contains('chat not found')) {
      return AppFormattedError(
        title: l10n?.errorChatNotFound ?? 'Чат не найден',
        description: l10n?.errorChatNotFoundDesc ??
            'Возможно, этот чат был удалён или у вас нет к нему доступа.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('channel_not_found')) {
      return AppFormattedError(
        title: l10n?.errorChannelNotFound ?? 'Канал не найден',
        description: l10n?.errorChannelNotFoundDesc ??
            'Указанный канал не существует или был удалён.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('already_exists') || lower.contains('username already taken')) {
      return AppFormattedError(
        title: l10n?.errorAlreadyTaken ?? 'Уже занято',
        description: l10n?.errorAlreadyTakenDesc ??
            'Это имя пользователя или ресурс уже существует.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('already_member') || lower.contains('already in chat')) {
      return AppFormattedError(
        title: l10n?.errorAlreadyInChat ?? 'Вы уже в этом чате',
        description: l10n?.errorAlreadyInChatDesc ??
            'Вы уже являетесь участником данной группы.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('not_a_member') || lower.contains('not in chat')) {
      return AppFormattedError(
        title: l10n?.errorNotInChat ?? 'Вы не состоите в этом чате',
        description: l10n?.errorNotInChatDesc ??
            'Для выполнения этого действия необходимо вступить в чат.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('session_expired') || lower.contains('token expired')) {
      return AppFormattedError(
        title: l10n?.errorSessionExpired ?? 'Сессия устарела',
        description: l10n?.errorSessionExpiredDesc ??
            'Пожалуйста, войдите в аккаунт заново.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('rate_limit') || lower.contains('too many requests')) {
      return AppFormattedError(
        title: l10n?.errorRateLimited ?? 'Слишком много запросов',
        description: l10n?.errorRateLimitedDesc ??
            'Пожалуйста, подождите немного перед следующей попыткой.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('permission_denied') || lower.contains('access denied')) {
      return AppFormattedError(
        title: l10n?.errorPermissionDenied ?? 'Недостаточно прав',
        description: l10n?.errorPermissionDeniedDesc ??
            'У вас нет разрешения на выполнение этого действия.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('upload_failed') || lower.contains('upload error')) {
      return AppFormattedError(
        title: l10n?.errorFileUploadFailed ?? 'Ошибка отправки файла',
        description: l10n?.errorFileUploadFailedDesc ??
            'Не удалось загрузить файл на сервер. Попробуйте снова.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('invalid_credentials') || lower.contains('invalid password')) {
      return AppFormattedError(
        title: l10n?.errorInvalidCredentials ?? 'Неверные данные для входа',
        description: l10n?.errorInvalidCredentialsDesc ??
            'Проверьте введённый логин и пароль.',
        technicalDetails: technical,
      );
    }
    if (lower.contains('message_not_found')) {
      return AppFormattedError(
        title: l10n?.errorFileNotFound ?? 'Сообщение не найдено',
        description: l10n?.errorFileNotFoundDesc ??
            'Возможно, сообщение уже было удалено отправителем.',
        technicalDetails: technical,
      );
    }
    return null;
  }
}
