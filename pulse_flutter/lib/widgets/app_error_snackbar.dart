import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/error/error_handler.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';

class AppErrorSnackbar extends ConsumerWidget {
  const AppErrorSnackbar({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppError? error = ref.watch(errorHandlerProvider);
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        AppToast.showError(context, error.message);
        ref.read(errorHandlerProvider.notifier).clear();
      });
    }
    return child;
  }
}
