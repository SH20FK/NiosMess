import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/services/calls/call_quality.dart';
import 'package:pulse_flutter/services/calls/call_session_types.dart';

class CallQualityBadge extends StatelessWidget {
  const CallQualityBadge({required this.data, super.key});
  final CallSessionData data;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n,
        q = data.quality,
        scheme = Theme.of(context).colorScheme;
    final recovering = data.state == CallSessionState.reconnecting;
    final title = recovering
        ? l.callQualityReconnecting
        : switch (q.level) {
            CallQualityLevel.unknown => l.callQualityMeasuring,
            CallQualityLevel.good => l.callQualityGood,
            CallQualityLevel.fair => l.callQualityFair,
            CallQualityLevel.poor => l.callQualityPoor,
          };
    final reason = switch (q.reason) {
      CallQualityReason.none => '',
      CallQualityReason.latency => l.callQualityLatency,
      CallQualityReason.loss => l.callQualityLoss,
      CallQualityReason.jitter => l.callQualityJitter,
      CallQualityReason.bandwidth => l.callQualityBandwidth,
      CallQualityReason.cpu => l.callQualityCpu,
    };
    return Tooltip(
      message: reason.isEmpty ? title : '$title: $reason',
      child: Semantics(
        liveRegion: recovering,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                recovering ? Icons.sync_rounded : Icons.network_check_rounded,
                size: 18,
                color: q.level == CallQualityLevel.poor
                    ? scheme.error
                    : scheme.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  reason.isEmpty || recovering ? title : '$title · $reason',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
