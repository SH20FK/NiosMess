import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';
import '../../ui/nios_ui.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final api = ApiRepository();
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final membersController = TextEditingController();
  bool isChannel = false;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    membersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NiosScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: Icon(Icons.arrow_back, color: NiosPalette.text),
                ),
                const SizedBox(width: 6),
                Text(
                  'Создание чата',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: NiosPalette.text),
                ),
              ],
            ),
            const SizedBox(height: 18),
            NiosCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NiosSectionTitle('Тип чата'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => isChannel = false),
                          child: _TypeChip(
                            title: 'Группа',
                            subtitle: 'Чат для общения участников',
                            active: !isChannel,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => isChannel = true),
                          child: _TypeChip(
                            title: 'Канал',
                            subtitle: 'Публикации только от владельца',
                            active: isChannel,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            NiosCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NiosSectionTitle('Название и описание'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: niosInputDecoration('Название'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: niosInputDecoration('Описание'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            NiosCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NiosSectionTitle('Участники'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: membersController,
                    decoration: niosInputDecoration('Введите никнеймы через запятую'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Можно добавить нескольких участников через запятую или пробел.',
                    style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
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
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: NiosGhostButton(
                    label: 'Отмена',
                    onTap: loading ? null : widget.onBack,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NiosPrimaryButton(
                    label: loading ? 'Создание...' : 'Создать',
                    onTap: loading ? null : _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => error = 'Введите название');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await api.createCollective(
        name: name,
        owner: session.username!,
        token: session.token!,
        isChannel: isChannel,
      );
      final chatId = result['chat_id']?.toString();
      final members = _parseMembers();
      if (chatId != null && chatId.isNotEmpty && members.isNotEmpty) {
        await api.updateMembers(
          chatId: chatId,
          operator: session.username!,
          token: session.token!,
          members: members,
          isChannel: isChannel,
        );
      }
      if (!mounted) return;
      widget.onBack();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isChannel ? 'Канал создан' : 'Группа создана')),
      );
    } catch (_) {
      setState(() => error = 'Не удалось создать чат');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<String> _parseMembers() {
    final raw = membersController.text.trim();
    if (raw.isEmpty) return [];
    final parts = raw
        .split(RegExp(r'[\,\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    return parts;
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.title,
    required this.subtitle,
    required this.active,
  });

  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? NiosPalette.accent.withValues(alpha: 0.18) : NiosPalette.surfaceHover,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? NiosPalette.accent : NiosPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: NiosPalette.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

