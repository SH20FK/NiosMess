import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/repositories/bot_repository.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class BotScreen extends ConsumerStatefulWidget {
  const BotScreen({super.key});

  @override
  ConsumerState<BotScreen> createState() => _BotScreenState();
}

class _BotScreenState extends ConsumerState<BotScreen> {
  bool _loading = false;
  bool _creating = false;
  List<Map<String, dynamic>>? _updates;
  String? _botToken;
  String? _error;

  Future<void> _createBot() async {
    final nameCtl = TextEditingController();
    final usernameCtl = TextEditingController();
    final descCtl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Bot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Bot Name')),
            TextField(controller: usernameCtl, decoration: const InputDecoration(labelText: 'Username')),
            TextField(controller: descCtl, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create')),
        ],
      ),
    );

    if (result != true) {
      nameCtl.dispose(); usernameCtl.dispose(); descCtl.dispose();
      return;
    }

    setState(() { _creating = true; _error = null; });
    try {
      final response = await ref.read(botRepositoryProvider).createBot(
        name: nameCtl.text.trim(),
        username: usernameCtl.text.trim(),
        description: descCtl.text.trim().isNotEmpty ? descCtl.text.trim() : null,
      );
      nameCtl.dispose(); usernameCtl.dispose(); descCtl.dispose();
      final token = response['token'] as String?;
      if (!mounted) return;
      setState(() {
        _creating = false;
        _botToken = token;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(token != null ? 'Bot created! Token: $token' : 'Bot created')));
    } catch (e) {
      nameCtl.dispose(); usernameCtl.dispose(); descCtl.dispose();
      if (!mounted) return;
      setState(() { _creating = false; _error = '$e'; });
    }
  }

  Future<void> _getUpdates() async {
    if (_botToken == null || _botToken!.isEmpty) {
      final tokenCtl = TextEditingController();
      final tokenResult = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bot Token'),
          content: TextField(controller: tokenCtl, decoration: const InputDecoration(labelText: 'Enter bot token')),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(tokenCtl.text.trim()), child: const Text('Use')),
          ],
        ),
      );
      tokenCtl.dispose();
      if (tokenResult == null || tokenResult.isEmpty) return;
      _botToken = tokenResult;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final updates = await ref.read(botRepositoryProvider).getBotUpdates(_botToken!);
      if (!mounted) return;
      setState(() { _updates = updates; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SettingsScaffold(
      title: 'Bots',
      children: [
        SettingsNavBanner(
          icon: Icons.smart_toy_rounded,
          title: 'Bots',
          subtitle: 'Create and manage your bots.',
          iconColor: Colors.cyan,
        ),
        SettingsSection(
          title: 'Create Bot',
          children: [
            SettingsTile(
              icon: Icons.add_circle_rounded,
              title: 'Create a new bot',
              subtitle: 'Register a bot account',
              iconColor: Colors.cyan,
              onTap: _creating ? () {} : _createBot,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
              ),
            if (_creating)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(year2023: false)),
              ),
          ],
        ),
        if (_botToken != null)
          SettingsSection(
            title: 'Bot Token',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_botToken!, style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token copied')));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        SettingsSection(
          title: 'Bot Updates',
          children: [
            SettingsTile(
              icon: Icons.refresh_rounded,
              title: 'Get updates',
              subtitle: 'Poll for new bot messages and callbacks',
              iconColor: Colors.teal,
              onTap: _loading ? () {} : _getUpdates,
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(year2023: false)),
              ),
            if (_updates != null && _updates!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No updates')),
              ),
            if (_updates != null)
              ..._updates!.map((update) => ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Icon(Icons.notifications_rounded, size: 18, color: scheme.onTertiaryContainer),
                ),
                title: Text(update['update_type'] as String? ?? 'unknown', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('${update['data']}', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
              )),
          ],
        ),
      ],
    );
  }
}
