import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/error/error_handler.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

class AppErrorSnackbar extends ConsumerWidget {
  const AppErrorSnackbar({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppError? error = ref.watch(errorHandlerProvider);
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            action: SnackBarAction(
              label: context.l10n.commonDismiss,
              onPressed: () => ref.read(errorHandlerProvider.notifier).clear(),
            ),
          ),
        );
        ref.read(errorHandlerProvider.notifier).clear();
      });
    }
    return child;
  }
}
