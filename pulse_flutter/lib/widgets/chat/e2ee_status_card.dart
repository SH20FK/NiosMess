import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/providers/secret_chat_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';

final secretProtectionStateProvider = Provider.family<SecretJson, int>((
  ref,
  chatId,
) {
  ref.watch(secretChatRevisionProvider);
  final state =
      ref.watch(secretChatEngineProvider)?.chat(chatId) ?? <String, dynamic>{};
  if (state.isEmpty &&
      ref.watch(chatByIdProvider(chatId))?.keyMismatch == true) {
    return {'status': 'otherDevice'};
  }
  return state;
});

String secretStatusLabel(BuildContext context, String? status) =>
    switch (status) {
      'secured' => context.l10n.secretProtected,
      'keyChanged' => context.l10n.secretKeyChanged,
      'invalidSignature' => context.l10n.secretSignatureInvalid,
      'otherDevice' => context.l10n.secretOtherDevice,
      'updateRequired' => context.l10n.secretUpdateRequired,
      _ => context.l10n.secretPreparing,
    };

class E2eeStatusCard extends ConsumerStatefulWidget {
  const E2eeStatusCard({required this.chatId, required this.onTap, super.key});
  final int chatId;
  final VoidCallback onTap;
  @override
  ConsumerState<E2eeStatusCard> createState() => _E2eeStatusCardState();
}

class _E2eeStatusCardState extends ConsumerState<E2eeStatusCard> {
  Timer? _delay;
  bool _showWaiting = false;
  @override
  void initState() {
    super.initState();
    _delay = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showWaiting = true);
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(secretChatRevisionProvider);
    final engine = ref.watch(secretChatEngineProvider);
    final status =
        ref.watch(secretProtectionStateProvider(widget.chatId))['status']
            as String?;
    final warning =
        status == 'keyChanged' ||
        status == 'invalidSignature' ||
        status == 'otherDevice';
    final pending =
        engine?.messages(widget.chatId).any((m) => m['is_sending'] == true) ??
        false;
    final visible = warning || (_showWaiting && pending);
    final scheme = Theme.of(context).colorScheme;
    final label = warning || status == 'updateRequired'
        ? secretStatusLabel(context, status)
        : context.l10n.secretQueued;
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: M3SpringCurves.spatial,
      child: !visible
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Material(
                color: warning
                    ? scheme.errorContainer
                    : scheme.surfaceContainerHigh,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: InkWell(
                  onTap: widget.onTap,
                  customBorder: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          warning
                              ? Icons.shield_outlined
                              : Icons.schedule_rounded,
                          color: warning
                              ? scheme.onErrorContainer
                              : scheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: warning
                                      ? scheme.onErrorContainer
                                      : scheme.onSurface,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
