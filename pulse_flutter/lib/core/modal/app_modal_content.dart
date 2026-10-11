import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/app_typography.dart';
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

/// Content only: presentation, results and feedback belong to the modal host.
class AppModalContent extends StatelessWidget {
  const AppModalContent({
    required this.title,
    this.subtitle,
    this.icon,
    this.child,
    this.actions = const [],
    this.stackedActions = false,
    this.destructive = false,
    super.key,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? child;
  final List<AppDialogAction> actions;
  final bool stackedActions;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: destructive
                          ? scheme.errorContainer
                          : scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SizedBox.square(
                      dimension: 48,
                      child: Icon(
                        icon,
                        size: 24,
                        color: destructive
                            ? scheme.onErrorContainer
                            : scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Semantics(
                  namesRoute: true,
                  header: true,
                  child: Text(
                    title,
                    style: text.titleLarge?.copyWith(
                      fontFamily: AppFonts.ui,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (subtitle?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    subtitle!,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                if (child != null) ...[const SizedBox(height: 20), child!],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double width = 0;
                for (final action in actions) {
                  final painter = TextPainter(
                    text: TextSpan(text: action.label, style: text.labelLarge),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout();
                  width += painter.width + 48 + (action.icon == null ? 0 : 26);
                  painter.dispose();
                }
                final stacked =
                    stackedActions ||
                    width + (actions.length - 1) * 8 > constraints.maxWidth;
                final ordered = List<AppDialogAction>.of(actions);
                if (stacked) {
                  ordered.sort(
                    (a, b) => (b.isPrimary || b.destructive ? 1 : 0).compareTo(
                      a.isPrimary || a.destructive ? 1 : 0,
                    ),
                  );
                }
                Widget button(AppDialogAction action) {
                  final onPressed = action.isLoading ? null : action.onPressed;
                  Widget label = action.isLoading
                      ? const AppLoadingIndicator(size: 18)
                      : Text(action.label, textAlign: TextAlign.center);
                  if (action.icon != null && !action.isLoading) {
                    label = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(action.icon, size: 20),
                        const SizedBox(width: 8),
                        Flexible(child: label),
                      ],
                    );
                  }
                  final style = ButtonStyle(
                    minimumSize: const WidgetStatePropertyAll<Size>(
                      Size(64, 56),
                    ),
                    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    shape: const WidgetStatePropertyAll<OutlinedBorder>(
                      StadiumBorder(),
                    ),
                  );
                  return action.isPrimary || action.destructive
                      ? FilledButton(
                          style: style.copyWith(
                            backgroundColor: action.destructive
                                ? WidgetStateProperty.resolveWith<Color?>(
                                    (states) =>
                                        states.contains(WidgetState.disabled)
                                        ? null
                                        : scheme.error,
                                  )
                                : null,
                            foregroundColor: action.destructive
                                ? WidgetStateProperty.resolveWith<Color?>(
                                    (states) =>
                                        states.contains(WidgetState.disabled)
                                        ? null
                                        : scheme.onError,
                                  )
                                : null,
                          ),
                          onPressed: onPressed,
                          child: label,
                        )
                      : TextButton(
                          style: style,
                          onPressed: onPressed,
                          child: label,
                        );
                }

                return stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < ordered.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            button(ordered[i]),
                          ],
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (int i = 0; i < ordered.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            button(ordered[i]),
                          ],
                        ],
                      );
              },
            ),
          ),
      ],
    );
  }
}
