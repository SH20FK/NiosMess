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
import 'package:pulse_flutter/core/media/media_playback_source.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/services/global_voice_playback_service.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

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
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  Duration _duration = Duration.zero;
  late List<double> _waveformBars;
  bool _seeking = false;
  MediaPlaybackSource? _playbackSource;
  int _sourceGeneration = 0;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.durationSeconds.clamp(0, 359999));
    _player = AudioPlayer(handleInterruptions: true);
    _initAudioSession();
    _waveformBars =
        (widget.waveformAmplitudes != null &&
            widget.waveformAmplitudes!.isNotEmpty)
        ? _resampleWaveform(widget.waveformAmplitudes!, 50)
        : List<double>.filled(50, 0.35);
    _setupPlayer();
  }

  @override
  void didUpdateWidget(covariant VoiceMessagePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl ||
        oldWidget.waveformAmplitudes != widget.waveformAmplitudes) {
      _waveformBars =
          (widget.waveformAmplitudes != null &&
              widget.waveformAmplitudes!.isNotEmpty)
          ? _resampleWaveform(widget.waveformAmplitudes!, 50)
          : List<double>.filled(50, 0.35);
    }
    if (oldWidget.audioUrl != widget.audioUrl) {
      _positionNotifier.value = Duration.zero;
      _duration = Duration(seconds: widget.durationSeconds.clamp(0, 359999));
      _setupPlayer();
    } else if (oldWidget.durationSeconds != widget.durationSeconds &&
        _duration == Duration.zero) {
      _duration = Duration(seconds: widget.durationSeconds.clamp(0, 359999));
    }
  }

  static List<double> _resampleWaveform(List<double> source, int targetCount) {
    if (source.isEmpty) return List.filled(targetCount, 0.15);
    if (source.length == targetCount) {
      return source.map((v) => v.clamp(0.08, 1.0)).toList();
    }
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
      await session.configure(
        const AudioSessionConfiguration(
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
        ),
      );
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
    final generation = ++_sourceGeneration;
    _cancelSubscriptions();
    if (widget.audioUrl.startsWith('local://')) {
      return;
    }
    try {
      Uint8List? fileKey;
      if (widget.e2eeFileKey != null && widget.e2eeFileKey!.isNotEmpty) {
        fileKey = base64Decode(widget.e2eeFileKey!);
      }
      final source = await WsMediaFetcher.acquirePlaybackSource(
        filePath: widget.audioUrl,
        mimeType: mediaPlaybackMimeType(widget.audioUrl, fallback: 'audio/mp4'),
        wsClient: widget.wsClient,
        e2eeFileKey: fileKey,
      );
      if (!mounted || generation != _sourceGeneration) {
        await source.close();
        return;
      }
      final oldSource = _playbackSource;
      _playbackSource = source;
      try {
        await _player.setAudioSource(
          source.uri != null
              ? AudioSource.uri(source.uri!)
              : AudioSource.file(source.filePath!),
        );
      } finally {
        await oldSource?.close();
      }
      if (!mounted || generation != _sourceGeneration) return;
      _duration = Duration(seconds: widget.durationSeconds);
      _posSub = _player.positionStream.listen((p) {
        if (mounted && !_seeking) {
          _positionNotifier.value = p;
        }
      });
      _stateSub = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          GlobalVoicePlaybackService.instance.unregisterPlaying(
            widget.audioUrl,
          );
          _positionNotifier.value = Duration.zero;
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
    _sourceGeneration++;
    GlobalVoicePlaybackService.instance.unregisterPlaying(widget.audioUrl);
    _cancelSubscriptions();
    final source = _playbackSource;
    unawaited(() async {
      await _player.dispose();
      await source?.close();
    }());
    _positionNotifier.dispose();
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
      if (_positionNotifier.value >= _duration && _duration > Duration.zero) {
        _player.seek(Duration.zero);
        _positionNotifier.value = Duration.zero;
      }
      _player.play();
    }
    if (mounted) setState(() {});
  }

  void _seekTo(double fraction) {
    final Duration target = _duration * fraction.clamp(0.0, 1.0);
    _player.seek(target);
    _positionNotifier.value = target;
  }

  @override
  Widget build(BuildContext context) {
    final bool playing = _player.playing;
    final Color fg = widget.scheme.primary;
    final Color onFg = widget.scheme.onPrimary;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(4),
            child: widget.audioUrl.startsWith('local://')
                ? Consumer(
                    builder: (context, ref, child) {
                      final localId = widget.audioUrl.replaceFirst(
                        'local://',
                        '',
                      );
                      ref.watch(uploadTaskProvider(localId));
                      return Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: AppLoadingIndicator(size: 26, color: fg),
                      );
                    },
                  )
                : Tooltip(
                    message: playing
                        ? context.l10n.filePreviewPause
                        : context.l10n.filePreviewPlay,
                    child: Semantics(
                      button: true,
                      label: playing
                          ? context.l10n.filePreviewPause
                          : context.l10n.filePreviewPlay,
                      child: TouchContainer(
                        borderRadius: AppRadii.fullRadius,
                        onTap: _togglePlay,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: fg,
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : M3Durations.short3,
                            switchInCurve: M3SpringCurves.expressiveDecel,
                            switchOutCurve: M3SpringCurves.expressiveDecel,
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              key: ValueKey<bool>(playing),
                              color: onFg,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ValueListenableBuilder<Duration>(
              valueListenable: _positionNotifier,
              builder: (context, pos, _) {
                final double progress = _duration.inMilliseconds > 0
                    ? (pos.inMilliseconds / _duration.inMilliseconds).clamp(
                        0.0,
                        1.0,
                      )
                    : 0.0;
                final Duration remaining = _duration - pos;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      height: 40,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (widget.audioUrl.startsWith('local://')) {
                            final localId = widget.audioUrl.replaceFirst(
                              'local://',
                              '',
                            );
                            return Consumer(
                              builder: (context, ref, child) {
                                final task = ref.watch(
                                  uploadTaskProvider(localId),
                                );
                                final progressVal = task?.progress ?? 0.0;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 18),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: SizedBox(
                                      height: 4,
                                      child: Stack(
                                        children: [
                                          Container(
                                            color: fg.withValues(alpha: 0.2),
                                          ),
                                          FractionallySizedBox(
                                            widthFactor: progressVal.clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            child: Container(color: fg),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                          return Semantics(
                            label: context.l10n.mediaPlaybackPosition,
                            value: '${(progress * 100).round()}%',
                            increasedValue:
                                '${((progress + 0.1).clamp(0.0, 1.0) * 100).round()}%',
                            decreasedValue:
                                '${((progress - 0.1).clamp(0.0, 1.0) * 100).round()}%',
                            slider: true,
                            onIncrease: () => _seekTo(progress + 0.1),
                            onDecrease: () => _seekTo(progress - 0.1),
                            child: GestureDetector(
                              onTapDown: (TapDownDetails details) {
                                final double localX = details.localPosition.dx;
                                final double width = constraints.maxWidth;
                                if (width > 0) _seekTo(localX / width);
                              },
                              onHorizontalDragStart: (_) => _seeking = true,
                              onHorizontalDragUpdate:
                                  (DragUpdateDetails details) {
                                    final double localX =
                                        details.localPosition.dx;
                                    final double width = constraints.maxWidth;
                                    if (width > 0) _seekTo(localX / width);
                                  },
                              onHorizontalDragEnd: (_) => _seeking = false,
                              onHorizontalDragCancel: () => _seeking = false,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    key: const ValueKey(
                                      'voice-message-waveform',
                                    ),
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
                            ),
                          );
                        },
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
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
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
    if (size.width <= 0 || size.height <= 0 || bars.isEmpty) return;
    const double gap = 1.5;
    final int count = (size.width / 4).floor().clamp(1, bars.length);
    final double barWidth = (size.width - (count - 1) * gap) / count;
    final double midY = size.height / 2;
    final double maxBarHeight = size.height * 0.85;

    for (int i = 0; i < count; i++) {
      final double x = i * (barWidth + gap);
      final double barHeight =
          bars[(i * bars.length / count).floor()] * maxBarHeight;
      final double top = midY - barHeight / 2;
      final bool played = i / count <= progress;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barWidth, barHeight),
          Radius.circular(barWidth / 2),
        ),
        Paint()..color = played ? playedColor : unplayedColor,
      );
    }

    final double radius = math.min(4, size.width / 2);
    final double thumbX = (progress.clamp(0.0, 1.0) * size.width).clamp(
      radius,
      size.width - radius,
    );
    canvas.drawCircle(
      Offset(thumbX, midY),
      radius,
      Paint()
        ..color = playedColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(thumbX, midY),
      radius,
      Paint()
        ..color = unplayedColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.bars != bars ||
      old.playedColor != playedColor ||
      old.unplayedColor != unplayedColor;
}
