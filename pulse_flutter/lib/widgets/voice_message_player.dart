import 'dart:math' as math;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({
    required this.audioUrl,
    required this.durationSeconds,
    required this.isMine,
    required this.scheme,
    this.formattedTime,
    this.isRead = false,
    this.isE2ee = false,
    this.isEdited = false,
    super.key,
  });

  final String audioUrl;
  final int durationSeconds;
  final bool isMine;
  final ColorScheme scheme;
  final String? formattedTime;
  final bool isRead;
  final bool isE2ee;
  final bool isEdited;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  late final AudioPlayer _player;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late final List<double> _waveformBars;
  bool _seeking = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer(handleInterruptions: false);
    _initAudioSession();
    _waveformBars = _generateWaveform(widget.audioUrl.hashCode);
    _setupPlayer();
  }

  List<double> _generateWaveform(int seed) {
    final math.Random rng = math.Random(seed);
    final List<double> bars = List<double>.generate(40, (_) {
      return 0.12 + 0.70 * rng.nextDouble();
    });
    for (int i = 1; i < bars.length - 1; i++) {
      bars[i] = (bars[i - 1] + bars[i] + bars[i + 1]) / 3;
    }
    return bars;
  }

  Future<void> _initAudioSession() async {
    try {
      final AudioSession session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      ));
    } catch (_) {}
  }

  Future<void> _setupPlayer() async {
    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(widget.audioUrl)));
      _duration = Duration(seconds: widget.durationSeconds);
      _player.positionStream.listen((p) {
        if (mounted && !_seeking) setState(() => _position = p);
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

  void _seekTo(double fraction) {
    final Duration target = _duration * fraction.clamp(0.0, 1.0);
    _player.seek(target);
    setState(() => _position = target);
  }

  @override
  Widget build(BuildContext context) {
    final bool playing = _player.playing;
    final double progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;
    final Duration remaining = _duration - _position;
    final Color fg = widget.isMine ? widget.scheme.onPrimary : widget.scheme.primary;
    final Color bg = widget.isMine
        ? widget.scheme.primary.withValues(alpha: 0.08)
        : widget.scheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(4),
            child: GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: fg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: fg.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: widget.isMine ? widget.scheme.surface : widget.scheme.surface,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: 40,
                  child: GestureDetector(
                    onTapDown: (TapDownDetails details) {
                      final RenderBox box = context.findRenderObject() as RenderBox;
                      final double localX = details.localPosition.dx;
                      final double width = box.size.width - 60;
                      _seekTo(localX / width);
                    },
                    onHorizontalDragStart: (_) => _seeking = true,
                    onHorizontalDragUpdate: (DragUpdateDetails details) {
                      final RenderBox box = context.findRenderObject() as RenderBox;
                      final double localX = details.localPosition.dx;
                      final double width = box.size.width - 60;
                      _seekTo(localX / width);
                    },
                    onHorizontalDragEnd: (_) => _seeking = false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: CustomPaint(
                        size: const Size(double.infinity, 34),
                        painter: _WaveformPainter(
                          bars: _waveformBars,
                          progress: progress,
                          playedColor: fg,
                          unplayedColor: fg.withValues(alpha: 0.30),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      if (widget.formattedTime != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (widget.isE2ee)
                                Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Icon(
                                    Icons.lock_rounded,
                                    size: 10,
                                    color: Colors.green.withValues(alpha: 0.7),
                                  ),
                                ),
                              if (widget.isEdited)
                                Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Text(
                                    'edited',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: fg.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              Text(
                                widget.formattedTime!,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: fg.withValues(alpha: 0.6),
                                ),
                              ),
                              if (widget.isMine)
                                Padding(
                                  padding: const EdgeInsets.only(left: 3),
                                  child: Icon(
                                    widget.isRead
                                        ? Icons.done_all_rounded
                                        : Icons.check_rounded,
                                    size: 11,
                                    color: fg.withValues(alpha: 0.7),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Text(
                        _formatDuration(remaining),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: fg.withValues(alpha: 0.7),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
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
          const Radius.circular(3),
        ),
        Paint()..color = played ? playedColor : unplayedColor,
      );
    }

    final double thumbX = progress * size.width;
    canvas.drawCircle(
      Offset(thumbX, midY),
      5,
      Paint()
        ..color = playedColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(thumbX, midY),
      5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}
