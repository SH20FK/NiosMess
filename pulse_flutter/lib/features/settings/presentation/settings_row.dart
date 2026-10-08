import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/features/settings/application/settings_anchor_controller.dart';
import 'package:pulse_flutter/features/settings/domain/settings_control.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class SettingsAnchor extends ConsumerStatefulWidget {
  const SettingsAnchor({
    required this.id,
    required this.child,
    super.key,
  });

  final String id;
  final Widget child;

  @override
  ConsumerState<SettingsAnchor> createState() => _SettingsAnchorState();
}

class _SettingsAnchorState extends ConsumerState<SettingsAnchor> {
  @override
  Widget build(BuildContext context) {
    final bool highlighted = ref.watch(
      settingsAnchorControllerProvider.select(
        (SettingsAnchorState s) => s.highlightedAnchor == widget.id,
      ),
    );

    if (highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: 0.3,
          );
        }
      });
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      key: ValueKey<String>(widget.id),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final bool isToggle = control is ToggleControl;
    final ToggleControl? toggle = isToggle ? control as ToggleControl : null;

    final Widget content = Semantics(
      container: true,
      button: !isToggle && onTap != null,
      toggled: toggle?.value,
      enabled: enabled,
      label: title,
      hint: enabled ? subtitle : disabledReason,
      child: InkWell(
        onTap: enabled
            ? (isToggle
                ? (toggle?.onChanged != null
                    ? () => toggle!.onChanged!(!toggle.value)
                    : null)
                : onTap)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  SizedBox.square(dimension: 32, child: Center(child: leading)),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: textTheme.bodyLarge?.copyWith(
                          color: enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.38),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: enabled
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface.withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _SettingsControlWidget(control: control, enabled: enabled),
              ],
            ),
          ),
        ),
      ),
    );

    if (anchor != null && anchor!.isNotEmpty) {
      return SettingsAnchor(id: anchor!, child: content);
    }
    return content;
  }
}

class _SettingsControlWidget extends StatelessWidget {
  const _SettingsControlWidget({
    required this.control,
    required this.enabled,
  });

  final SettingsControl control;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return switch (control) {
      ToggleControl(:final bool value, :final ValueChanged<bool>? onChanged, :final bool pending) =>
        pending
            ? const SizedBox(
                width: 48,
                height: 32,
                child: Center(child: AppLoadingIndicator(size: 20)),
              )
            : Switch(
                value: value,
                onChanged: enabled ? onChanged : null,
              ),
      NavigationControl(:final String? value) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (value != null && value.isNotEmpty)
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ValueControl(:final String value) => Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ActionControl(:final bool destructive) => Icon(
          Icons.arrow_forward_rounded,
          size: 18,
          color: destructive ? scheme.error : scheme.primary,
        ),
    };
  }
}
