import 'dart:typed_data';
import 'media_playback_source.dart';

MediaPlaybackSource browserPlayback(Uint8List bytes, String mimeType) =>
    throw UnsupportedError('Browser playback is unavailable on this platform');
void releaseBrowserPlayback() {}
void downloadBrowserBytes(Uint8List bytes, String name) =>
    throw UnsupportedError('Browser download is unavailable on this platform');
