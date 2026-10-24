import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/features/settings/application/settings_anchor_controller.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/widgets/settings/settings_list_item.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';

class SettingsAnchor extends ConsumerStatefulWidget {
  const SettingsAnchor({required this.id, required this.child, super.key});

  final String id;
  final Widget child;

  @override
  ConsumerState<SettingsAnchor> createState() => _SettingsAnchorState();
}

/// Opens an advanced group when search points inside it, without collapsing
/// it again when the temporary highlight expires.
class SettingsSearchDisclosure extends ConsumerStatefulWidget {
  const SettingsSearchDisclosure({
    required this.anchor,
    required this.title,
    this.subtitle,
    required this.children,
    super.key,
  });
  final String anchor;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  ConsumerState<SettingsSearchDisclosure> createState() =>
      _SettingsSearchDisclosureState();
}

class _SettingsSearchDisclosureState
    extends ConsumerState<SettingsSearchDisclosure> {
  final _controller = ExpansibleController();
  ProviderSubscription<SettingsAnchorState>? _subscription;
  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(settingsAnchorControllerProvider, (
      _,
      next,
    ) {
      if (next.highlightedAnchor == widget.anchor) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_controller.isExpanded) _controller.expand();
        });
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _subscription?.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsAnchor(
    id: widget.anchor,
    child: ExpansionTile(
      controller: _controller,
      maintainState: true,
      title: Text(widget.title),
      subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
      children: widget.children,
    ),
  );
}

class _SettingsAnchorState extends ConsumerState<SettingsAnchor> {
  ProviderSubscription<SettingsAnchorState>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(settingsAnchorControllerProvider, (
      previous,
      next,
    ) {
      if (next.highlightedAnchor == widget.id &&
          previous?.highlightedAnchor != widget.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Scrollable.ensureVisible(
            context,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            curve: M3SpringCurves.expressiveStandard,
            alignment: 0.3,
          );
        });
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool highlighted = ref.watch(
      settingsAnchorControllerProvider.select(
        (SettingsAnchorState s) => s.highlightedAnchor == widget.id,
      ),
    );

    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      key: ValueKey<String>(widget.id),
      duration: const Duration(milliseconds: 260),
      curve: M3SpringCurves.expressiveStandard,
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer.withValues(alpha: 0.38)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: widget.child,
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.title,
    required this.control,
    this.subtitle,
    this.leading,
    this.onTap,
    this.enabled = true,
    this.disabledReason,
    this.anchor,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final SettingsControl control;
  final VoidCallback? onTap;
  final bool enabled;
  final String? disabledReason;
  final String? anchor;

  @override
  Widget build(BuildContext context) {
    final toggle = control is ToggleControl ? control as ToggleControl : null;
    final navigation = control is NavigationControl
        ? control as NavigationControl
        : null;
    final staticValue = control is ValueControl
        ? (control as ValueControl).value
        : null;
    final danger =
        control is ActionControl && (control as ActionControl).destructive;
    final row = SettingsListItem(
      icon: leading is Icon
          ? ((leading as Icon).icon ?? Icons.tune_rounded)
          : Icons.tune_rounded,
      leading: leading,
      showIcon: leading != null,
      title: title,
      subtitle: enabled ? subtitle : disabledReason ?? subtitle,
      value: navigation?.value ?? staticValue,
      type: toggle != null
          ? SettingsListItemType.toggle
          : danger
          ? SettingsListItemType.danger
          : navigation != null
          ? SettingsListItemType.nav
          : control is ValueControl
          ? SettingsListItemType.value
          : SettingsListItemType.action,
      boolValue: toggle?.value,
      onChanged: toggle?.onChanged,
      pending: toggle?.pending ?? false,
      enabled: enabled,
      onTap: onTap,
    );
    return anchor?.isNotEmpty == true
        ? SettingsAnchor(id: anchor!, child: row)
        : row;
  }
}
