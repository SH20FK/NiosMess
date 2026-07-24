import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';

class E2eeVerificationSheet extends ConsumerStatefulWidget {
  const E2eeVerificationSheet({
    required this.chatId,
    this.onInitiateHandshake,
    super.key,
  });

  final int chatId;
  final VoidCallback? onInitiateHandshake;

  @override
  ConsumerState<E2eeVerificationSheet> createState() =>
      _E2eeVerificationSheetState();
}

class _E2eeVerificationSheetState extends ConsumerState<E2eeVerificationSheet> {
  late Future<E2eeSessionInfo> _sessionInfo;
  String? _checkResult;

  @override
  void initState() {
    super.initState();
    _sessionInfo = ref.read(e2eeServiceProvider).getSessionInfo(widget.chatId);
  }

  Color _colorFromName(String name) {
    switch (name) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.amber;
      case 'blue':
        return Colors.blue;
      case 'magenta':
        return Colors.pink;
      case 'cyan':
        return Colors.cyan;
      case 'white':
        return Colors.grey.shade100;
      default:
        return Colors.grey;
    }
  }

  Future<void> _runCheckEnc() async {
    setState(() => _checkResult = null);
    final e2ee = ref.read(e2eeServiceProvider);
    final hash = await e2ee.computeCheckHash(widget.chatId);
    setState(() =>
        _checkResult = 'CHK sent. Wait for peer response.\nHash: $hash');
  }

  Future<void> _verifyPeer() async {
    try {
      final e2ee = ref.read(e2eeServiceProvider);
      await e2ee.verifyPeer(widget.chatId);
      if (!mounted) return;
      AppToast.showSuccess(context, context.l10n.e2eePeerVerified);
      setState(() =>
          _sessionInfo =
              ref.read(e2eeServiceProvider).getSessionInfo(widget.chatId));
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: FutureBuilder<E2eeSessionInfo>(
          future: _sessionInfo,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final info = snapshot.data!;
            final isSecured = info.status == E2eeSessionStatus.secured;
            final isConnecting =
                info.status == E2eeSessionStatus.connecting;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: info.isVerified
                          ? Colors.green
                          : isSecured
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.e2eeEncryptionTitle,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (isSecured)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: info.isVerified
                              ? Colors.green.withValues(alpha: 0.15)
                              : scheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          info.isVerified
                              ? l10n.e2eeVerified
                              : l10n.e2eeUnverified,
                          style: textTheme.labelSmall?.copyWith(
                            color: info.isVerified
                                ? Colors.green
                                : scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (info.status == E2eeSessionStatus.none) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 32,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No E2EE session established yet.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "Initialize" to start the secure handshake with your peer.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: widget.onInitiateHandshake,
                            icon: const Icon(Icons.lock_rounded, size: 18),
                            label: const Text('Initialize E2EE'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (isConnecting) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          'Waiting for peer handshake response...',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (isSecured && info.visualWords != null) ...[
                  Text(
                    l10n.e2eeVisualWordsDesc,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: info.visualWords!.map((word) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _colorFromName(word.color)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            word.word,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _colorFromName(word.color),
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.e2eeCompareWordsHint,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (info.status == E2eeSessionStatus.compromised)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_rounded,
                            color: scheme.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.e2eeMitmWarning,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                if (info.peerFingerprint != null) ...[
                  _fingerprintRow(
                    scheme,
                    textTheme,
                    label: l10n.e2eeYourFingerprint,
                    fingerprint: info.ourFingerprint ?? '',
                  ),
                  const SizedBox(height: 8),
                  _fingerprintRow(
                    scheme,
                    textTheme,
                    label: l10n.e2eePeerFingerprint,
                    fingerprint: info.peerFingerprint!,
                  ),
                  const SizedBox(height: 20),
                ],

                if (isSecured)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: info.isVerified ? null : _verifyPeer,
                          icon:
                              const Icon(Icons.verified_rounded, size: 18),
                          label: Text(l10n.e2eeVerifyAction),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _runCheckEnc,
                          icon: const Icon(Icons.sync_rounded, size: 18),
                          label: Text(l10n.e2eeCheckEnc),
                        ),
                      ),
                    ],
                  ),

                if (_checkResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _checkResult!,
                        style: textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _fingerprintRow(
    ColorScheme scheme,
    TextTheme textTheme, {
    required String label,
    required String fingerprint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            fingerprint,
            style: textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontSize: 11,
              letterSpacing: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
