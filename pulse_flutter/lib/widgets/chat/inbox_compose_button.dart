import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/features/chats/presentation/compose_action_sheet.dart';
import 'package:pulse_flutter/providers/chat_list_fab_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class InboxComposeButton extends ConsumerWidget {
  const InboxComposeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isVisible = ref.watch(chatListFabVisibleProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);
    final Duration motionDuration = reducedMotion
        ? Duration.zero
        : M3Durations.short4;

    return AnimatedSlide(
      offset: isVisible ? Offset.zero : const Offset(0, 0.35),
      duration: motionDuration,
      curve: M3SpringCurves.gentle,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: motionDuration,
        curve: M3SpringCurves.expressiveDecel,
        child: ExcludeSemantics(
          excluding: !isVisible,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: FloatingActionButton(
              heroTag: 'compose_chat_fab',
              elevation: 0,
              highlightElevation: 0,
              focusElevation: 0,
              hoverElevation: 1,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              tooltip: context.l10n.inboxCreateMenu,
              onPressed: () {
                final bool haptics = ref.read(
                  uiSettingsProvider.select((s) => s.haptics),
                );
                if (haptics) {
                  HapticService.tap();
                }
                openComposeActions(context);
              },
              child: const Icon(Icons.edit_rounded),
            ),
          ),
        ),
      ),
    );
  }
}
