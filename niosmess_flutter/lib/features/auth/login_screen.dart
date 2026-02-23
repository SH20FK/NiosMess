import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';
import '../../core/utils/error_handler.dart';
import '../../ui/nios_ui.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    required this.onRegister,
    required this.onFrozen,
    required this.onBack,
  });

  final VoidCallback onRegister;
  final void Function(String reason) onFrozen;
  final VoidCallback onBack;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool loading = false;
  bool showPassword = false;
  String? error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Валидация формы
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiRepository();
      final res = await api.login(
        _username.text.trim(),
        _password.text.trim(),
      );

      final session = SessionState(
        token: res['token']?.toString(),
        username: res['username']?.toString(),
        name: res['name']?.toString(),
      );

      await ref.read(sessionProvider.notifier).setSession(session);
    } on DioException catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Login');

      final data = e.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;

      if (e.response?.statusCode == 403 &&
          detail != null &&
          detail.contains('Account frozen')) {
        final reason = detail.split('Account frozen:').last.trim();
        widget.onFrozen(reason.isEmpty ? 'Аккаунт заморожен' : reason);
      } else {
        setState(() => error = detail ?? ErrorHandler.getUserMessage(e));
      }
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Login');
      setState(() => error = ErrorHandler.getUserMessage(e));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _showPasswordResetSheet() {
    final identifier = TextEditingController();
    final code = TextEditingController();
    final newPassword = TextEditingController();
    final confirm = TextEditingController();
    int step = 0;
    bool loading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          Future<void> requestCode() async {
            final value = identifier.text.trim();
            if (value.isEmpty) return;
            setState(() {
              loading = true;
              error = null;
            });
            try {
              if (value.contains('@')) {
                await ApiRepository().passwordResetRequest(email: value);
              } else {
                await ApiRepository().passwordResetRequest(username: value);
              }
              setState(() {
                step = 1;
                loading = false;
              });
            } catch (_) {
              setState(() {
                loading = false;
                error = 'Не удалось отправить код';
              });
            }
          }

          Future<void> confirmReset() async {
            final value = identifier.text.trim();
            final codeValue = code.text.trim();
            final pass = newPassword.text.trim();
            if (codeValue.isEmpty || pass.isEmpty || pass != confirm.text.trim()) {
              setState(() => error = 'Проверьте код и пароль');
              return;
            }
            setState(() {
              loading = true;
              error = null;
            });
            try {
              await ApiRepository().passwordResetConfirm(
                email: value.contains('@') ? value : null,
                username: value.contains('@') ? null : value,
                code: codeValue,
                newPassword: pass,
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пароль обновлен')),
                );
              }
            } catch (_) {
              setState(() {
                loading = false;
                error = 'Не удалось изменить пароль';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  step == 0 ? 'Сброс пароля' : 'Введите код',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (step == 0)
                  TextField(
                    controller: identifier,
                    decoration: const InputDecoration(labelText: 'Email или username'),
                  )
                else ...[
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(labelText: 'Код'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newPassword,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Новый пароль'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirm,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Повторите пароль'),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: loading ? null : (step == 0 ? requestCode : confirmReset),
                  child: Text(loading ? '...' : step == 0 ? 'Отправить код' : 'Сменить пароль'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return NiosScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Вход'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text('🦊', textAlign: TextAlign.center, style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text(
                  'Войдите в NiosMess',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: NiosCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _username,
                          decoration: niosInputDecoration('Логин', icon: Icons.person_outline),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Введите логин';
                            }
                            if (value.trim().length < 3) {
                              return 'Минимум 3 символа';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: !showPassword,
                          decoration: niosInputDecoration('Пароль', icon: Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => showPassword = !showPassword),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Введите пароль';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showPasswordResetSheet,
                            child: const Text('Забыли пароль?'),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    error!,
                                    style: TextStyle(color: scheme.onErrorContainer),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        NiosPrimaryButton(
                          label: loading ? 'Вход...' : 'Войти',
                          onTap: loading ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Нет аккаунта? ', style: TextStyle(color: scheme.onSurfaceVariant)),
                    TextButton(
                      onPressed: widget.onRegister,
                      child: const Text('Зарегистрироваться'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
