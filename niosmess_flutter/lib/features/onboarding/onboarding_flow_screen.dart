import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';
import '../../core/settings_provider.dart';
import '../../ui/nios_ui.dart';

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

enum _OnboardingStep {
  welcome,
  introValue,
  introPrivacy,
  introThemes,
  introCalls,
  introSync,
  signupEmail,
  signupName,
  signupPassword,
  signupLegal,
  signupCode,
  loginEmail,
  loginPassword,
  frozen,
  success,
}

enum _MascotMood { idle, happy, sad, thinking, shy, frozen }

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> with TickerProviderStateMixin {
  final api = ApiRepository();

  late final AnimationController _stepController;

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  final _loginCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  _OnboardingStep _step = _OnboardingStep.welcome;
  _MascotMood _mood = _MascotMood.idle;
  String? _frozenReason;
  String _successSubtitle = '';
  Timer? _successTimer;

  bool _showSignupPassword = false;
  bool _showLoginPassword = false;

  final List<_LegalDoc> _legalDocs = const [
    _LegalDoc(id: 'terms', title: 'Условия использования', asset: 'assets/legal/terms.txt'),
    _LegalDoc(id: 'privacy', title: 'Политика конфиденциальности', asset: 'assets/legal/privacy.txt'),
    _LegalDoc(id: 'consent', title: 'Согласие на обработку данных', asset: 'assets/legal/consent.txt'),
  ];
  final Set<String> _legalRead = {};
  bool _legalAccepted = false;

  bool get _allDocsRead => _legalRead.length == _legalDocs.length;

  @override
  void initState() {
    super.initState();
    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      value: 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduceMotion = (ref.read(settingsProvider)['reduce_motion'] as bool?) ?? false;
      if (!reduceMotion) _stepController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    _loginCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _successTimer?.cancel();
    _stepController.dispose();
    super.dispose();
  }

  void _setError(String? value) {
    setState(() {
      _error = value;
      _mood = value == null ? _MascotMood.idle : _MascotMood.sad;
    });
  }

  void _go(_OnboardingStep step, {_MascotMood? mood}) {
    setState(() {
      _step = step;
      _error = null;
      _mood = mood ?? _MascotMood.idle;
    });
    final reduceMotion = (ref.read(settingsProvider)['reduce_motion'] as bool?) ?? false;
    if (reduceMotion) {
      _stepController.value = 1;
    } else {
      _stepController.forward(from: 0);
    }
  }

  void _completeAuth(SessionState session, String subtitle) {
    _successSubtitle = subtitle;
    _go(_OnboardingStep.success, mood: _MascotMood.happy);
    _successTimer?.cancel();
    _successTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      ref.read(sessionProvider.notifier).setSession(session);
    });
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  bool _isValidUsername(String value) {
    return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(value);
  }

  Future<void> _submitSignupEmail() async {
    final email = _emailCtrl.text.trim();
    if (!_isValidEmail(email)) {
      _setError('Введите корректный email');
      return;
    }
    _go(_OnboardingStep.signupName, mood: _MascotMood.happy);
  }

  Future<void> _submitSignupName() async {
    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    if (name.length < 2) {
      _setError('Имя должно быть не менее 2 символов');
      return;
    }
    if (!_isValidUsername(username)) {
      _setError('Username: 3-20 символов, латиница, цифры и _');
      return;
    }
    _go(_OnboardingStep.signupPassword, mood: _MascotMood.shy);
  }

  Future<void> _submitSignupPassword() async {
    final password = _passwordCtrl.text.trim();
    if (password.length < 6) {
      _setError('Пароль должен быть не менее 6 символов');
      return;
    }
    _go(_OnboardingStep.signupLegal, mood: _MascotMood.idle);
  }

  Future<void> _submitSignupLegal() async {
    if (!_allDocsRead) {
      _setError('Откройте и прочитайте все документы');
      return;
    }
    if (!_legalAccepted) {
      _setError('Подтвердите согласие с документами');
      return;
    }
    await _register();
  }

  Future<void> _submitSignupCode() async {
    final code = _codeCtrl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _setError('Код должен состоять из 6 цифр');
      return;
    }
    await _register(code: code);
  }

  Future<void> _register({String? code}) async {
    setState(() => _loading = true);
    try {
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text.trim(),
      };
      if (code != null) payload['code'] = code;
      final res = await api.register(payload);
      if (res['status'] == 'wait_code') {
        _go(_OnboardingStep.signupCode, mood: _MascotMood.thinking);
        return;
      }
      final token = res['token'] ?? res['access_token'];
      if (token != null && token.toString().isNotEmpty) {
        final session = SessionState(
          token: token.toString(),
          username: res['username']?.toString() ?? _usernameCtrl.text.trim(),
          name: res['name']?.toString() ?? _nameCtrl.text.trim(),
        );
        _completeAuth(session, 'Ваш аккаунт успешно создан.');
      } else {
        final loginRes = await api.login(_usernameCtrl.text.trim(), _passwordCtrl.text.trim());
        final session = SessionState(
          token: loginRes['token']?.toString(),
          username: loginRes['username']?.toString(),
          name: loginRes['name']?.toString(),
        );
        if (!session.isAuthed) {
          throw Exception('Не удалось войти после регистрации');
        }
        _completeAuth(session, 'Ваш аккаунт успешно создан.');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      if (e.response?.statusCode == 403 && detail != null && detail.contains('Account frozen')) {
        final reason = detail.split('Account frozen:').last.trim();
        _frozenReason = reason.isEmpty ? 'Аккаунт заморожен' : reason;
        _go(_OnboardingStep.frozen, mood: _MascotMood.frozen);
      } else {
        _setError(detail ?? 'Ошибка регистрации');
      }
    } catch (_) {
      _setError('Ошибка регистрации');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitLoginEmail() async {
    final username = _loginCtrl.text.trim();
    if (username.isEmpty) {
      _setError('Введите имя пользователя');
      return;
    }
    _go(_OnboardingStep.loginPassword, mood: _MascotMood.shy);
  }

  Future<void> _submitLoginPassword() async {
    final password = _loginPasswordCtrl.text.trim();
    if (password.isEmpty) {
      _setError('Введите пароль');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await api.login(_loginCtrl.text.trim(), password);
      final session = SessionState(
        token: res['token']?.toString(),
        username: res['username']?.toString(),
        name: res['name']?.toString(),
      );
      _completeAuth(session, 'С возвращением!');
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      if (e.response?.statusCode == 403 && detail != null && detail.contains('Account frozen')) {
        final reason = detail.split('Account frozen:').last.trim();
        _frozenReason = reason.isEmpty ? 'Аккаунт заморожен' : reason;
        _go(_OnboardingStep.frozen, mood: _MascotMood.frozen);
      } else {
        _setError(detail ?? 'Ошибка входа');
      }
    } catch (_) {
      _setError('Ошибка входа');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetToWelcome() {
    _go(_OnboardingStep.welcome, mood: _MascotMood.happy);
  }

  int _signupIndex() {
    switch (_step) {
      case _OnboardingStep.signupEmail:
        return 0;
      case _OnboardingStep.signupName:
        return 1;
      case _OnboardingStep.signupPassword:
        return 2;
      case _OnboardingStep.signupLegal:
        return 3;
      case _OnboardingStep.signupCode:
        return 4;
      default:
        return 0;
    }
  }

  Widget _stepIndicator(int count, int active) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? scheme.primary : scheme.outlineVariant,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _errorBox() {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _error == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(_error),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
            ),
    );
  }

  Widget _reveal(Widget child, double start, {double offsetY = 0.08}) {
    final reduceMotion = (ref.watch(settingsProvider)['reduce_motion'] as bool?) ?? false;
    if (reduceMotion) return child;
    final animation = CurvedAnimation(
      parent: _stepController,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, offsetY), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildLegalItem(_LegalDoc doc) {
    final read = _legalRead.contains(doc.id);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: read ? scheme.primary : scheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(
          read ? Icons.check_circle : Icons.description_outlined,
          color: read ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(
          read ? 'Прочитано' : 'Не прочитано',
          style: TextStyle(color: read ? scheme.primary : scheme.onSurfaceVariant, fontSize: 12),
        ),
        trailing: TextButton(
          onPressed: () => _openLegalDoc(doc),
          child: Text(read ? 'Прочитано' : 'Отметить'),
        ),
      ),
    );
  }

  Future<void> _openLegalDoc(_LegalDoc doc) async {
    final raw = await rootBundle.loadString(doc.asset);
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (context) {
        bool canAccept = false;
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, controller) {
                return Material(
                  color: scheme.surface,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                doc.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Дальше'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.pixels >=
                                (notification.metrics.maxScrollExtent - 12)) {
                              if (!canAccept) {
                                setStateSheet(() => canAccept = true);
                              }
                            }
                            return false;
                          },
                          child: Markdown(
                            controller: controller,
                            data: raw,
                            styleSheet: MarkdownStyleSheet(
                              p: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                              h1: Theme.of(context).textTheme.titleLarge,
                              h2: Theme.of(context).textTheme.titleMedium,
                              h3: Theme.of(context).textTheme.titleSmall,
                              listBullet: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: canAccept
                                ? () {
                                    setState(() => _legalRead.add(doc.id));
                                    Navigator.pop(context);
                                  }
                                : null,
                            child: const Text('Пропустить'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCard({required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildWelcome() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _reveal(
          Text('NiosMess', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: NiosPalette.text, letterSpacing: -0.5)),
          0.0,
        ),
        const SizedBox(height: 8),
        _reveal(
          Text(
            'Быстрый, приватный, твой',
            style: TextStyle(color: NiosPalette.accent, fontSize: 15, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          0.06,
        ),
        const SizedBox(height: 20),
        _reveal(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _FeatureChip(icon: Icons.lock_outline, label: 'Шифрование'),
              _FeatureChip(icon: Icons.palette_outlined, label: 'Темы'),
              _FeatureChip(icon: Icons.phone_outlined, label: 'Звонки'),
              _FeatureChip(icon: Icons.sync, label: 'Синхронизация'),
            ],
          ),
          0.1,
        ),
        const SizedBox(height: 28),
        _reveal(
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OnboardingPrimaryButton(
                      label: 'Создать аккаунт',
                      icon: Icons.person_add_outlined,
                      onTap: () => _go(_OnboardingStep.signupEmail, mood: _MascotMood.happy),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OnboardingGhostButton(
                      label: 'У меня есть аккаунт',
                      onTap: () => _go(_OnboardingStep.loginEmail, mood: _MascotMood.happy),
                    ),
                  ),
                ],
              ),
            ],
          ),
          0.16,
        ),
      ],
    );
  }

  Widget _buildIntro({
    required String title,
    required String subtitle,
    required IconData icon,
    required _OnboardingStep next,
    _OnboardingStep? back,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        _reveal(
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: scheme.onPrimaryContainer),
          ),
          0.0,
        ),
        const SizedBox(height: 16),
        _reveal(
          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          0.06,
        ),
        const SizedBox(height: 8),
        _reveal(
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          0.1,
        ),
        const SizedBox(height: 24),
        _reveal(
          Row(
            children: [
              if (back != null)
                Expanded(
                  child: OnboardingGhostButton(
                    label: 'Назад',
                    onTap: () => _go(back),
                  ),
                ),
              if (back != null) const SizedBox(width: 12),
              Expanded(
                child: OnboardingPrimaryButton(
                  label: next == _OnboardingStep.signupEmail ? 'Создать аккаунт' : 'Дальше',
                  onTap: () => _go(next, mood: _MascotMood.happy),
                ),
              ),
            ],
          ),
          0.14,
        ),
        if (next != _OnboardingStep.signupEmail) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _go(_OnboardingStep.loginEmail, mood: _MascotMood.happy),
            child: const Text('Уже есть аккаунт'),
          ),
        ],
      ],
    );
  }

  Widget _buildSignupEmail() {
    return Column(
      children: [
        _reveal(_stepIndicator(5, _signupIndex()), 0.0),
        const SizedBox(height: 16),
        _reveal(Text('Создание аккаунта', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: NiosPalette.text)), 0.04),
        const SizedBox(height: 6),
        _reveal(Text('Введите email для регистрации', style: TextStyle(color: NiosPalette.textSecondary)), 0.08),
        const SizedBox(height: 18),
        _reveal(TextField(controller: _emailCtrl, decoration: niosInputDecoration('Email', icon: Icons.alternate_email)), 0.12),
        _reveal(_errorBox(), 0.16),
        const SizedBox(height: 16),
        _reveal(
          Row(
            children: [
              Expanded(child: OnboardingGhostButton(label: 'Назад', onTap: _resetToWelcome)),
              const SizedBox(width: 12),
              Expanded(child: OnboardingPrimaryButton(label: 'Продолжить', onTap: _submitSignupEmail)),
            ],
          ),
          0.2,
        ),
      ],
    );
  }

  Widget _buildSignupName() {
    return Column(
      children: [
        _reveal(_stepIndicator(5, _signupIndex()), 0.0),
        const SizedBox(height: 16),
        _reveal(Text('Ваш профиль', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: NiosPalette.text)), 0.04),
        const SizedBox(height: 6),
        _reveal(Text('Как к вам обращаться?', style: TextStyle(color: NiosPalette.textSecondary)), 0.08),
        const SizedBox(height: 18),
        _reveal(TextField(controller: _nameCtrl, decoration: niosInputDecoration('Имя', icon: Icons.badge_outlined)), 0.12),
        const SizedBox(height: 12),
        _reveal(TextField(controller: _usernameCtrl, decoration: niosInputDecoration('Имя пользователя', icon: Icons.person_outline)), 0.16),
        _reveal(_errorBox(), 0.2),
        const SizedBox(height: 16),
        _reveal(
          Row(
            children: [
              Expanded(child: OnboardingGhostButton(label: 'Назад', onTap: () => _go(_OnboardingStep.signupEmail))),
              const SizedBox(width: 12),
              Expanded(child: OnboardingPrimaryButton(label: 'Продолжить', onTap: _submitSignupName)),
            ],
          ),
          0.24,
        ),
      ],
    );
  }

  Widget _buildSignupPassword() {
    return Column(
      children: [
        _reveal(_stepIndicator(5, _signupIndex()), 0.0),
        const SizedBox(height: 16),
        _reveal(Text('Пароль', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: NiosPalette.text)), 0.04),
        const SizedBox(height: 6),
        _reveal(Text('Придумайте надежный пароль', style: TextStyle(color: NiosPalette.textSecondary)), 0.08),
        const SizedBox(height: 18),
        _reveal(
          TextField(
            controller: _passwordCtrl,
            obscureText: !_showSignupPassword,
            decoration: niosInputDecoration('Пароль', icon: Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                onPressed: () => setState(() => _showSignupPassword = !_showSignupPassword),
                icon: Icon(_showSignupPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: NiosPalette.textSecondary),
              ),
            ),
          ),
          0.12,
        ),
        _reveal(_errorBox(), 0.16),
        const SizedBox(height: 16),
        _reveal(
          Row(
            children: [
              Expanded(child: OnboardingGhostButton(label: 'Назад', onTap: () => _go(_OnboardingStep.signupName))),
              const SizedBox(width: 12),
              Expanded(child: OnboardingPrimaryButton(label: 'Продолжить', onTap: _submitSignupPassword)),
            ],
          ),
          0.2,
        ),
      ],
    );
  }

  Widget _buildSignupLegal() {
    return Column(
      children: [
        _reveal(_stepIndicator(5, _signupIndex()), 0.0),
        const SizedBox(height: 16),
        _reveal(Text('Документы', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: NiosPalette.text)), 0.04),
        const SizedBox(height: 6),
        _reveal(Text('Ознакомьтесь с документами', style: TextStyle(color: NiosPalette.textSecondary)), 0.08),
        const SizedBox(height: 18),
        _reveal(
          Column(children: _legalDocs.map(_buildLegalItem).toList()),
          0.12,
        ),
        _reveal(
          Row(
            children: [
              Checkbox(
                value: _legalAccepted,
                onChanged: _allDocsRead ? (val) => setState(() => _legalAccepted = val ?? false) : null,
              ),
              Expanded(
                child: Text(
                  'Я прочитал(а) документы и согласен(на) с условиями',
                  style: TextStyle(color: NiosPalette.textSecondary),
                ),
              ),
            ],
          ),
          0.18,
        ),
        if (!_allDocsRead)
          _reveal(
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('Откройте и прочитайте все документы', style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
            ),
            0.22,
          ),
        _reveal(_errorBox(), 0.24),
        const SizedBox(height: 16),
        _reveal(
          Row(
            children: [
              Expanded(child: OnboardingGhostButton(label: 'Назад', onTap: () => _go(_OnboardingStep.signupPassword))),
              const SizedBox(width: 12),
              Expanded(
                child: OnboardingPrimaryButton(
                  label: _loading ? 'Отправляем...' : 'Продолжить',
                  onTap: _loading ? null : _submitSignupLegal,
                ),
              ),
            ],
          ),
          0.28,
        ),
      ],
    );
  }

  Widget _buildSignupCode() {
    return Column(
      children: [
        _reveal(_stepIndicator(5, _signupIndex()), 0.0),
        const SizedBox(height: 16),
        _reveal(Text('Код подтверждения', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: NiosPalette.text)), 0.04),
        const SizedBox(height: 6),
        _reveal(Text('Введите код из письма', style: TextStyle(color: NiosPalette.textSecondary)), 0.08),
        const SizedBox(height: 18),
        _reveal(TextField(controller: _codeCtrl, decoration: niosInputDecoration('Код', icon: Icons.verified_outlined)), 0.12),
        _reveal(_errorBox(), 0.16),
        const SizedBox(height: 16),
        _reveal(
          Row(
            children: [
              Expanded(child: OnboardingGhostButton(label: 'Назад', onTap: () => _go(_OnboardingStep.signupLegal))),
              const SizedBox(width: 12),
              Expanded(
                child: OnboardingPrimaryButton(
                  label: _loading ? 'Проверяем...' : 'Подтвердить',
                  onTap: _loading ? null : _submitSignupCode,
                ),
              ),
            ],
          ),
          0.2,
        ),
      ],
    );
  }

  Widget _buildLoginEmail() {
    return Column(
      children: [
        _reveal(Text('Вход', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: NiosPalette.text)), 0.0),
        const SizedBox(height: 6),
        _reveal(Text('Введите имя пользователя', style: TextStyle(color: NiosPalette.textSecondary)), 0.04),
        const SizedBox(height: 18),
        _reveal(TextField(controller: _loginCtrl, decoration: niosInputDecoration('Логин', icon: Icons.person_outline)), 0.08),
        _reveal(_errorBox(), 0.12),
        const SizedBox(height: 16),
        _reveal(
          Row(
            children: [
              Expanded(child: OnboardingGhostButton(label: 'Назад', onTap: _resetToWelcome)),
              const SizedBox(width: 12),
              Expanded(child: OnboardingPrimaryButton(label: 'Продолжить', onTap: _submitLoginEmail)),
            ],
          ),
          0.16,
        ),
      ],
    );
  }

  Widget _buildLoginPassword() {
    return Column(
      children: [
        _reveal(Text('Введите пароль', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: NiosPalette.text)), 0.0),
        const SizedBox(height: 6),
        _reveal(Text('Почти готово', style: TextStyle(color: NiosPalette.textSecondary)), 0.04),
        const SizedBox(height: 18),
        _reveal(
          TextField(
            controller: _loginPasswordCtrl,
            obscureText: !_showLoginPassword,
            decoration: niosInputDecoration('Пароль', icon: Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                onPressed: () => setState(() => _showLoginPassword = !_showLoginPassword),
                icon: Icon(_showLoginPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: NiosPalette.textSecondary),
              ),
            ),
          ),
          0.08,
        ),
        _reveal(
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _openForgotPassword,
              child: Text('Забыли пароль?', style: TextStyle(color: NiosPalette.accent)),
            ),
          ),
          0.12,
        ),
        _reveal(_errorBox(), 0.16),
        const SizedBox(height: 12),
        _reveal(
          Row(
            children: [
              Expanded(child: OnboardingGhostButton(label: 'Назад', onTap: () => _go(_OnboardingStep.loginEmail))),
              const SizedBox(width: 12),
              Expanded(
                child: OnboardingPrimaryButton(
                  label: _loading ? 'Входим...' : 'Войти',
                  onTap: _loading ? null : _submitLoginPassword,
                ),
              ),
            ],
          ),
          0.2,
        ),
      ],
    );
  }

  Widget _buildFrozen() {
    return Column(
      children: [
        _reveal(const Text('❄️', style: TextStyle(fontSize: 48)), 0.0),
        const SizedBox(height: 12),
        _reveal(Text('Аккаунт заморожен', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: NiosPalette.text)), 0.04),
        const SizedBox(height: 8),
        _reveal(
          Text('Ваш аккаунт был заморожен администрацией.', style: TextStyle(color: NiosPalette.textSecondary), textAlign: TextAlign.center),
          0.08,
        ),
        const SizedBox(height: 8),
        _reveal(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NiosPalette.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NiosPalette.border),
            ),
            child: Text('Причина: ${_frozenReason ?? '—'}', style: TextStyle(color: NiosPalette.textSecondary)),
          ),
          0.12,
        ),
        const SizedBox(height: 8),
        _reveal(
          Text('Если это ошибка, обратитесь в поддержку.', style: TextStyle(color: NiosPalette.textSecondary), textAlign: TextAlign.center),
          0.16,
        ),
        const SizedBox(height: 20),
        _reveal(
          OnboardingPrimaryButton(label: 'Назад', onTap: () => _go(_OnboardingStep.loginEmail)),
          0.2,
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        _reveal(const Text('✓', style: TextStyle(fontSize: 48)), 0.0),
        const SizedBox(height: 12),
        _reveal(Text('Добро пожаловать!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: NiosPalette.text)), 0.04),
        const SizedBox(height: 8),
        _reveal(Text(_successSubtitle, style: TextStyle(color: NiosPalette.textSecondary), textAlign: TextAlign.center), 0.08),
        const SizedBox(height: 6),
        _reveal(
          Text('Сейчас мы перенаправим вас в мессенджер...', style: TextStyle(color: NiosPalette.textSecondary), textAlign: TextAlign.center),
          0.12,
        ),
      ],
    );
  }

  void _openForgotPassword() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Безопасный чат',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Мы ценим вашу конфиденциальность. Шифрование и защита включены.',
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Начать'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final reduceMotion = (settings['reduce_motion'] as bool?) ?? false;
    return NiosScaffold(
      body: Stack(
        children: [
          Positioned.fill(child: OnboardingParticles(reduceMotion: reduceMotion)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    FoxMascot(mood: _mood, reduceMotion: reduceMotion),
                    const SizedBox(height: 24),
                    _buildCard(
                      child: AnimatedSize(
                        duration: Duration(milliseconds: reduceMotion ? 0 : 320),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: reduceMotion ? 0 : 320),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (child, animation) {
                            final slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                            final scale = Tween<double>(begin: 0.98, end: 1).animate(
                              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                            );
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(position: slide, child: ScaleTransition(scale: scale, child: child)),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(_step),
                            child: _buildStep(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _OnboardingStep.welcome:
        return _buildWelcome();
      case _OnboardingStep.introValue:
        return _buildIntro(
          title: 'Чат с заботой о вас',
          subtitle: 'Шифрование, контроль видимости, PIN-защита и полный контроль над приватностью.',
          icon: Icons.shield_outlined,
          next: _OnboardingStep.introPrivacy,
          back: _OnboardingStep.welcome,
        );
      case _OnboardingStep.introPrivacy:
        return _buildIntro(
          title: 'Всё под рукой',
          subtitle: 'Темы, звонки, синхронизация — персонализируй мессенджер под себя.',
          icon: Icons.auto_awesome,
          next: _OnboardingStep.signupEmail,
          back: _OnboardingStep.introValue,
        );
      case _OnboardingStep.introThemes:
        return _buildIntro(
          title: 'Всё под рукой',
          subtitle: 'Темы, звонки, синхронизация — персонализируй мессенджер под себя.',
          icon: Icons.auto_awesome,
          next: _OnboardingStep.signupEmail,
          back: _OnboardingStep.introValue,
        );
      case _OnboardingStep.introCalls:
        return _buildIntro(
          title: 'Всё под рукой',
          subtitle: 'Темы, звонки, синхронизация — персонализируй мессенджер под себя.',
          icon: Icons.auto_awesome,
          next: _OnboardingStep.signupEmail,
          back: _OnboardingStep.introValue,
        );
      case _OnboardingStep.introSync:
        return _buildIntro(
          title: 'Всё под рукой',
          subtitle: 'Темы, звонки, синхронизация — персонализируй мессенджер под себя.',
          icon: Icons.auto_awesome,
          next: _OnboardingStep.signupEmail,
          back: _OnboardingStep.introValue,
        );
      case _OnboardingStep.signupEmail:
        return _buildSignupEmail();
      case _OnboardingStep.signupName:
        return _buildSignupName();
      case _OnboardingStep.signupPassword:
        return _buildSignupPassword();
      case _OnboardingStep.signupLegal:
        return _buildSignupLegal();
      case _OnboardingStep.signupCode:
        return _buildSignupCode();
      case _OnboardingStep.loginEmail:
        return _buildLoginEmail();
      case _OnboardingStep.loginPassword:
        return _buildLoginPassword();
      case _OnboardingStep.frozen:
        return _buildFrozen();
      case _OnboardingStep.success:
        return _buildSuccess();
    }
  }
}

class FoxMascot extends StatefulWidget {
  const FoxMascot({super.key, required this.mood, required this.reduceMotion});

  final _MascotMood mood;
  final bool reduceMotion;

  @override
  State<FoxMascot> createState() => _FoxMascotState();
}

class _FoxMascotState extends State<FoxMascot> with TickerProviderStateMixin {
  late final AnimationController _idleController;
  late final AnimationController _moodController;
  late final AnimationController _sparkleController;
  _MascotMood? _lastMood;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _moodController = AnimationController(vsync: this, duration: const Duration(milliseconds: 520), value: 1);
    _sparkleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    if (!widget.reduceMotion) {
      _idleController.repeat();
    }
    _lastMood = widget.mood;
  }

  @override
  void didUpdateWidget(covariant FoxMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion != widget.reduceMotion) {
      if (widget.reduceMotion) {
        _idleController.stop();
      } else {
        _idleController.repeat();
      }
    }
    if (_lastMood != widget.mood) {
      _lastMood = widget.mood;
      if (widget.reduceMotion) {
        _moodController.value = 1;
      } else {
        _moodController.forward(from: 0);
      }
      if (widget.mood == _MascotMood.happy && !widget.reduceMotion) {
        _sparkleController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _moodController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idleController, _moodController, _sparkleController]),
      builder: (context, _) {
        final t = _idleController.value * 2 * pi;
        final reduce = widget.reduceMotion;
        final floatY = reduce ? 0.0 : 10 * sin(t);
        final headTilt = reduce ? 0.0 : 0.04 * sin(t * 0.8);
        final earWiggle = reduce ? 0.0 : 0.12 * sin(t * 1.1);
        final blink = reduce ? 1.0 : (sin(t * 0.5) > 0.97 ? 0.1 : 1.0);
        final moodT = Curves.easeOutBack.transform(_moodController.value);
        final pupilShift = widget.mood == _MascotMood.thinking && !reduce ? 4 * sin(t * 0.7) : 0.0;

        double scale = 1.0;
        double offsetX = 0.0;
        double offsetY = 0.0;
        if (widget.mood == _MascotMood.happy) {
          scale = 1 + 0.08 * moodT;
          offsetY = -8 * moodT;
        } else if (widget.mood == _MascotMood.shy) {
          offsetX = reduce ? 0.0 : 4 * sin(moodT * 2 * pi);
        } else if (widget.mood == _MascotMood.sad) {
          offsetY = 6 * moodT;
        } else if (widget.mood == _MascotMood.frozen) {
          offsetX = reduce ? 0.0 : 2 * sin(t * 8);
          offsetY = reduce ? 0.0 : 2 * sin(t * 10);
        }

        return Transform.translate(
          offset: Offset(offsetX, floatY + offsetY),
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: headTilt,
              child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (widget.mood == _MascotMood.happy) _sparkles(),
                    Positioned(
                      top: 35,
                      left: 35,
                      child: _FoxHead(
                        mood: widget.mood,
                        blink: blink,
                        pupilShift: pupilShift,
                        earWiggle: earWiggle,
                        blush: reduce ? 0.0 : (0.4 + 0.3 * sin(t * 1.6)),
                        sparkleT: _sparkleController.value,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sparkles() {
    final t = Curves.easeOut.transform(_sparkleController.value);
    final opacity = (1 - t).clamp(0.0, 1.0);
    final scale = 0.6 + 0.8 * (1 - t);
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: const Stack(
              children: [
                _Sparkle(top: -10, left: -10),
                _Sparkle(top: -10, right: -10),
                _Sparkle(top: 90, right: -15),
                _Sparkle(bottom: -10, right: -10),
                _Sparkle(bottom: -10, left: -10),
                _Sparkle(top: 90, left: -15),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoxHead extends StatelessWidget {
  const _FoxHead({
    required this.mood,
    required this.blink,
    required this.pupilShift,
    required this.earWiggle,
    required this.blush,
    required this.sparkleT,
  });

  final _MascotMood mood;
  final double blink;
  final double pupilShift;
  final double earWiggle;
  final double blush;
  final double sparkleT;

  @override
  Widget build(BuildContext context) {
    final happy = mood == _MascotMood.happy;
    final shy = mood == _MascotMood.shy;
    final sad = mood == _MascotMood.sad || mood == _MascotMood.frozen;

    double mouthW = 45;
    double mouthH = 22;
    if (happy) {
      mouthW = 60 - 8 * sparkleT;
      mouthH = 30 - 4 * sparkleT;
    } else if (sad) {
      mouthW = 40;
      mouthH = 18;
    }

    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]),
              borderRadius: BorderRadius.circular(65),
              boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))],
            ),
          ),
          _FoxEar(left: true, wiggle: earWiggle),
          _FoxEar(left: false, wiggle: -earWiggle),
          Positioned(
            top: 38,
            left: (130 - 75) / 2,
            child: _FoxEyes(
              blink: blink,
              shy: shy,
              pupilShift: pupilShift,
            ),
          ),
          Positioned(
            top: 80,
            left: (130 - 18) / 2,
            child: _FoxNose(),
          ),
          Positioned(
            top: 100,
            left: (130 - mouthW) / 2,
            child: _FoxMouth(width: mouthW, height: mouthH, sad: sad),
          ),
          _FoxCheek(
            left: 15,
            opacity: (happy || shy) ? blush : 0,
          ),
          _FoxCheek(
            right: 15,
            opacity: (happy || shy) ? blush : 0,
          ),
          if (mood == _MascotMood.frozen)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(65),
                    gradient: const LinearGradient(
                      colors: [Color.fromRGBO(126, 205, 255, 0.28), Color.fromRGBO(126, 205, 255, 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FoxEar extends StatelessWidget {
  const _FoxEar({required this.left, required this.wiggle});

  final bool left;
  final double wiggle;

  @override
  Widget build(BuildContext context) {
    final angle = (left ? -0.12 : 0.12) + wiggle;
    return Positioned(
      top: -28,
      left: left ? 8 : null,
      right: left ? null : 8,
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 45,
          height: 65,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(left ? 36 : 12),
              topRight: Radius.circular(left ? 12 : 36),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: 22,
              height: 32,
              margin: const EdgeInsets.only(top: 10, left: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFC09F), Color(0xFFFFB88C)]),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(left ? 26 : 8),
                  topRight: Radius.circular(left ? 8 : 26),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoxEyes extends StatelessWidget {
  const _FoxEyes({required this.blink, required this.shy, required this.pupilShift});

  final double blink;
  final bool shy;
  final double pupilShift;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 75,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _FoxEye(blink: blink, shy: shy, pupilShift: pupilShift),
          _FoxEye(blink: blink, shy: shy, pupilShift: pupilShift),
        ],
      ),
    );
  }
}

class _FoxEye extends StatelessWidget {
  const _FoxEye({required this.blink, required this.shy, required this.pupilShift});

  final double blink;
  final bool shy;
  final double pupilShift;

  @override
  Widget build(BuildContext context) {
    if (shy) {
      return Container(
        width: 30,
        height: 4,
        decoration: BoxDecoration(color: const Color(0xFFFF8C5A), borderRadius: BorderRadius.circular(6)),
      );
    }
    return Transform.scale(
      scaleY: blink,
      alignment: Alignment.center,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 7,
              left: 8,
              child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            ),
            Positioned(
              left: 7 + pupilShift,
              top: 7,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2, offset: const Offset(0, 1))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoxNose extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 14,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)]),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _FoxMouth extends StatelessWidget {
  const _FoxMouth({required this.width, required this.height, required this.sad});

  final double width;
  final double height;
  final bool sad;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border(
          top: sad ? const BorderSide(color: Color(0xFF1A1A1A), width: 3) : BorderSide.none,
          bottom: sad ? BorderSide.none : const BorderSide(color: Color(0xFF1A1A1A), width: 3),
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: sad ? const Radius.circular(0) : const Radius.circular(40),
          bottomRight: sad ? const Radius.circular(0) : const Radius.circular(40),
          topLeft: sad ? const Radius.circular(40) : Radius.zero,
          topRight: sad ? const Radius.circular(40) : Radius.zero,
        ),
      ),
    );
  }
}

class _FoxCheek extends StatelessWidget {
  const _FoxCheek({this.left, this.right, required this.opacity});

  final double? left;
  final double? right;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 35,
      left: left,
      right: right,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 20,
          height: 15,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withValues(alpha: 0.4), blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({this.top, this.left, this.right, this.bottom});

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: const Text('✨', style: TextStyle(fontSize: 16)),
    );
  }
}

class OnboardingParticles extends StatefulWidget {
  const OnboardingParticles({super.key, required this.reduceMotion});

  final bool reduceMotion;

  @override
  State<OnboardingParticles> createState() => _OnboardingParticlesState();
}

class _OnboardingParticlesState extends State<OnboardingParticles> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20));
    if (!widget.reduceMotion) {
      _controller.repeat();
    }
    final rand = Random(7);
    _particles = List.generate(24, (i) {
      return _Particle(
        x: rand.nextDouble(),
        y: rand.nextDouble(),
        radius: 2 + rand.nextDouble() * 3,
        speed: 0.12 + rand.nextDouble() * 0.2,
        drift: 8 + rand.nextDouble() * 20,
        phase: rand.nextDouble() * 2 * pi,
        opacity: 0.18 + rand.nextDouble() * 0.22,
      );
    });
  }

  @override
  void didUpdateWidget(covariant OnboardingParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion != widget.reduceMotion) {
      if (widget.reduceMotion) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.reduceMotion ? 0.0 : _controller.value;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => SizedBox.expand(
          child: CustomPaint(
            painter: _ParticlesPainter(
              particles: _particles,
              t: t,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.drift,
    required this.phase,
    required this.opacity,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double drift;
  final double phase;
  final double opacity;
}

class _ParticlesPainter extends CustomPainter {
  _ParticlesPainter({required this.particles, required this.t, required this.color});

  final List<_Particle> particles;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final progress = (p.y - t * p.speed) % 1.0;
      final y = size.height * (1 - progress);
      final x = size.width * p.x + sin((t * 2 * pi) + p.phase) * p.drift;
      paint.color = color.withValues(alpha: p.opacity);
      canvas.drawCircle(Offset(x, y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) => oldDelegate.t != t || oldDelegate.color != color;
}

class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = loading || onTap == null;
    return FilledButton(
      onPressed: disabled ? null : onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
            ),
            const SizedBox(width: 12),
          ] else if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class OnboardingGhostButton extends StatelessWidget {
  const OnboardingGhostButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _LegalDoc {
  const _LegalDoc({required this.id, required this.title, required this.asset});
  final String id;
  final String title;
  final String asset;
}
