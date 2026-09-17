import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/motion/tri_sync.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';

class AppBottomSheets {
  AppBottomSheets._();

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool useRootNavigator = true,
    bool isDismissible = true,
    bool enableDrag = true,
    bool showDragHandle = true,
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
      backgroundColor: Colors.transparent, // We handle background in the container
      elevation: 0,
      builder: (ctx) {
        return _AppBottomSheetContainer(
          showDragHandle: showDragHandle,
          child: builder(ctx),
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
}

class _AppBottomSheetContainer extends StatelessWidget {
  const _AppBottomSheetContainer({
    required this.child,
    this.showDragHandle = true,
  });

  final Widget child;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.lg),
          ),
        ),
        child: SafeArea(
          bottom: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDragHandle) ...[
                const SizedBox(height: 12),
                // Drag Handle
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Content
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
