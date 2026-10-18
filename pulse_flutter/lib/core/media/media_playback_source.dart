import 'dart:async';

/// An account-owned playback lease. Network URLs may be short-lived loopback
/// capabilities and must never be copied into message history or disk caches.
final class MediaPlaybackSource {
  MediaPlaybackSource.file(this.filePath) : uri = null, _release = null;
  MediaPlaybackSource.network(
    this.uri, {
    required Future<void> Function() release,
  }) : filePath = null,
       _release = release;

  final String? filePath;
  final Uri? uri;
  final Future<void> Function()? _release;
  Future<void>? _closing;

  Future<void> close() => _closing ??= _release?.call() ?? Future<void>.value();
}
