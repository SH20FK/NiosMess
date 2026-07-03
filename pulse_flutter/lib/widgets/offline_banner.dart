import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({this.isOffline = false, super.key});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isOffline ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: isOffline
            ? SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  height: 36,
                  color: scheme.errorContainer,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 16,
                        color: scheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.offlineWaiting,
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
