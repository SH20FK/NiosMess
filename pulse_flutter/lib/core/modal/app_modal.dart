import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/modal/app_side_sheet.dart';
import 'package:pulse_flutter/core/modal/m3_modal_surface.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
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
      sheetAnimationStyle: const AnimationStyle(
        curve: M3SpringCurves.spatial,
        reverseCurve: M3SpringCurves.spatial,
        duration: Duration(milliseconds: 320),
        reverseDuration: Duration(milliseconds: 280),
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
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              content,
            ],
          );
        }
        return M3ModalSurface(
          variant: ModalVariant.bottomSheet,
          tone: tone,
          showDragHandle: showDragHandle,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          child: content,
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
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierLabel: 'Dialog',
      barrierColor: scheme.scrim.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (
        BuildContext ctx,
        Animation<double> anim1,
        Animation<double> anim2,
      ) {
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
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              content,
            ],
          );
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: M3ModalSurface(
              variant: ModalVariant.dialog,
              tone: tone,
              destructive: destructive,
              maxWidth: maxWidth,
              maxHeight: maxHeight ?? MediaQuery.sizeOf(ctx).height * 0.88,
              child: content,
            ),
          ),
        );
      },
      transitionBuilder: (
        BuildContext ctx,
        Animation<double> anim1,
        Animation<double> anim2,
        Widget child,
      ) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(
              CurvedAnimation(
                parent: anim1,
                curve: Curves.easeOutCubic,
              ),
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
    String barrierLabel = 'Side Sheet',
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

  /// Displays an adaptive confirmation dialog / sheet.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    String? message,
    String confirmLabel = 'Подтвердить',
    String cancelLabel = 'Отмена',
    bool destructive = false,
    IconData? icon,
  }) async {
    final bool isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    Widget buildContent(BuildContext ctx) {
      final ColorScheme scheme = Theme.of(ctx).colorScheme;
      final TextTheme textTheme = Theme.of(ctx).textTheme;

      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: destructive
                        ? scheme.error.withValues(alpha: 0.12)
                        : scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: destructive ? scheme.error : scheme.primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null && message.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      HapticService.tap();
                      Navigator.of(ctx).pop(false);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.fullRadius,
                      ),
                    ),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (destructive) {
                        HapticService.destructive();
                      } else {
                        HapticService.tap();
                      }
                      Navigator.of(ctx).pop(true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          destructive ? scheme.error : scheme.primary,
                      foregroundColor:
                          destructive ? scheme.onError : scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.fullRadius,
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (isWide) {
      final bool? res = await showDialog<bool>(
        context: context,
        builder: buildContent,
        destructive: destructive,
      );
      return res ?? false;
    } else {
      final bool? res = await showSheet<bool>(
        context: context,
        builder: buildContent,
        showDragHandle: true,
      );
      return res ?? false;
    }
  }
}
