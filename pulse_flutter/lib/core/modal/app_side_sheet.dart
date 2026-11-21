import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/modal/m3_modal_route.dart';
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
    return Navigator.of(context, rootNavigator: true).push<T>(
      M3ModalRoute<T>(
        context: context,
        barrierDismissible: isDismissible,
        barrierLabel: barrierLabel,
        enterDuration: M3Durations.medium4,
        exitDuration: M3Durations.short4,
        transitionBuilder: M3ModalRoute.sideTransition,
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
      ),
    );
  }
}
