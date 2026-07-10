import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    this.state = AppConnectionState.online,
    super.key,
  });

  final AppConnectionState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final bool visible = state != AppConnectionState.online;
    final bool isReconnecting = state == AppConnectionState.reconnecting;

    final Color bg =
        isReconnecting ? scheme.secondaryContainer : scheme.errorContainer;
    final Color fg =
        isReconnecting ? scheme.onSecondaryContainer : scheme.onErrorContainer;
    final String label = isReconnecting
        ? context.l10n.connectionReconnecting
        : context.l10n.offlineWaiting;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: visible
            ? SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  height: 36,
                  color: bg,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (isReconnecting)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fg,
                          ),
                        )
                      else
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 16,
                          color: fg,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: textTheme.labelMedium?.copyWith(
                          color: fg,
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
