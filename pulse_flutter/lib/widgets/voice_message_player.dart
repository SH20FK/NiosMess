import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({
    required this.audioUrl,
    required this.durationSeconds,
    required this.isMine,
    required this.scheme,
    super.key,
  });

  final String audioUrl;
  final int durationSeconds;
  final bool isMine;
  final ColorScheme scheme;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late final List<double> _waveformBars;

  @override
  void initState() {
    super.initState();
    final int seed = widget.audioUrl.hashCode;
    final math.Random rng = math.Random(seed);
    _waveformBars = List<double>.generate(40, (_) => 0.15 + 0.55 * rng.nextDouble());
    _setupPlayer();
  }

  Future<void> _setupPlayer() async {
    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(widget.audioUrl)));
      _duration = Duration(seconds: widget.durationSeconds);
      _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _player.playerStateStream.listen((_) {
        if (mounted) setState(() {});
      });
      _player.durationStream.listen((d) {
        if (d != null && mounted) setState(() => _duration = d);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_player.playing) {
      _player.pause();
    } else if (_position >= _duration && _duration > Duration.zero) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool playing = _player.playing;
    final double progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;
    final Duration remaining = _duration - _position;

    final Color fg = widget.isMine ? widget.scheme.onPrimary : widget.scheme.primary;

    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isMine
              ? [widget.scheme.primary, widget.scheme.primaryContainer]
              : [widget.scheme.secondaryContainer, widget.scheme.tertiaryContainer],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMine ? widget.scheme.primaryContainer : widget.scheme.surface,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: 28,
                  child: CustomPaint(
                    size: const Size(double.infinity, 28),
                    painter: _WaveformPainter(
                      bars: _waveformBars,
                      progress: progress,
                      playedColor: fg,
                      unplayedColor: fg.withValues(alpha: 0.30),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _formatDuration(remaining),
                    style: TextStyle(
                      fontSize: 10,
                      color: fg.withValues(alpha: 0.75),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final int sec = d.inSeconds.clamp(0, 9999);
    final int m = sec ~/ 60;
    final int s = sec % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  final List<double> bars;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double barWidth = (size.width - (bars.length - 1) * 2) / bars.length;
    final double midY = size.height / 2;

    for (int i = 0; i < bars.length; i++) {
      final double x = i * (barWidth + 2);
      final double barHeight = bars[i] * size.height;
      final double top = midY - barHeight / 2;
      final bool played = i / bars.length <= progress;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barWidth, barHeight),
          const Radius.circular(1.5),
        ),
        Paint()..color = played ? playedColor : unplayedColor,
      );
    }
    final double thumbX = progress * size.width;
    canvas.drawCircle(
      Offset(thumbX, midY),
      3.5,
      Paint()..color = playedColor,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}
