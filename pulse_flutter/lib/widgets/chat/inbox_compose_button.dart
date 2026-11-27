import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/motion/m3_motion.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/features/chats/presentation/compose_action_sheet.dart';
import 'package:pulse_flutter/providers/chat_list_fab_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// Vertical space the inbox keeps free for the composer button:
/// [kInboxComposerMargin] gap + the 56 dp button + [kInboxComposerMargin]
/// gap. The list reserves exactly this much trailing room while the button
/// is shown, and the scrim under the button covers the same strip. The 56 is
/// the regular M3 FAB edge: material_ui keeps that number inside the
/// generated FAB defaults (`sizeConstraints`) and exports no constant for
/// it, so it is spelled out here.
const double kInboxComposerClearance = kInboxComposerMargin * 2 + 56.0;

/// Gap between the composer button and the pane edge / navigation bar.
/// The same margin the FAB location system docks the button with.
const double kInboxComposerMargin = kFloatingActionButtonMargin;

/// Floating "new conversation" button of the inbox.
///
/// Shape, colours and the flat elevation come from the theme's FAB token.
/// The button springs in (scale and slide may overshoot) and leaves on an
/// accelerating curve; opacity rides an effects curve in both directions.
class InboxComposeButton extends ConsumerWidget {
  const InboxComposeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isVisible = ref.watch(inboxComposerVisibleProvider);
    final bool animate = !context.reduceMotion;
    final Duration spatial = !animate
        ? Duration.zero
        : isVisible
        ? M3Durations.spatialFast
        : M3Durations.short4;
    final Curve spatialCurve = isVisible
        ? M3SpringCurves.spatialFast
        : M3SpringCurves.expressiveAccel;

    return AnimatedSlide(
      offset: isVisible ? Offset.zero : const Offset(0, 0.35),
      duration: spatial,
      curve: spatialCurve,
      child: AnimatedScale(
        scale: isVisible ? 1 : 0.6,
        duration: spatial,
        curve: spatialCurve,
        child: AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: animate ? M3Durations.effectsFast : Duration.zero,
          curve: M3SpringCurves.effectsFast,
          child: ExcludeSemantics(
            excluding: !isVisible,
            child: IgnorePointer(
              ignoring: !isVisible,
              child: FloatingActionButton(
                heroTag: 'compose_chat_fab',
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
      ),
    );
  }
}
