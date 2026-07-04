import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
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
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: context.l10n.e2eeGeneratingKeys,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (ctx, a1, a2, child) {
        return FadeTransition(
          opacity: a1,
          child: const _KeyGenerationOverlay(),
        );
      },
    );

    try {
      final publicKeyB64 = await _e2ee.getPublicKeyBase64();
      await ref.read(authRepositoryProvider).setPublicKey(publicKeyB64);
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      setState(() {
        _hasKey = true;
        _publicKeyPreview = '${publicKeyB64.substring(0, 40)}...';
        _loading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.e2eeKeyGenerated)));
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _rotateKey() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(context.l10n.e2eeRotateConfirmTitle),
        content: Text(
          context.l10n.e2eeRotateConfirmBody,
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.e2eeRotateConfirm, style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _loading = true; _error = null; });
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: context.l10n.e2eeGeneratingKeys,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (ctx, a1, a2, child) {
        return FadeTransition(
          opacity: a1,
          child: const _KeyGenerationOverlay(),
        );
      },
    );

    try {
      await _e2ee.rotateKeyPair();
      final publicKeyB64 = await _e2ee.getPublicKeyBase64();
      await ref.read(authRepositoryProvider).setPublicKey(publicKeyB64);
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      setState(() {
        _publicKeyPreview = '${publicKeyB64.substring(0, 40)}...';
        _loading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.e2eeKeyRotated)),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SettingsScaffold(
      title: context.l10n.e2eeScreenTitle,
      children: [
        SettingsNavBanner(
          icon: Icons.lock_rounded,
          title: context.l10n.e2eeBannerTitle,
          subtitle: context.l10n.e2eeBannerSubtitle,
          iconColor: Colors.green,
        ),
        SettingsSection(
          title: context.l10n.e2eeDeviceKey,
          children: [
            SettingsTile(
              icon: _hasKey ? Icons.vpn_key_rounded : Icons.vpn_key_outlined,
              title: _hasKey ? context.l10n.e2eeKeyPairReady : context.l10n.e2eeNoKeyPair,
              subtitle: _hasKey
                  ? (_publicKeyPreview ?? context.l10n.e2eeTapToRegenerate)
                  : context.l10n.e2eeGenerateKeyPair,
              iconColor: _hasKey ? Colors.green : scheme.onSurfaceVariant,
              onTap: _loading ? () {} : _generateAndUploadKey,
            ),
            if (_hasKey)
              SettingsTile(
                icon: Icons.refresh_rounded,
                title: context.l10n.e2eeRotateKey,
                subtitle: context.l10n.e2eeRotateKeySubtitle,
                iconColor: Colors.orange,
                onTap: _loading ? () {} : _rotateKey,
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
              ),
          ],
        ),
        SettingsSection(
          title: context.l10n.e2eeHowItWorks,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                context.l10n.e2eeHowItWorksDesc,
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.e2eeCreateSecretChat,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                context.l10n.e2eeCreateSecretChatDesc,
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyGenerationOverlay extends StatefulWidget {
  const _KeyGenerationOverlay();

  @override
  State<_KeyGenerationOverlay> createState() => _KeyGenerationOverlayState();
}

class _KeyGenerationOverlayState extends State<_KeyGenerationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _rotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, _) {
                    return Transform.scale(
                      scale: _pulse.value,
                      child: Transform.rotate(
                        angle: _rotation.value * 6.28,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.2),
                              width: 4,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Icon(
                              Icons.vpn_key_rounded,
                              color: scheme.primary,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.e2eeGeneratingKeys,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.e2eeGeneratingKeysDesc,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
