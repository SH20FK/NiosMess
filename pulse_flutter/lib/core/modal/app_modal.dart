import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/modal/app_side_sheet.dart';
import 'package:pulse_flutter/core/modal/app_modal_content.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/m3_modal_surface.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/theme/app_typography.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';

/// Centralized Material 3 Expressive modal layer for NiosMess.
/// Unifies desktop dialogs, mobile bottom sheets, side sheets, confirmations, and forms.
class AppModal {
  AppModal._();

  /// Displays an adaptive bottom sheet on mobile or compact screens.
  static Future<T?> showSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    bool isScrollControlled = true,
    bool useRootNavigator = true,
    bool isDismissible = true,
    bool enableDrag = true,
    bool showDragHandle = true,
    bool isScrollable = true,
    double? maxWidth,
    double? maxHeight,
    ModalTone tone = ModalTone.low,
    WidgetRef? ref,
  }) async {
    final T? result = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              curve: M3SpringCurves.expressiveDecel,
              reverseCurve: M3SpringCurves.expressiveAccel,
              duration: Duration(milliseconds: 300),
              reverseDuration: Duration(milliseconds: 250),
            ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (BuildContext ctx) {
        Widget content = builder(ctx);
        if (title != null && title.isNotEmpty) {
          content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontFamily: AppFonts.ui,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(fit: FlexFit.loose, child: content),
            ],
          );
        }
        final media = MediaQuery.of(ctx);
        final available =
            (media.size.height -
                    media.viewInsets.bottom -
                    media.padding.top -
                    24)
                .clamp(0.0, double.infinity);
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: MediaQuery.removeViewInsets(
            context: ctx,
            removeBottom: true,
            child: M3ModalSurface(
              variant: ModalVariant.bottomSheet,
              tone: tone,
              showDragHandle: showDragHandle,
              maxWidth: maxWidth,
              maxHeight: maxHeight == null
                  ? available
                  : maxHeight.clamp(0, available),
              isScrollable: isScrollable,
              child: content,
            ),
          ),
        );
      },
    );

    if (context.mounted) {
      TriSync.dismiss(ref: ref, context: context);
    } else {
      TriSync.dismiss(ref: ref);
    }
    return result;
  }

  /// Displays a centered Material 3 Expressive dialog for wide / desktop screens.
  static Future<T?> showDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    bool isDismissible = true,
    double? maxWidth = 460,
    double? maxHeight,
    ModalTone tone = ModalTone.high,
    bool destructive = false,
    bool isScrollable = true,
    bool wrapSurface = true,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: scheme.scrim.withValues(alpha: 0.45),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      pageBuilder:
          (BuildContext ctx, Animation<double> anim1, Animation<double> anim2) {
            Widget content = builder(ctx);
            if (title != null && title.isNotEmpty) {
              content = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Flexible(fit: FlexFit.loose, child: content),
                ],
              );
            }
            if (!wrapSurface) return content;
            final media = MediaQuery.of(ctx);
            final available =
                (media.size.height -
                        media.viewInsets.bottom -
                        media.padding.vertical -
                        48)
                    .clamp(0.0, double.infinity);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  24 + media.viewInsets.bottom,
                ),
                child: Center(
                  child: MediaQuery.removeViewInsets(
                    context: ctx,
                    removeBottom: true,
                    child: M3ModalSurface(
                      variant: ModalVariant.dialog,
                      tone: tone,
                      destructive: destructive,
                      maxWidth: maxWidth,
                      maxHeight: maxHeight == null
                          ? available
                          : maxHeight.clamp(0, available),
                      isScrollable: isScrollable,
                      child: content,
                    ),
                  ),
                ),
              ),
            );
          },
      transitionBuilder:
          (
            BuildContext ctx,
            Animation<double> anim1,
            Animation<double> anim2,
            Widget child,
          ) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: anim1,
                curve: M3SpringCurves.expressiveDecel,
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                  CurvedAnimation(parent: anim1, curve: M3SpringCurves.gentle),
                ),
                child: child,
              ),
            );
          },
    );
  }

  /// Displays a slide-in right side sheet on wide / desktop screens.
  static Future<T?> showSideSheet<T>({
    required BuildContext context,
    required Widget child,
    String? barrierLabel,
    double width = 440,
    bool isDismissible = true,
  }) {
    return AppSideSheet.show<T>(
      context: context,
      child: child,
      barrierLabel: barrierLabel,
      width: width,
      isDismissible: isDismissible,
    );
  }

  /// Displays an adaptive actions sheet (mobile bottom sheet, desktop centered dialog).
  static Future<T?> showActions<T>({
    required BuildContext context,
    Widget? header,
    required List<Widget> actions,
    Widget? destructiveAction,
    double? maxWidth = 380,
    WidgetRef? ref,
  }) async {
    final bool isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    Widget buildContent(BuildContext ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, isWide ? 16 : 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (header != null) ...<Widget>[header, const SizedBox(height: 12)],
            ...actions,
            if (destructiveAction != null) ...<Widget>[
              const SizedBox(height: 8),
              destructiveAction,
            ],
          ],
        ),
      );
    }

    if (isWide) {
      return showDialog<T>(
        context: context,
        maxWidth: maxWidth,
        builder: buildContent,
      );
    } else {
      return showSheet<T>(
        context: context,
        maxWidth: maxWidth,
        showDragHandle: true,
        ref: ref,
        builder: buildContent,
      );
    }
  }

  /// One presenter for both public confirmation facades. Dismissal stays null.
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    String? message,
    String? confirmLabel,
    String? cancelLabel,
    bool destructive = false,
    IconData? icon,
    ValueChanged<bool>? onActionFeedback,
  }) {
    bool responded = false;
    Widget content(BuildContext ctx) {
      void respond(bool confirmed) {
        if (responded) return;
        responded = true;
        if (confirmed && destructive) {
          HapticService.destructive();
        } else {
          HapticService.tap();
        }
        onActionFeedback?.call(confirmed);
        Navigator.of(ctx).pop(confirmed);
      }

      return AppModalContent(
        title: title,
        subtitle: message,
        icon: icon,
        destructive: destructive,
        stackedActions: false,
        actions: [
          AppDialogAction(
            label: cancelLabel ?? ctx.l10n.commonCancel,
            onPressed: () => respond(false),
          ),
          AppDialogAction(
            label: confirmLabel ?? ctx.l10n.commonContinue,
            isPrimary: true,
            destructive: destructive,
            onPressed: () => respond(true),
          ),
        ],
      );
    }

    return showDialog<bool>(
      context: context,
      builder: content,
      maxWidth: 460,
      isScrollable: true,
    );
  }

  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    String? message,
    String? confirmLabel,
    String? cancelLabel,
    bool destructive = false,
    IconData? icon,
  }) async =>
      await showConfirmation(
        context: context,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        icon: icon,
      ) ??
      false;
}
