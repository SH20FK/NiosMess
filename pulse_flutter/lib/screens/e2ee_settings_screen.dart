import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class E2eeSettingsScreen extends ConsumerStatefulWidget {
  const E2eeSettingsScreen({super.key});

  @override
  ConsumerState<E2eeSettingsScreen> createState() => _E2eeSettingsScreenState();
}

class _E2eeSettingsScreenState extends ConsumerState<E2eeSettingsScreen> {
  final E2eeService _e2ee = E2eeService();
  bool _loading = false;
  bool _hasKey = false;
  String? _publicKeyPreview;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  Future<void> _checkKey() async {
    final privateKey = await _e2ee.loadPrivateKey();
    if (!mounted) return;
    setState(() => _hasKey = privateKey != null);
  }

  Future<void> _generateAndUploadKey() async {
    setState(() { _loading = true; _error = null; });
    try {
      final publicKeyB64 = await _e2ee.getPublicKeyBase64();
      await ref.read(authRepositoryProvider).setPublicKey(publicKeyB64);
      setState(() {
        _hasKey = true;
        _publicKeyPreview = publicKeyB64.substring(0, 40) + '...';
        _loading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E2EE key generated and uploaded')));
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
      title: 'Secret Chats',
      children: [
        SettingsNavBanner(
          icon: Icons.lock_rounded,
          title: 'Secret Chats (E2EE)',
          subtitle: 'End-to-end encrypted chats are tied to this device. Generate a key pair to enable secret chats.',
          iconColor: Colors.green,
        ),
        SettingsSection(
          title: 'Device Key',
          children: [
            SettingsTile(
              icon: _hasKey ? Icons.vpn_key_rounded : Icons.vpn_key_outlined,
              title: _hasKey ? 'Key pair ready' : 'No key pair',
              subtitle: _hasKey
                  ? (_publicKeyPreview ?? 'Click to regenerate')
                  : 'Generate RSA-2048 key pair for E2EE',
              iconColor: _hasKey ? Colors.green : scheme.onSurfaceVariant,
              onTap: _loading ? () {} : _generateAndUploadKey,
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(year2023: false)),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
              ),
          ],
        ),
        SettingsSection(
          title: 'How it works',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                '• Each device generates its own RSA-2048 key pair\n'
                '• Public key is shared with the server\n'
                '• Private key stays on this device only\n'
                '• Secret chats are visible only on this device\n'
                '• Messages are encrypted with AES-256-GCM\n'
                '• The AES key is encrypted with the recipient\'s RSA public key',
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Create Secret Chat',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                'To start a secret chat, open a direct chat from contacts.\n'
                'Secret chat option will be available after generating your key pair.',
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
