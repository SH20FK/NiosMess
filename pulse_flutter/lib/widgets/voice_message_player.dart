import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/web_socket_client.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:pulse_flutter/widgets/chat/md3_squiggle_progress.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/services/global_voice_playback_service.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';

class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({
    required this.audioUrl,
    required this.durationSeconds,
    required this.isMine,
    required this.scheme,
    required this.chatId,
    required this.wsClient,
    this.e2eeFileKey,
    this.formattedTime,
    this.waveformAmplitudes,
    this.isRead = false,
    this.isE2ee = false,
    this.isEdited = false,
    super.key,
  });

  final String audioUrl;
  final int durationSeconds;
  final bool isMine;
  final ColorScheme scheme;
  final int chatId;
  final WebSocketClient wsClient;

  /// Base64 AES key from the E2EE message envelope; null for plain media.
  final String? e2eeFileKey;
  final String? formattedTime;
  final List<double>? waveformAmplitudes;
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
    _player = AudioPlayer(handleInterruptions: true);
    _initAudioSession();
    _waveformBars = (widget.waveformAmplitudes != null &&
            widget.waveformAmplitudes!.isNotEmpty)
        ? _resampleWaveform(widget.waveformAmplitudes!, 50)
        : _generateWaveform(widget.audioUrl.hashCode);
    _setupPlayer();
  }

  @override
  void didUpdateWidget(covariant VoiceMessagePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl) {
      _setupPlayer();
    }
  }

  List<double> _generateWaveform(int seed) {
    final math.Random rng = math.Random(seed);
    final List<double> bars = List<double>.generate(50, (i) {
      final double envelope = math.sin(math.pi * i / 49);
      final double noise = 0.15 + 0.65 * rng.nextDouble();
      final double wave = 0.3 + 0.4 * math.sin(i * 0.3 + seed * 0.001);
      return (envelope * 0.4 + noise * 0.4 + wave * 0.2).clamp(0.08, 1.0);
    });
    for (int i = 1; i < bars.length - 1; i++) {
      bars[i] = (bars[i - 1] + bars[i] + bars[i + 1]) / 3;
    }
    return bars;
  }

  static List<double> _resampleWaveform(List<double> source, int targetCount) {
    if (source.isEmpty) return List.filled(targetCount, 0.15);
    if (source.length == targetCount) return source.map((v) => v.clamp(0.08, 1.0)).toList();
    final List<double> resampled = [];
    final double step = source.length / targetCount;
    for (int i = 0; i < targetCount; i++) {
      final int start = (i * step).floor();
      final int end = math.min(((i + 1) * step).ceil(), source.length);
      double maxVal = 0.08;
      for (int j = start; j < end; j++) {
        if (source[j] > maxVal) maxVal = source[j];
      }
      resampled.add(maxVal.clamp(0.08, 1.0));
    }
    return resampled;
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

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durationSub;

  void _cancelSubscriptions() {
    _posSub?.cancel();
    _posSub = null;
    _stateSub?.cancel();
    _stateSub = null;
    _durationSub?.cancel();
    _durationSub = null;
  }

  Future<void> _setupPlayer() async {
    _cancelSubscriptions();
    if (widget.audioUrl.startsWith('local://')) {
      return;
    }
    try {
      Uint8List? fileKey;
      if (widget.e2eeFileKey != null && widget.e2eeFileKey!.isNotEmpty) {
        fileKey = base64Decode(widget.e2eeFileKey!);
      }
      final localPath = await WsMediaFetcher.fetchToLocalFile(
        filePath: widget.audioUrl,
        wsClient: widget.wsClient,
        e2eeFileKey: fileKey,
      );
      await _player.setAudioSource(
        AudioSource.file(localPath),
      );
      _duration = Duration(seconds: widget.durationSeconds);
      _posSub = _player.positionStream.listen((p) {
        if (mounted && !_seeking) setState(() => _position = p);
      });
      _stateSub = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          GlobalVoicePlaybackService.instance.unregisterPlaying(widget.audioUrl);
        }
        if (mounted) setState(() {});
      });
      _durationSub = _player.durationStream.listen((d) {
        if (d != null && mounted) setState(() => _duration = d);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    GlobalVoicePlaybackService.instance.unregisterPlaying(widget.audioUrl);
    _cancelSubscriptions();
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_player.playing) {
      _player.pause();
      GlobalVoicePlaybackService.instance.unregisterPlaying(widget.audioUrl);
    } else {
      GlobalVoicePlaybackService.instance.registerPlaying(widget.audioUrl, () {
        if (mounted && _player.playing) {
          _player.pause();
          if (mounted) setState(() {});
        }
      });
      if (_position >= _duration && _duration > Duration.zero) {
        _player.seek(Duration.zero);
      }
      _player.play();
    }
    if (mounted) setState(() {});
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
    final Color onFg = widget.isMine ? widget.scheme.primary : widget.scheme.onPrimary;
    final Color bg = widget.isMine
        ? widget.scheme.onPrimary.withValues(alpha: 0.12)
        : widget.scheme.surfaceContainerHighest.withValues(alpha: 0.50);

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
            child: widget.audioUrl.startsWith('local://')
                ? Consumer(
                    builder: (context, ref, child) {
                      final localId = widget.audioUrl.replaceFirst('local://', '');
                      final task = ref.watch(uploadTaskProvider(localId));
                      final uploadProgress = task?.progress ?? 0.0;
                      return Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            value: uploadProgress,
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(fg),
                          ),
                        ),
                      );
                    },
                  )
                : TouchContainer(
                    borderRadius: AppRadii.fullRadius,
                    onTap: _togglePlay,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: fg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: fg.withValues(alpha: 0.3),
                            blurRadius: playing ? 12 : 6,
                            spreadRadius: playing ? 2 : 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          key: ValueKey<bool>(playing),
                          color: onFg,
                          size: 26,
                        ),
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (widget.audioUrl.startsWith('local://')) {
                        final localId = widget.audioUrl.replaceFirst('local://', '');
                        return Consumer(
                          builder: (context, ref, child) {
                            final task = ref.watch(uploadTaskProvider(localId));
                            final progressVal = task?.progress ?? 0.0;
                            return Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Md3SquiggleProgress(
                                progress: progressVal,
                                color: fg,
                              ),
                            );
                          },
                        );
                      }
                      return GestureDetector(
                        onTapDown: (TapDownDetails details) {
                          final double localX = details.localPosition.dx;
                          final double width = constraints.maxWidth;
                          _seekTo(localX / width);
                        },
                        onHorizontalDragStart: (_) => _seeking = true,
                        onHorizontalDragUpdate: (DragUpdateDetails details) {
                          final double localX = details.localPosition.dx;
                          final double width = constraints.maxWidth;
                          _seekTo(localX / width);
                        },
                        onHorizontalDragEnd: (_) => _seeking = false,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: RepaintBoundary(
                            child: CustomPaint(
                              size: Size(constraints.maxWidth, 34),
                              painter: _WaveformPainter(
                                bars: _waveformBars,
                                progress: progress,
                                playedColor: fg,
                                unplayedColor: fg.withValues(alpha: 0.30),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
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
                                    color: fg.withValues(alpha: 0.6),
                                  ),
                                ),
                              if (widget.isEdited)
                                Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Text(
                                    context.l10n.chatEdited,
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
    return '$m:${s.toString().padLeft(2, '0')}';
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
    final double gap = 1.5;
    final double barWidth = (size.width - (bars.length - 1) * gap) / bars.length;
    final double midY = size.height / 2;
    final double maxBarHeight = size.height * 0.85;

    for (int i = 0; i < bars.length; i++) {
      final double x = i * (barWidth + gap);
      final double barHeight = bars[i] * maxBarHeight;
      final double top = midY - barHeight / 2;
      final bool played = i / bars.length <= progress;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barWidth, barHeight),
          Radius.circular(barWidth / 2),
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
        ..color = unplayedColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}
