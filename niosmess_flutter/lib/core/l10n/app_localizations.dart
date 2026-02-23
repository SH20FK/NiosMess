import 'package:flutter/material.dart';

/// Локализация приложения
/// Поддерживает русский и английский языки
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ru', 'RU'), // Русский
    Locale('en', 'US'), // Английский
  ];

  // Общие
  String get appName => _get('app_name');
  String get ok => _get('ok');
  String get cancel => _get('cancel');
  String get save => _get('save');
  String get delete => _get('delete');
  String get edit => _get('edit');
  String get search => _get('search');
  String get send => _get('send');
  String get loading => _get('loading');
  String get error => _get('error');
  String get retry => _get('retry');
  String get yes => _get('yes');
  String get no => _get('no');

  // Авторизация
  String get login => _get('login');
  String get register => _get('register');
  String get logout => _get('logout');
  String get username => _get('username');
  String get password => _get('password');
  String get email => _get('email');
  String get name => _get('name');
  String get forgotPassword => _get('forgot_password');
  String get dontHaveAccount => _get('dont_have_account');
  String get alreadyHaveAccount => _get('already_have_account');

  // Чаты
  String get chats => _get('chats');
  String get messages => _get('messages');
  String get newMessage => _get('new_message');
  String get typeMessage => _get('type_message');
  String get noMessages => _get('no_messages');
  String get today => _get('today');
  String get yesterday => _get('yesterday');
  String get online => _get('online');
  String get offline => _get('offline');
  String get typing => _get('typing');
  String get lastSeen => _get('last_seen');

  // Группы
  String get groups => _get('groups');
  String get createGroup => _get('create_group');
  String get groupName => _get('group_name');
  String get members => _get('members');
  String get addMembers => _get('add_members');
  String get removeMembers => _get('remove_members');

  // Профиль
  String get profile => _get('profile');
  String get editProfile => _get('edit_profile');
  String get changeAvatar => _get('change_avatar');
  String get about => _get('about');
  String get phone => _get('phone');

  // Настройки
  String get settings => _get('settings');
  String get account => _get('account');
  String get privacy => _get('privacy');
  String get notifications => _get('notifications');
  String get theme => _get('theme');
  String get language => _get('language');
  String get dataAndStorage => _get('data_and_storage');
  String get help => _get('help');

  // Темы
  String get darkTheme => _get('dark_theme');
  String get lightTheme => _get('light_theme');
  String get systemTheme => _get('system_theme');

  // Уведомления
  String get enableNotifications => _get('enable_notifications');
  String get disableNotifications => _get('disable_notifications');
  String get sound => _get('sound');
  String get vibration => _get('vibration');

  // Медиа
  String get camera => _get('camera');
  String get gallery => _get('gallery');
  String get photo => _get('photo');
  String get video => _get('video');
  String get file => _get('file');
  String get location => _get('location');

  // Stories
  String get stories => _get('stories');
  String get yourStory => _get('your_story');
  String get addStory => _get('add_story');
  String get viewStory => _get('view_story');
  String get deleteStory => _get('delete_story');

  // Ошибки
  String get errorOccurred => _get('error_occurred');
  String get noInternet => _get('no_internet');
  String get serverError => _get('server_error');
  String get unauthorized => _get('unauthorized');
  String get forbidden => _get('forbidden');
  String get notFound => _get('not_found');

  // Валидация
  String get fieldRequired => _get('field_required');
  String get invalidEmail => _get('invalid_email');
  String get passwordTooShort => _get('password_too_short');
  String get passwordsDoNotMatch => _get('passwords_do_not_match');
  String get usernameTooShort => _get('username_too_short');

  // Временные метки
  String get justNow => _get('just_now');
  String get minutesAgo => _get('minutes_ago');
  String get hoursAgo => _get('hours_ago');
  String get daysAgo => _get('days_ago');

  String _get(String key) {
    final translations = _translations[locale.languageCode] ?? _translations['ru']!;
    return translations[key] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    'ru': {
      // Общие
      'app_name': 'NiosMess',
      'ok': 'OK',
      'cancel': 'Отмена',
      'save': 'Сохранить',
      'delete': 'Удалить',
      'edit': 'Редактировать',
      'search': 'Поиск',
      'send': 'Отправить',
      'loading': 'Загрузка...',
      'error': 'Ошибка',
      'retry': 'Повторить',
      'yes': 'Да',
      'no': 'Нет',

      // Авторизация
      'login': 'Вход',
      'register': 'Регистрация',
      'logout': 'Выход',
      'username': 'Имя пользователя',
      'password': 'Пароль',
      'email': 'Email',
      'name': 'Имя',
      'forgot_password': 'Забыли пароль?',
      'dont_have_account': 'Нет аккаунта?',
      'already_have_account': 'Уже есть аккаунт?',

      // Чаты
      'chats': 'Чаты',
      'messages': 'Сообщения',
      'new_message': 'Новое сообщение',
      'type_message': 'Введите сообщение...',
      'no_messages': 'Нет сообщений',
      'today': 'Сегодня',
      'yesterday': 'Вчера',
      'online': 'В сети',
      'offline': 'Не в сети',
      'typing': 'печатает...',
      'last_seen': 'был(а) в сети',

      // Группы
      'groups': 'Группы',
      'create_group': 'Создать группу',
      'group_name': 'Название группы',
      'members': 'Участники',
      'add_members': 'Добавить участников',
      'remove_members': 'Удалить участников',

      // Профиль
      'profile': 'Профиль',
      'edit_profile': 'Редактировать профиль',
      'change_avatar': 'Изменить аватар',
      'about': 'О себе',
      'phone': 'Телефон',

      // Настройки
      'settings': 'Настройки',
      'account': 'Аккаунт',
      'privacy': 'Конфиденциальность',
      'notifications': 'Уведомления',
      'theme': 'Тема',
      'language': 'Язык',
      'data_and_storage': 'Данные и хранилище',
      'help': 'Помощь',

      // Темы
      'dark_theme': 'Тёмная тема',
      'light_theme': 'Светлая тема',
      'system_theme': 'Системная тема',

      // Уведомления
      'enable_notifications': 'Включить уведомления',
      'disable_notifications': 'Выключить уведомления',
      'sound': 'Звук',
      'vibration': 'Вибрация',

      // Медиа
      'camera': 'Камера',
      'gallery': 'Галерея',
      'photo': 'Фото',
      'video': 'Видео',
      'file': 'Файл',
      'location': 'Местоположение',

      // Stories
      'stories': 'Истории',
      'your_story': 'Ваша история',
      'add_story': 'Добавить историю',
      'view_story': 'Просмотреть историю',
      'delete_story': 'Удалить историю',

      // Ошибки
      'error_occurred': 'Произошла ошибка',
      'no_internet': 'Нет подключения к интернету',
      'server_error': 'Ошибка сервера',
      'unauthorized': 'Необходима авторизация',
      'forbidden': 'Доступ запрещён',
      'not_found': 'Не найдено',

      // Валидация
      'field_required': 'Поле обязательно',
      'invalid_email': 'Некорректный email',
      'password_too_short': 'Пароль слишком короткий',
      'passwords_do_not_match': 'Пароли не совпадают',
      'username_too_short': 'Имя слишком короткое',

      // Временные метки
      'just_now': 'только что',
      'minutes_ago': 'мин назад',
      'hours_ago': 'ч назад',
      'days_ago': 'дн назад',
    },
    'en': {
      // Common
      'app_name': 'NiosMess',
      'ok': 'OK',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'search': 'Search',
      'send': 'Send',
      'loading': 'Loading...',
      'error': 'Error',
      'retry': 'Retry',
      'yes': 'Yes',
      'no': 'No',

      // Auth
      'login': 'Login',
      'register': 'Register',
      'logout': 'Logout',
      'username': 'Username',
      'password': 'Password',
      'email': 'Email',
      'name': 'Name',
      'forgot_password': 'Forgot password?',
      'dont_have_account': "Don't have an account?",
      'already_have_account': 'Already have an account?',

      // Chats
      'chats': 'Chats',
      'messages': 'Messages',
      'new_message': 'New message',
      'type_message': 'Type a message...',
      'no_messages': 'No messages',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'online': 'Online',
      'offline': 'Offline',
      'typing': 'typing...',
      'last_seen': 'last seen',

      // Groups
      'groups': 'Groups',
      'create_group': 'Create group',
      'group_name': 'Group name',
      'members': 'Members',
      'add_members': 'Add members',
      'remove_members': 'Remove members',

      // Profile
      'profile': 'Profile',
      'edit_profile': 'Edit profile',
      'change_avatar': 'Change avatar',
      'about': 'About',
      'phone': 'Phone',

      // Settings
      'settings': 'Settings',
      'account': 'Account',
      'privacy': 'Privacy',
      'notifications': 'Notifications',
      'theme': 'Theme',
      'language': 'Language',
      'data_and_storage': 'Data and storage',
      'help': 'Help',

      // Themes
      'dark_theme': 'Dark theme',
      'light_theme': 'Light theme',
      'system_theme': 'System theme',

      // Notifications
      'enable_notifications': 'Enable notifications',
      'disable_notifications': 'Disable notifications',
      'sound': 'Sound',
      'vibration': 'Vibration',

      // Media
      'camera': 'Camera',
      'gallery': 'Gallery',
      'photo': 'Photo',
      'video': 'Video',
      'file': 'File',
      'location': 'Location',

      // Stories
      'stories': 'Stories',
      'your_story': 'Your story',
      'add_story': 'Add story',
      'view_story': 'View story',
      'delete_story': 'Delete story',

      // Errors
      'error_occurred': 'An error occurred',
      'no_internet': 'No internet connection',
      'server_error': 'Server error',
      'unauthorized': 'Unauthorized',
      'forbidden': 'Forbidden',
      'not_found': 'Not found',

      // Validation
      'field_required': 'Field is required',
      'invalid_email': 'Invalid email',
      'password_too_short': 'Password is too short',
      'passwords_do_not_match': 'Passwords do not match',
      'username_too_short': 'Username is too short',

      // Timestamps
      'just_now': 'just now',
      'minutes_ago': 'min ago',
      'hours_ago': 'h ago',
      'days_ago': 'd ago',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ru', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
