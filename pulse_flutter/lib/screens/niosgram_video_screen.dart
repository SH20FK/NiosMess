import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/api_constants.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/media/m3_video_controls.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens one feed video only after the user chooses it.
class NiosgramVideoScreen extends ConsumerStatefulWidget {
  const NiosgramVideoScreen({required this.url, super.key});
  final String url;

  @override
  ConsumerState<NiosgramVideoScreen> createState() =>
      _NiosgramVideoScreenState();
}

class _NiosgramVideoScreenState extends ConsumerState<NiosgramVideoScreen> {
  VideoPlayerController? _controller;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      authProvider.select((s) => (s.session?.userId, s.session?.accessToken)),
      (before, after) {
        if (before == after) return;
        _generation++;
        final controller = _controller;
        _controller = null;
        if (controller != null) unawaited(controller.dispose());
        if (mounted) setState(() => _failed = true);
      },
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    final resolved = ApiConstants.resolve(widget.url);
    final uri = Uri.tryParse(resolved);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    // Feed media is public; a decoder may follow redirects, so it must never
    // receive the account bearer token for these URLs.
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    controller.addListener(() {
      if (mounted &&
          generation == _generation &&
          controller.value.hasError &&
          !_failed) {
        setState(() => _failed = true);
      }
    });
    try {
      await controller.initialize();
      if (!mounted || generation != _generation) return;
      setState(() {});
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _generation++;
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.niosgramVideoTitle)),
      body: Center(
        child: _failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.niosgramVideoUnavailable),
                  TextButton(
                    onPressed: () async {
                      final uri = Uri.tryParse(
                        ApiConstants.resolve(widget.url),
                      );
                      if (uri != null &&
                          (uri.scheme == 'https' || uri.scheme == 'http') &&
                          uri.host.isNotEmpty &&
                          uri.userInfo.isEmpty) {
                        try {
                          if (await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          )) {
                            return;
                          }
                        } catch (_) {}
                      }
                      if (context.mounted) {
                        AppToast.showError(
                          context,
                          context.l10n.niosgramVideoUnavailable,
                        );
                      }
                    },
                    child: Text(context.l10n.niosgramOpenVideoExternal),
                  ),
                ],
              )
            : controller == null || !controller.value.isInitialized
            ? const AppLoadingIndicator()
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: M3VideoPlaybackBar(controller: controller),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
