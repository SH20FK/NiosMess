import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/modal/m3_modal_surface.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

/// A Material 3 Expressive side sheet for wide-screen / desktop contexts.
/// Provides standardized smooth slide-in motion, tonal surface, and semantic accessibility.
class AppSideSheet {
  AppSideSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? barrierLabel,
    double width = 440,
    bool isDismissible = true,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierLabel:
          barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: scheme.scrim.withValues(alpha: 0.45),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> anim1,
            Animation<double> anim2,
          ) {
            return Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: width.clamp(0, MediaQuery.sizeOf(dialogContext).width),
                height: double.infinity,
                child: M3ModalSurface(
                  variant: ModalVariant.sideSheet,
                  tone: ModalTone.high,
                  child: child,
                ),
              ),
            );
          },
      transitionBuilder:
          (
            BuildContext dialogContext,
            Animation<double> anim1,
            Animation<double> anim2,
            Widget child,
          ) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: anim1,
                      curve: M3SpringCurves.expressiveDecel,
                    ),
                  ),
              child: child,
            );
          },
    );
  }
}
