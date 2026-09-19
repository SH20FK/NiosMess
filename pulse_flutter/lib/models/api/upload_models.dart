/// Low-level upload RPC models, stages, and throughput metrics.
library;

enum UploadStage {
  /// File is queued and waiting for an available concurrent upload slot.
  queued,

  /// Bytes are actively streaming over the network to the server.
  uploading,

  /// Network stream completed (99%); server is transcoding, hashing, or storing.
  processing,

  /// Upload succeeded on server; chat message payload is being dispatched via WS.
  sendingMessage,

  /// Message confirmed by server; optimistic message replaced.
  completed,

  /// Upload or message dispatch encountered an error.
  failed,

  /// Upload was cancelled by the user.
  cancelled,
}

class UploadMetrics {
  const UploadMetrics({
    this.bytesSent = 0,
    this.totalBytes = 0,
    this.smoothedBytesPerSecond = 0.0,
    this.eta,
    this.startedAt,
    this.lastProgressAt,
  });

  final int bytesSent;
  final int totalBytes;
  final double smoothedBytesPerSecond;
  final Duration? eta;
  final DateTime? startedAt;
  final DateTime? lastProgressAt;

  UploadMetrics copyWith({
    int? bytesSent,
    int? totalBytes,
    double? smoothedBytesPerSecond,
    Duration? eta,
    bool clearEta = false,
    DateTime? startedAt,
    DateTime? lastProgressAt,
  }) {
    return UploadMetrics(
      bytesSent: bytesSent ?? this.bytesSent,
      totalBytes: totalBytes ?? this.totalBytes,
      smoothedBytesPerSecond:
          smoothedBytesPerSecond ?? this.smoothedBytesPerSecond,
      eta: clearEta ? null : (eta ?? this.eta),
      startedAt: startedAt ?? this.startedAt,
      lastProgressAt: lastProgressAt ?? this.lastProgressAt,
    );
  }
}

class UploadSpeedTracker {
  UploadSpeedTracker({
    this.windowDuration = const Duration(milliseconds: 1000),
    this.minDurationForDisplay = const Duration(milliseconds: 600),
  });

  final Duration windowDuration;
  final Duration minDurationForDisplay;

  DateTime? _startedAt;
  final List<({DateTime time, int bytes})> _samples =
      <({DateTime time, int bytes})>[];
  double _lastSmoothedSpeed = 0.0;

  DateTime? get startedAt => _startedAt;

  UploadMetrics updateProgress(int sent, int total) {
    final DateTime now = DateTime.now();
    _startedAt ??= now;
    _samples.add((time: now, bytes: sent));

    // Prune samples older than rolling window
    final DateTime cutoff = now.subtract(windowDuration);
    _samples.removeWhere(
      (({DateTime time, int bytes}) sample) => sample.time.isBefore(cutoff),
    );

    final Duration totalElapsed = now.difference(_startedAt!);
    if (totalElapsed < minDurationForDisplay || _samples.length < 2) {
      // Don't show instantaneous speed on the very first chunks to avoid wild jitter
      return UploadMetrics(
        bytesSent: sent,
        totalBytes: total,
        smoothedBytesPerSecond: 0.0,
        eta: null,
        startedAt: _startedAt,
        lastProgressAt: now,
      );
    }

    final ({DateTime time, int bytes}) oldest = _samples.first;
    final int deltaBytes = sent - oldest.bytes;
    final int deltaMicros = now.difference(oldest.time).inMicroseconds;

    if (deltaBytes <= 0 || deltaMicros <= 0) {
      return UploadMetrics(
        bytesSent: sent,
        totalBytes: total,
        smoothedBytesPerSecond: _lastSmoothedSpeed,
        eta: _calculateEta(sent, total, _lastSmoothedSpeed),
        startedAt: _startedAt,
        lastProgressAt: now,
      );
    }

    final double instantSpeed = (deltaBytes * 1000000.0) / deltaMicros;
    // Exponential moving average to smooth out packet bursts
    final double currentSpeed = _lastSmoothedSpeed == 0.0
        ? instantSpeed
        : (_lastSmoothedSpeed * 0.65 + instantSpeed * 0.35);
    _lastSmoothedSpeed = currentSpeed;

    return UploadMetrics(
      bytesSent: sent,
      totalBytes: total,
      smoothedBytesPerSecond: currentSpeed,
      eta: _calculateEta(sent, total, currentSpeed),
      startedAt: _startedAt,
      lastProgressAt: now,
    );
  }

  static Duration? _calculateEta(int sent, int total, double speed) {
    if (speed <= 1024 || total <= sent) return null;
    final int remainingBytes = total - sent;
    final double remainingSeconds = remainingBytes / speed;
    if (remainingSeconds.isInfinite ||
        remainingSeconds.isNaN ||
        remainingSeconds > 86400) {
      return null;
    }
    return Duration(milliseconds: (remainingSeconds * 1000).round());
  }

  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '';
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} МБ/с';
    } else if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} КБ/с';
    } else {
      return '${bytesPerSecond.toStringAsFixed(0)} Б/с';
    }
  }

  static String formatEta(Duration? eta) {
    if (eta == null) return '';
    final int totalSeconds = eta.inSeconds;
    if (totalSeconds < 1) return 'менее секунды';
    if (totalSeconds < 60) return '$totalSecondsс осталось';
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    if (minutes < 60) {
      return '$minutesм $secondsс';
    }
    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes % 60;
    return '$hoursч $remainingMinutesм';
  }

  void reset() {
    _startedAt = null;
    _samples.clear();
    _lastSmoothedSpeed = 0.0;
  }
}

class UploadInitResult {
  const UploadInitResult({required this.uploadId, required this.chunkSize});

  final String uploadId;
  final int chunkSize;

  factory UploadInitResult.fromJson(Map<String, dynamic> json) {
    return UploadInitResult(
      uploadId: json['upload_id'] as String? ?? '',
      chunkSize: json['chunk_size'] as int? ?? 262144,
    );
  }
}

class UploadChunkResult {
  const UploadChunkResult({
    required this.uploadId,
    required this.chunkIndex,
    required this.received,
    required this.total,
    required this.complete,
  });

  final String uploadId;
  final int chunkIndex;
  final int received;
  final int total;
  final bool complete;

  factory UploadChunkResult.fromJson(Map<String, dynamic> json) {
    return UploadChunkResult(
      uploadId: json['upload_id'] as String? ?? '',
      chunkIndex: json['chunk_index'] as int? ?? 0,
      received: json['received'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      complete: json['complete'] as bool? ?? false,
    );
  }
}
