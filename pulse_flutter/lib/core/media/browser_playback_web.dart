import 'dart:js_interop';
import 'dart:async';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'media_playback_source.dart';

final _urls = <String>{};
final _downloads = <Timer>{};
MediaPlaybackSource browserPlayback(Uint8List bytes, String mimeType) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  _urls.add(url);
  return MediaPlaybackSource.network(
    Uri.parse(url),
    release: () async {
      if (_urls.remove(url)) web.URL.revokeObjectURL(url);
    },
  );
}

/// Logout invalidates all live capabilities even if a player is still mounted.
void releaseBrowserPlayback() {
  for (final timer in _downloads) {
    timer.cancel();
  }
  _downloads.clear();
  for (final url in _urls) {
    web.URL.revokeObjectURL(url);
  }
  _urls.clear();
}

void downloadBrowserBytes(Uint8List bytes, String name) {
  final source = browserPlayback(bytes, 'application/octet-stream');
  final anchor = web.HTMLAnchorElement()
    ..href = source.uri.toString()
    ..download = name.replaceAll(RegExp(r'[\\/\x00-\x1f]'), '_');
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // Let the browser consume the capability before releasing its bytes.
  late Timer timer;
  timer = Timer(const Duration(seconds: 60), () {
    _downloads.remove(timer);
    unawaited(source.close());
  });
  _downloads.add(timer);
}
