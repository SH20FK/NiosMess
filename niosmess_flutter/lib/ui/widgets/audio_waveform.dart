import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../../ui/nios_ui.dart';

class AudioWaveformPlayer extends StatefulWidget {
  final String audioPath;
  final bool isOutgoing;
  final Duration? duration;

  const AudioWaveformPlayer({
    super.key,
    required this.audioPath,
    this.isOutgoing = false,
    this.duration,
  });

  @override
  State<AudioWaveformPlayer> createState() => _AudioWaveformPlayerState();
}

class _AudioWaveformPlayerState extends State<AudioWaveformPlayer> {
  PlayerController? _playerController;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration? _totalDuration;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _playerController = PlayerController();
    
    try {
      await _playerController!.preparePlayer(
        path: widget.audioPath,
      );
      
      final durationMs = await _playerController!.getDuration();
      _totalDuration = Duration(milliseconds: durationMs);
      
      _playerController!.onCurrentDurationChanged.listen((durationMs) {
        if (mounted) {
          setState(() {
            _currentPosition = Duration(milliseconds: durationMs);
          });
        }
      });
      
      _playerController!.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
    }
  }

  @override
  void dispose() {
    _playerController?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerController == null) return;
    
    try {
      if (_isPlaying) {
        await _playerController!.pausePlayer();
      } else {
        await _playerController!.startPlayer();
      }
    } catch (e) {
      debugPrint('Error toggling playback: $e');
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final waveformColor = widget.isOutgoing 
        ? Colors.white.withValues(alpha: 0.8)
        : NiosPalette.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isOutgoing 
            ? Colors.white.withValues(alpha: 0.1)
            : NiosPalette.surfaceHover,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isOutgoing 
                    ? Colors.white.withValues(alpha: 0.2)
                    : NiosPalette.accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: waveformColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_playerController != null)
            AudioFileWaveforms(
              size: const Size(120, 30),
              playerController: _playerController!,
              waveformType: WaveformType.fitWidth,
              playerWaveStyle: PlayerWaveStyle(
                fixedWaveColor: waveformColor.withValues(alpha: 0.3),
                liveWaveColor: waveformColor,
                spacing: 4,
                waveThickness: 2,
                showSeekLine: false,
              ),
            )
          else
            Container(
              width: 120,
              height: 30,
              alignment: Alignment.center,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: waveformColor,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_isPlaying ? _currentPosition : (_totalDuration ?? widget.duration ?? Duration.zero)),
            style: TextStyle(
              fontSize: 12,
              color: waveformColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Мини-версия для списка сообщений
class AudioWaveformMini extends StatelessWidget {
  final Duration duration;
  final bool isPlaying;
  final VoidCallback onTap;
  final bool isOutgoing;

  const AudioWaveformMini({
    super.key,
    required this.duration,
    required this.isPlaying,
    required this.onTap,
    this.isOutgoing = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOutgoing 
        ? Colors.white.withValues(alpha: 0.8)
        : NiosPalette.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isOutgoing 
              ? Colors.white.withValues(alpha: 0.1)
              : NiosPalette.surfaceHover,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 6),
            // Симулированная волна
            Row(
              children: List.generate(20, (index) {
                final height = 4.0 + (index % 5) * 3.0;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 2,
                  height: height,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.5 + (index % 3) * 0.2),
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              }),
            ),
            const SizedBox(width: 6),
            Text(
              _formatDuration(duration),
              style: TextStyle(
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
