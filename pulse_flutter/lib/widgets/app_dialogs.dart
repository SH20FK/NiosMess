import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/modal/app_modal_content.dart';
import 'package:pulse_flutter/core/modal/m3_modal_surface.dart';
export 'package:pulse_flutter/core/modal/app_modal_content.dart'
    show AppDialogAction;

class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
    this.maxWidth = 460,
    this.compactActions = false,
    this.child,
    super.key,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? child;
  final List<AppDialogAction> actions;
  final double maxWidth;
  final bool compactActions;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: M3ModalSurface(
      variant: ModalVariant.dialog,
      tone: ModalTone.high,
      maxWidth: maxWidth,
      maxHeight:
          (MediaQuery.sizeOf(context).height -
                  MediaQuery.viewInsetsOf(context).bottom -
                  MediaQuery.paddingOf(context).vertical -
                  48)
              .clamp(0, double.infinity),
      isScrollable: true,
      child: AppModalContent(
        title: title,
        subtitle: subtitle,
        icon: icon,
        actions: actions,
        stackedActions: compactActions,
        destructive: actions.any((action) => action.destructive),
        child: child,
      ),
    ),
  );
}

class AppDialogField {
  const AppDialogField({
    required this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final IconData? prefixIcon;
}

class AppDialogFormContent extends StatelessWidget {
  const AppDialogFormContent({required this.fields, super.key});

  final List<AppDialogField> fields;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(fields.length, (int index) {
        final AppDialogField field = fields[index];
        return Padding(
          padding: EdgeInsets.only(bottom: index == fields.length - 1 ? 0 : 12),
          child: AppTextFieldDialogContent(
            controller: field.controller,
            label: field.label,
            hint: field.hint,
            obscureText: field.obscureText,
            keyboardType: field.keyboardType,
            maxLines: field.maxLines,
            prefixIcon: field.prefixIcon,
          ),
        );
      }),
    );
  }
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return AppModal.showDialog<T>(
    context: context,
    builder: builder,
    wrapSurface: false,
  );
}

class AppTextFieldDialogContent extends StatelessWidget {
  const AppTextFieldDialogContent({
    required this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.prefixIcon,
    super.key,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
    );
  }
}

Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String subtitle,
  required String confirmLabel,
  required String cancelLabel,
  IconData? icon,
  bool destructive = false,
}) => AppModal.showConfirmation(
  context: context,
  title: title,
  message: subtitle,
  confirmLabel: confirmLabel,
  cancelLabel: cancelLabel,
  icon: icon,
  destructive: destructive,
  onActionFeedback: (confirmed) {
    try {
      ProviderScope.containerOf(context, listen: false)
          .read(appSoundProvider)
          .playEvent(confirmed ? SoundEvent.confirm : SoundEvent.cancel);
    } catch (_) {}
  },
);
