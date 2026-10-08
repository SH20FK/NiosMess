import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/theme/app_typography.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/widgets/chat/e2ee_status_card.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

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
  bool _advanced = false;
  bool _busy = false;
  Future<void> _accept() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.secretKeyChanged,
      subtitle: context.l10n.secretKeyChangedBody,
      confirmLabel: context.l10n.secretAcceptKey,
      cancelLabel: context.l10n.commonCancel,
      icon: Icons.shield_outlined,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final coordinator = await ref.read(secretChatCoordinatorProvider.future);
      await coordinator?.engine.acceptChangedIdentity(widget.chatId);
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, context.l10n.secretSignatureInvalid);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(secretChatRevisionProvider);
    final engine = ref.watch(secretChatEngineProvider);
    final state = ref.watch(secretProtectionStateProvider(widget.chatId));
    final status = state['status'] as String?;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: scheme.primaryContainer,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 32,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.secretTitle,
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  fontFamilyFallback: const [AppFonts.ui],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                secretStatusLabel(context, status),
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.secretDescription,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (status == 'keyChanged') ...[
                const SizedBox(height: 20),
                Text(context.l10n.secretKeyChangedBody, style: text.bodyMedium),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _busy ? null : _accept,
                  child: _busy
                      ? const AppLoadingIndicator(size: 24)
                      : Text(context.l10n.secretAcceptKey),
                ),
              ],
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: status == 'secured'
                    ? () => setState(() => _advanced = !_advanced)
                    : null,
                icon: Icon(
                  _advanced ? Icons.expand_less_rounded : Icons.qr_code_rounded,
                ),
                label: Text(context.l10n.secretAdvanced),
              ),
              AnimatedSize(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: M3SpringCurves.spatial,
                child: !_advanced || engine == null
                    ? const SizedBox.shrink()
                    : FutureBuilder<String>(
                        future: engine.safetyNumber(widget.chatId),
                        builder: (context, snapshot) {
                          final number = snapshot.data;
                          if (number == null) {
                            return const Center(
                              child: AppLoadingIndicator(size: 32),
                            );
                          }
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 12),
                              Text(
                                context.l10n.secretCompare,
                                style: text.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              QrImageView(
                                data:
                                    "niosmess:secret-v2:${number.replaceAll(' ', '')}",
                                size: 184,
                                backgroundColor: scheme.surface,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: scheme.onSurface,
                                ),
                                dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SelectableText(
                                number,
                                textAlign: TextAlign.center,
                                style: text.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.tonal(
                                onPressed: state['verified'] == true
                                    ? null
                                    : () async {
                                        await engine.verifyIdentity(
                                          widget.chatId,
                                        );
                                      },
                                child: Text(
                                  state['verified'] == true
                                      ? context.l10n.secretVerified
                                      : context.l10n.secretCodesMatch,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
