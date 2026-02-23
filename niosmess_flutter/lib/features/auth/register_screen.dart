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
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
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
        title: const Text('Создание аккаунта'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Регистрация в NiosMess',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                NiosCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _name,
                        decoration: niosInputDecoration('Имя', icon: Icons.badge_outlined),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _username,
                        decoration: niosInputDecoration('Имя пользователя', icon: Icons.person_outline),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _email,
                        decoration: niosInputDecoration('Email', icon: Icons.alternate_email),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        decoration: niosInputDecoration('Пароль', icon: Icons.lock_outline),
                        textInputAction: waitingCode ? TextInputAction.next : TextInputAction.done,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Документы',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ..._legalDocs.map(_buildLegalItem),
                      CheckboxListTile(
                        value: acceptedLegal,
                        onChanged: _allDocsRead ? (val) => setState(() => acceptedLegal = val ?? false) : null,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Я прочитал(а) документы и согласен(на) с условиями'),
                      ),
                      if (!_allDocsRead)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'Откройте и прочитайте все документы',
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      if (waitingCode) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _code,
                          decoration: niosInputDecoration('Код подтверждения', icon: Icons.verified_outlined),
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(error!, style: TextStyle(color: scheme.onErrorContainer)),
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
      ),
    );
  }

  Widget _buildLegalItem(_LegalDoc doc) {
    final read = _readDocs.contains(doc.id);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: read ? scheme.primary : scheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(
          read ? Icons.check_circle : Icons.description_outlined,
          color: read ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(read ? 'Прочитано' : 'Не прочитано'),
        trailing: TextButton(
          onPressed: () => _openLegalDoc(doc),
          child: Text(read ? 'Открыть' : 'Прочитать'),
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
                              child: const Text('Закрыть'),
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
                                    setState(() => _readDocs.add(doc.id));
                                    Navigator.pop(context);
                                  }
                                : null,
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
