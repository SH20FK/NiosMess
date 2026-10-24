enum CallQualityLevel { unknown, good, fair, poor }

enum CallQualityReason { none, latency, loss, jitter, bandwidth, cpu }

class CallQuality {
  const CallQuality({
    this.level = CallQualityLevel.unknown,
    this.reason = CallQualityReason.none,
    this.rttMs = 0,
    this.lossPercent = 0,
    this.jitterMs = 0,
  });
  final CallQualityLevel level;
  final CallQualityReason reason;
  final double rttMs, lossPercent, jitterMs;
}

/// Uses interval counters per RTP stream, not lifetime loss percentages.
/// SSRCs and raw reports never leave the session or enter diagnostic logs.
class CallQualitySampler {
  final _counters = <String, (double, double)>{};
  CallQuality _last = const CallQuality();
  int _badSamples = 0;

  CallQuality sample(List<Map<String, dynamic>> reports) {
    double rtt = 0, jitter = 0, lost = 0, received = 0;
    var media = false;
    var reason = CallQualityReason.none;
    double number(dynamic v) {
      final n = v is num
          ? v.toDouble()
          : v is String
          ? double.tryParse(v)
          : null;
      return n != null && n.isFinite ? n : 0;
    }

    final seen = <String>{};
    for (final r in reports) {
      final type = r['type'];
      if (type == 'candidate-pair' &&
          (r['selected'] == true || r['nominated'] == true) &&
          r['state'] == 'succeeded') {
        final value = number(r['currentRoundTripTime']) * 1000;
        if (value > rtt) rtt = value;
      }
      if (type == 'outbound-rtp') {
        media |= number(r['bytesSent']) > 0;
        if (r['qualityLimitationReason'] == 'cpu') {
          reason = CallQualityReason.cpu;
        }
        if (r['qualityLimitationReason'] == 'bandwidth') {
          reason = CallQualityReason.bandwidth;
        }
      }
      if (type != 'inbound-rtp' && type != 'remote-inbound-rtp') continue;
      media |= number(r['bytesReceived']) > 0 || type == 'remote-inbound-rtp';
      final j = number(r['jitter']) * 1000;
      if (j > jitter) jitter = j;
      final rt = number(r['roundTripTime']) * 1000;
      if (rt > rtt) rtt = rt;
      if (type != 'inbound-rtp') continue;
      final key = '${r['id'] ?? r['ssrc']}:${r['kind'] ?? r['mediaType']}';
      seen.add(key);
      final l = number(r['packetsLost']), p = number(r['packetsReceived']);
      final old = _counters[key];
      _counters[key] = (l, p);
      if (old != null && p >= old.$2 && l >= old.$1) {
        lost += l - old.$1;
        received += p - old.$2;
      }
    }
    _counters.removeWhere((key, _) => !seen.contains(key));
    final loss = lost + received > 0 ? lost * 100 / (lost + received) : 0.0;
    var level = media ? CallQualityLevel.good : CallQualityLevel.unknown;
    if (reason != CallQualityReason.none) level = CallQualityLevel.fair;
    if (jitter > 40) {
      level = CallQualityLevel.fair;
      reason = CallQualityReason.jitter;
    }
    if (rtt > 300) {
      level = CallQualityLevel.fair;
      reason = CallQualityReason.latency;
    }
    if (loss > 3) {
      level = CallQualityLevel.fair;
      reason = CallQualityReason.loss;
    }
    if (jitter > 80) {
      level = CallQualityLevel.poor;
      reason = CallQualityReason.jitter;
    }
    if (rtt > 700) {
      level = CallQualityLevel.poor;
      reason = CallQualityReason.latency;
    }
    if (loss > 8) {
      level = CallQualityLevel.poor;
      reason = CallQualityReason.loss;
    }
    // One late stats sample should not flash a warning in the call UI.
    if (level.index > _last.level.index &&
        _last.level != CallQualityLevel.unknown) {
      if (++_badSamples < 2) return _last;
    } else {
      _badSamples = 0;
    }
    return _last = CallQuality(
      level: level,
      reason: reason,
      rttMs: rtt,
      lossPercent: loss,
      jitterMs: jitter,
    );
  }
}
