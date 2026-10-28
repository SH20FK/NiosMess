import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:video_player/video_player.dart';

/// Shared playback controls for the chat gallery and the feed video viewer.
class M3VideoPlaybackBar extends StatelessWidget {
  const M3VideoPlaybackBar({
    required this.controller,
    this.onFullscreen,
    this.isFullscreen = false,
    super.key,
  });

  final VideoPlayerController controller;
  final VoidCallback? onFullscreen;
  final bool isFullscreen;

  String _time(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 359999);
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final max = value.duration.inMilliseconds.toDouble();
        final position = value.position.inMilliseconds.toDouble().clamp(
          0.0,
          max > 0 ? max : 1.0,
        );
        final play = IconButton.filled(
          tooltip: value.isPlaying
              ? context.l10n.filePreviewPause
              : context.l10n.filePreviewPlay,
          onPressed: () async {
            if (value.isPlaying) {
              await controller.pause();
            } else {
              if (value.duration > Duration.zero &&
                  value.position >= value.duration) {
                await controller.seekTo(Duration.zero);
              }
              await controller.play();
            }
          },
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : M3Durations.short2,
            switchInCurve: M3SpringCurves.expressiveDecel,
            switchOutCurve: M3SpringCurves.expressiveDecel,
            child: Icon(
              value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(value.isPlaying),
            ),
          ),
        );
        final time = Text(
          '${_time(value.position)} / ${_time(value.duration)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
        final slider = Semantics(
          label: context.l10n.mediaPlaybackPosition,
          child: Slider(
            value: position,
            max: max > 0 ? max : 1,
            onChanged: max > 0
                ? (milliseconds) => controller.seekTo(
                    Duration(milliseconds: milliseconds.round()),
                  )
                : null,
          ),
        );
        final speed = MenuAnchor(
          menuChildren: [
            for (final rate in const [
              0.25,
              0.5,
              0.75,
              1.0,
              1.25,
              1.5,
              1.75,
              2.0,
            ])
              MenuItemButton(
                onPressed: () => controller.setPlaybackSpeed(rate),
                leadingIcon: Icon(
                  value.playbackSpeed == rate
                      ? Icons.check_rounded
                      : Icons.speed_rounded,
                ),
                child: Text(
                  '${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}×',
                ),
              ),
          ],
          builder: (context, menu, _) => IconButton(
            tooltip: context.l10n.mediaPlaybackSpeed,
            onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            icon: const Icon(Icons.speed_rounded),
          ),
        );
        final fullscreen = onFullscreen == null
            ? const SizedBox.shrink()
            : IconButton(
                tooltip: isFullscreen
                    ? context.l10n.mediaExitFullscreen
                    : context.l10n.mediaEnterFullscreen,
                onPressed: onFullscreen,
                icon: Icon(
                  isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                ),
              );
        final mute = IconButton(
          tooltip: value.volume == 0
              ? context.l10n.mediaUnmute
              : context.l10n.mediaMute,
          onPressed: () => controller.setVolume(value.volume == 0 ? 1 : 0),
          icon: Icon(
            value.volume == 0
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
          ),
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(26),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 420 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.5) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        play,
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: time,
                          ),
                        ),
                        speed,
                        mute,
                        fullscreen,
                      ],
                    ),
                    slider,
                  ],
                );
              }
              return Row(
                children: [
                  play,
                  Expanded(child: slider),
                  time,
                  speed,
                  mute,
                  fullscreen,
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Used inside Chewie; tapping the video toggles only the control surface.
class M3VideoOverlayControls extends StatefulWidget {
  const M3VideoOverlayControls({
    required this.controller,
    this.onVisibilityChanged,
    super.key,
  });

  final VideoPlayerController controller;
  final ValueChanged<bool>? onVisibilityChanged;

  @override
  State<M3VideoOverlayControls> createState() => _M3VideoOverlayControlsState();
}

class _M3VideoOverlayControlsState extends State<M3VideoOverlayControls> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    final chewie = ChewieController.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            button: true,
            label: _visible
                ? context.l10n.mediaHideControls
                : context.l10n.mediaShowControls,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                onTap: () {
                  setState(() => _visible = !_visible);
                  widget.onVisibilityChanged?.call(_visible);
                },
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              curve: M3SpringCurves.expressiveDecel,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : M3Durations.short3,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: M3VideoPlaybackBar(
                    controller: widget.controller,
                    onFullscreen: chewie.toggleFullScreen,
                    isFullscreen: chewie.isFullScreen,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
