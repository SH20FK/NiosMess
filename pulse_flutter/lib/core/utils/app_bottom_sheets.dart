import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';

/// Legacy facade for bottom sheets, forwarding directly to the unified [AppModal.showSheet].
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
  }) {
    return AppModal.showSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      ref: ref,
    );
  }
}
