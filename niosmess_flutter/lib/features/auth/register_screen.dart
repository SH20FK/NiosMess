import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';
import '../../ui/nios_ui.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({
    super.key,
    required this.onBack,
    required this.onFrozen,
  });

  final VoidCallback onBack;
  final void Function(String reason) onFrozen;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool waitingCode = false;
  bool loading = false;
  bool acceptedLegal = false;
  String? error;
  final List<_LegalDoc> _legalDocs = const [
    _LegalDoc(id: 'terms', title: 'Условия использования', asset: 'assets/legal/terms.txt'),
    _LegalDoc(id: 'privacy', title: 'Политика конфиденциальности', asset: 'assets/legal/privacy.txt'),
    _LegalDoc(id: 'consent', title: 'Согласие на обработку данных', asset: 'assets/legal/consent.txt'),
  ];
  final Set<String> _readDocs = {};

  bool get _allDocsRead => _readDocs.length == _legalDocs.length;

  Future<void> _submit() async {
    if (!_allDocsRead) {
      setState(() => error = 'Откройте и прочитайте все документы');
      return;
    }
    if (!acceptedLegal) {
      setState(() => error = 'Подтвердите согласие с документами');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = ApiRepository();
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text.trim(),
      };
      if (waitingCode) {
        payload['code'] = _code.text.trim();
      }
      final res = await api.register(payload);
      if (res['status'] == 'wait_code') {
        setState(() => waitingCode = true);
        return;
      }
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
        setState(() => error = detail ?? 'Ошибка регистрации');
      }
    } catch (_) {
      setState(() => error = 'Ошибка регистрации');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NiosScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
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
              Text('Создание аккаунта', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: NiosPalette.text)),
              const SizedBox(height: 6),
              Text('Регистрация в NiosMess', style: TextStyle(color: NiosPalette.textSecondary)),
              const SizedBox(height: 24),
              NiosCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _name,
                      decoration: niosInputDecoration('Имя', icon: Icons.badge_outlined),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _username,
                      decoration: niosInputDecoration('Имя пользователя', icon: Icons.person_outline),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      decoration: niosInputDecoration('Email', icon: Icons.alternate_email),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: niosInputDecoration('Пароль', icon: Icons.lock_outline),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NiosPalette.surfaceHover,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NiosPalette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._legalDocs.map(_buildLegalItem).toList(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: acceptedLegal,
                                onChanged: _allDocsRead ? (val) => setState(() => acceptedLegal = val ?? false) : null,
                              ),
                              Expanded(
                                child: Text(
                                  'Я прочитал(а) документы и согласен(на) с условиями',
                                  style: TextStyle(color: NiosPalette.textSecondary),
                                ),
                              ),
                            ],
                          ),
                          if (!_allDocsRead)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                'Откройте и прочитайте все документы',
                                style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (waitingCode) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _code,
                        decoration: niosInputDecoration('Код подтверждения', icon: Icons.verified_outlined),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(255, 90, 90, 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(error!, style: const TextStyle(color: Color(0xFFFF7A7A))),
                      ),
                    ],
                    const SizedBox(height: 12),
                    NiosPrimaryButton(
                      label: waitingCode ? 'Подтвердить' : (loading ? 'Создание...' : 'Создать аккаунт'),
                      onTap: loading ? null : _submit,
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

  Widget _buildLegalItem(_LegalDoc doc) {
    final read = _readDocs.contains(doc.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: read ? const Color.fromRGBO(74, 222, 128, 0.08) : NiosPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: read ? const Color.fromRGBO(74, 222, 128, 0.4) : NiosPalette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.title, style: TextStyle(color: NiosPalette.text, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(read ? 'Прочитано' : 'Не прочитано', style: TextStyle(color: read ? const Color(0xFF4ADE80) : NiosPalette.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openLegalDoc(doc),
            child: Text(read ? 'Открыть' : 'Прочитать'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLegalDoc(_LegalDoc doc) async {
    final raw = await rootBundle.loadString(doc.asset);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final controller = ScrollController();
        bool canAccept = false;
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            void updateAccept() {
              if (!controller.hasClients) return;
              final max = controller.position.maxScrollExtent;
              final current = controller.position.pixels;
              final reached = current >= (max - 12);
              if (reached != canAccept) {
                setStateSheet(() => canAccept = reached);
              }
            }

            controller.removeListener(updateAccept);
            controller.addListener(updateAccept);

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: NiosPalette.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: NiosPalette.border),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(width: 44, height: 4, decoration: BoxDecoration(color: NiosPalette.borderLight, borderRadius: BorderRadius.circular(20))),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: Text(doc.title, style: TextStyle(color: NiosPalette.text, fontWeight: FontWeight.w700))),
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Markdown(
                      controller: controller,
                      data: raw,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: NiosPalette.textSecondary, height: 1.5),
                        h1: TextStyle(color: NiosPalette.text, fontWeight: FontWeight.w700, fontSize: 18),
                        h2: TextStyle(color: NiosPalette.text, fontWeight: FontWeight.w700, fontSize: 16),
                        h3: TextStyle(color: NiosPalette.text, fontWeight: FontWeight.w600, fontSize: 14),
                        listBullet: TextStyle(color: NiosPalette.textSecondary),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canAccept
                            ? () {
                                setState(() => _readDocs.add(doc.id));
                                Navigator.pop(context);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(backgroundColor: NiosPalette.accent),
                        child: const Text('Прочитано'),
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
  }

}

class _LegalDoc {
  const _LegalDoc({required this.id, required this.title, required this.asset});
  final String id;
  final String title;
  final String asset;
}

