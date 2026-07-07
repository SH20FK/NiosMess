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
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final List<double> _waveformBars = List<double>.generate(40, (_) => 0.08 + 0.32 * math.Random().nextDouble());

  @override
  void initState() {
    super.initState();
    _setupPlayer();
  }

  Future<void> _setupPlayer() async {
    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(widget.audioUrl)));
      _duration = Duration(seconds: widget.durationSeconds);
      _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _player.playerStateStream.listen((ps) {
        if (mounted) setState(() => _state = ps.state);
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
    if (_state == PlayerState.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool playing = _state == PlayerState.playing;
    final double progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;
    final Duration remaining = _duration - _position;

    final Color fg = widget.isMine ? widget.scheme.onPrimary : widget.scheme.primary;
    final Color bg = widget.isMine
        ? widget.scheme.onPrimary.withValues(alpha: 0.20)
        : widget.scheme.surfaceContainerHighest;

    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMine ? widget.scheme.primaryContainer : widget.scheme.surface,
                size: 20,
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
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}
