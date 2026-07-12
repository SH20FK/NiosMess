import 'package:flutter/material.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class AppDialogAction {
  const AppDialogAction({
    required this.label,
    this.icon,
    this.onPressed,
    this.destructive = false,
    this.isPrimary = false,
    this.isLoading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool isPrimary;
  final bool isLoading;
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const <AppDialogAction>[],
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
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.22),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.16),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (icon != null) ...<Widget>[
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: Icon(icon, color: scheme.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                title,
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: scheme.onSurface,
                                ),
                              ),
                              if (subtitle != null && subtitle!.trim().isNotEmpty) ...<Widget>[
                                const SizedBox(height: 8),
                                Text(
                                  subtitle!,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (child != null) ...<Widget>[
                      const SizedBox(height: 18),
                      child!,
                    ],
                    if (actions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 22),
                      compactActions
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _buildActions(context, dense: false),
                            )
                          : Wrap(
                              alignment: WrapAlignment.end,
                              runAlignment: WrapAlignment.end,
                              spacing: 10,
                              runSpacing: 10,
                              children: _buildActions(context, dense: true),
                            ),
                    ],
                  ],
                ),
              ),
            ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, {required bool dense}) {
    final List<Widget> buttons = <Widget>[];
    for (final AppDialogAction action in actions) {
      final Widget label = action.isLoading
          ? const AppLoadingIndicator(size: 18)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (action.icon != null) ...<Widget>[
                  Icon(action.icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(action.label)),
              ],
            );

      final ButtonStyle? destructiveStyle = action.destructive
          ? FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            )
          : null;

      final Widget button = action.isPrimary || action.destructive
          ? FilledButton(
              style: destructiveStyle,
              onPressed: action.isLoading ? null : action.onPressed,
              child: label,
            )
          : OutlinedButton(
              onPressed: action.isLoading ? null : action.onPressed,
              child: label,
            );

      if (dense) {
        buttons.add(button);
      } else {
        buttons.add(SizedBox(width: double.infinity, child: button));
      }
    }
    return buttons;
  }
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
  return showDialog<T>(
    context: context,
    builder: builder,
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
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AppDialog(
        title: title,
        subtitle: subtitle,
        icon: icon,
        actions: <AppDialogAction>[
          AppDialogAction(
            label: cancelLabel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppDialogAction(
            label: confirmLabel,
            isPrimary: !destructive,
            destructive: destructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  );
}
