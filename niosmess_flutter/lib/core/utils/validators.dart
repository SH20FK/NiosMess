/// Валидаторы для форм и полей ввода
class Validators {
  /// Проверка email
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email не может быть пустым';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Введите корректный email';
    }

    return null;
  }

  /// Проверка username
  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Имя пользователя не может быть пустым';
    }

    if (value.length < 3) {
      return 'Минимум 3 символа';
    }

    if (value.length > 20) {
      return 'Максимум 20 символов';
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value)) {
      return 'Только буквы, цифры и подчёркивание';
    }

    return null;
  }

  /// Проверка пароля
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Пароль не может быть пустым';
    }

    if (value.length < 8) {
      return 'Минимум 8 символов';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Нужна хотя бы одна заглавная буква';
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Нужна хотя бы одна строчная буква';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Нужна хотя бы одна цифра';
    }

    return null;
  }

  /// Проверка имени
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Имя не может быть пустым';
    }

    if (value.trim().length < 2) {
      return 'Минимум 2 символа';
    }

    if (value.trim().length > 50) {
      return 'Максимум 50 символов';
    }

    return null;
  }

  /// Проверка PIN-кода
  static String? pin(String? value) {
    if (value == null || value.isEmpty) {
      return 'PIN не может быть пустым';
    }

    if (value.length != 4 && value.length != 6) {
      return 'PIN должен быть 4 или 6 цифр';
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'PIN может содержать только цифры';
    }

    // Проверка на простые PIN-коды
    final weakPins = ['0000', '1111', '1234', '000000', '111111', '123456'];
    if (weakPins.contains(value)) {
      return 'Слишком простой PIN';
    }

    return null;
  }

  /// Проверка текста сообщения
  static String? message(String? value, {int maxLength = 4000}) {
    if (value == null || value.trim().isEmpty) {
      return 'Сообщение не может быть пустым';
    }

    if (value.length > maxLength) {
      return 'Максимум $maxLength символов';
    }

    return null;
  }

  /// Проверка номера телефона
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Телефон необязателен
    }

    // Удаляем все кроме цифр и +
    final cleaned = value.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.length < 10) {
      return 'Некорректный номер телефона';
    }

    return null;
  }

  /// Проверка URL
  static String? url(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return 'URL должен начинаться с http:// или https://';
      }
      return null;
    } catch (e) {
      return 'Некорректный URL';
    }
  }

  /// Проверка совпадения паролей
  static String? passwordMatch(String? value, String? password) {
    if (value != password) {
      return 'Пароли не совпадают';
    }
    return null;
  }

  /// Общая проверка на пустоту
  static String? required(String? value, {String fieldName = 'Поле'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName не может быть пустым';
    }
    return null;
  }

  /// Проверка минимальной длины
  static String? minLength(String? value, int min, {String fieldName = 'Значение'}) {
    if (value == null || value.length < min) {
      return '$fieldName должно быть минимум $min символов';
    }
    return null;
  }

  /// Проверка максимальной длины
  static String? maxLength(String? value, int max, {String fieldName = 'Значение'}) {
    if (value != null && value.length > max) {
      return '$fieldName должно быть максимум $max символов';
    }
    return null;
  }

  /// Комбинированный валидатор
  static String? Function(String?) combine(
    List<String? Function(String?)> validators,
  ) {
    return (value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}
