import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';
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
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool loading = false;
  bool showPassword = false;
  String? error;

  Future<void> _submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = ApiRepository();
      final res = await api.login(_username.text.trim(), _password.text.trim());
      final session = SessionState(
        token: res['token']?.toString(),
        username: res['username']?.toString(),
        name: res['name']?.toString(),
      );
      await ref.read(sessionProvider.notifier).setSession(session);
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      if (e.response?.statusCode == 403 && detail != null && detail.contains('Account frozen')) {
        final reason = detail.split('Account frozen:').last.trim();
        widget.onFrozen(reason.isEmpty ? 'Аккаунт заморожен' : reason);
      } else {
        setState(() => error = detail ?? 'Ошибка входа');
      }
    } catch (_) {
      setState(() => error = 'Ошибка входа');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NiosScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onBack,
                  icon: Icon(Icons.arrow_back, color: NiosPalette.textSecondary),
                  label: Text('Назад', style: TextStyle(color: NiosPalette.textSecondary)),
                ),
              ),
              const SizedBox(height: 8),
              const Text('🦊', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text('Вход', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: NiosPalette.text)),
              const SizedBox(height: 6),
              Text('Войдите в NiosMess', style: TextStyle(color: NiosPalette.textSecondary)),
              const SizedBox(height: 24),
              NiosCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _username,
                      decoration: niosInputDecoration('Логин', icon: Icons.person_outline),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: !showPassword,
                      decoration: niosInputDecoration('Пароль', icon: Icons.lock_outline).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: NiosPalette.textSecondary,
                          ),
                          onPressed: () => setState(() => showPassword = !showPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text('Забыли пароль?', style: TextStyle(color: NiosPalette.accent)),
                      ),
                    ),
                    if (error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(255, 90, 90, 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(error!, style: const TextStyle(color: Color(0xFFFF7A7A))),
                      ),
                    const SizedBox(height: 12),
                    NiosPrimaryButton(label: loading ? 'Вход...' : 'Войти', onTap: loading ? null : _submit),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Нет аккаунта? ', style: TextStyle(color: NiosPalette.textSecondary)),
                        TextButton(
                          onPressed: widget.onRegister,
                          child: Text('Зарегистрироваться', style: TextStyle(color: NiosPalette.accent)),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
