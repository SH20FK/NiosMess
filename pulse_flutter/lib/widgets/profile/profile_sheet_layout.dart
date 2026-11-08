import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/modal/m3_modal_surface.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Shared profile sheet: balanced header, one scroll area, persistent action.
class ProfileSheetLayout extends StatelessWidget {
  const ProfileSheetLayout({
    required this.title,
    required this.onClose,
    required this.child,
    this.actionLabel,
    this.onSubmit,
    this.busy = false,
    this.secondaryAction,
    super.key,
  });

  final String title;
  final VoidCallback? onClose;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onSubmit;
  final bool busy;
  final Widget? secondaryAction;

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isDismissible = false,
  }) => MediaQuery.sizeOf(context).width >= Breakpoints.medium
      ? AppModal.showDialog<T>(
          context: context,
          builder: builder,
          maxWidth: 520,
          isDismissible: isDismissible,
          // Match the sheet surface so filled fields keep their tonal boundary
          // in desktop dialogs as well as on mobile.
          tone: ModalTone.low,
        )
      : AppModal.showSheet<T>(
          context: context,
          builder: builder,
          maxWidth: 520,
          isDismissible: isDismissible,
          enableDrag: isDismissible,
          showDragHandle: false,
        );

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 48,
                child: IconButton(
                  tooltip: context.l10n.commonCancel,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  namesRoute: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox.square(dimension: 48),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: child,
          ),
        ),
        if (actionLabel != null || secondaryAction != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (actionLabel != null)
                  FilledButton(
                    onPressed: busy ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: busy
                        ? const AppLoadingIndicator(size: 22)
                        : Text(actionLabel!, textAlign: TextAlign.center),
                  ),
                if (secondaryAction != null) ...[
                  const SizedBox(height: 8),
                  secondaryAction!,
                ],
              ],
            ),
          ),
      ],
    ),
  );
}

/// Secondary fields stay discoverable without competing with the main form.
class ProfileDetailsGroup extends StatefulWidget {
  const ProfileDetailsGroup({
    required this.title,
    required this.children,
    this.controller,
    this.enabled = true,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final ExpansibleController? controller;
  final bool enabled;

  @override
  State<ProfileDetailsGroup> createState() => _ProfileDetailsGroupState();
}

class _ProfileDetailsGroupState extends State<ProfileDetailsGroup> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.controller?.isExpanded ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    );
    return ExpansionTile(
      controller: widget.controller,
      enabled: widget.enabled,
      maintainState: true,
      onExpansionChanged: (value) => setState(() => _expanded = value),
      title: Text(widget.title, style: Theme.of(context).textTheme.titleSmall),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: shape,
      collapsedShape: shape,
      backgroundColor: scheme.surfaceContainerHigh,
      collapsedBackgroundColor: scheme.surfaceContainerHigh,
      expansionAnimationStyle: AnimationStyle(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : M3Durations.medium2,
        curve: M3SpringCurves.expressiveDecel,
      ),
      children: [
        ExcludeFocus(
          excluding: !_expanded || !widget.enabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widget.children,
          ),
        ),
      ],
    );
  }
}
