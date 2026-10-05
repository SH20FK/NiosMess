import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/circular_theme_reveal.dart';

final bool _isTestEnvironment =
    !kReleaseMode && WidgetsBinding.instance.runtimeType.toString().contains('Test');

final bool _isDesktopPlatform = !_isTestEnvironment &&
    (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

class M3OrganicBackground extends ConsumerWidget {
  const M3OrganicBackground({
    super.key,
    required this.child,
    this.showBackButton = false,
    this.showThemeToggle = true,
    this.onBack,
  });

  final Widget child;
  final bool showBackButton;
  final bool showThemeToggle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.paddingOf(context).top;


    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // ── Child Content ────────────────────────────────────────────
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isDesktop =
                    _isDesktopPlatform && constraints.maxWidth >= 840;
                if (!isDesktop) {
                  return child;
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: child,
                  ),
                );
              },
            ),
          ),

          // ── Top Header Actions (Back & Theme Toggle) ──────────────────
          if (showBackButton || showThemeToggle)
            Positioned(
              top: topPadding + 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (showBackButton)
                    _TopIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: context.l10n.commonBack,
                      scheme: scheme,
                      onTap: () {
                        HapticService.tap();
                        if (onBack != null) {
                          onBack!();
                        } else if (Navigator.canPop(context)) {
                          Navigator.of(context).pop();
                        }
                      },
                    )
                  else
                    const SizedBox(width: 44),

                  if (showThemeToggle)
                    Builder(
                      builder: (BuildContext btnContext) {
                        final ThemeMode currentMode = ref.watch(
                          uiSettingsProvider.select((s) => s.themeMode),
                        );
                        final (IconData modeIcon, ThemeMode nextMode, String tooltip) =
                            switch (currentMode) {
                          ThemeMode.system => (
                              Icons.brightness_auto_rounded,
                              ThemeMode.light,
                              context.l10n.themeModeSystem,
                            ),
                          ThemeMode.light => (
                              Icons.light_mode_rounded,
                              ThemeMode.dark,
                              context.l10n.themeModeLight,
                            ),
                          ThemeMode.dark => (
                              Icons.dark_mode_rounded,
                              ThemeMode.system,
                              context.l10n.themeModeDark,
                            ),
                        };

                        return _TopIconButton(
                          icon: modeIcon,
                          tooltip: tooltip,
                          scheme: scheme,
                          onTap: () {
                            final switcher =
                                CircularThemeSwitcher.maybeOf(btnContext);
                            if (switcher != null) {
                              final RenderBox? box = btnContext
                                  .findRenderObject() as RenderBox?;
                              final Offset? offset =
                                  box != null && box.hasSize
                                      ? box.localToGlobal(
                                          box.size.center(Offset.zero))
                                      : null;
                              switcher.toggleTheme(
                                () => ref
                                    .read(uiSettingsProvider.notifier)
                                    .setThemeMode(nextMode),
                                tapOffset: offset,
                              );
                            } else {
                              HapticService.tap();
                              ref
                                  .read(uiSettingsProvider.notifier)
                                  .setThemeMode(nextMode);
                            }
                          },
                        );
                      },
                    )
                  else
                    const SizedBox(width: 44),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.scheme,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final radii = AppRadii.of(context);
    final Widget button = Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.8),
      borderRadius: AppRadii.fullRadius,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.fullRadius,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: radii.fullRadius,
            border: Border.all(
              color: scheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: scheme.onSurface,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: Semantics(
          button: true,
          label: tooltip,
          child: button,
        ),
      );
    }

    return Semantics(
      button: true,
      child: button,
    );
  }
}
