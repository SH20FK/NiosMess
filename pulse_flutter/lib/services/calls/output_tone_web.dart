import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'output_test_tone.dart';

Future<void> playOutputTest(String device) async {
  final url = web.URL.createObjectURL(
    web.Blob(
      [outputTestTone().toJS].toJS,
      web.BlobPropertyBag(type: 'audio/wav'),
    ),
  );
  final element = web.HTMLAudioElement()..src = url;
  try {
    if (device.isNotEmpty) {
      if (!element.getProperty<JSAny?>('setSinkId'.toJS).isDefinedAndNotNull) {
        throw StateError('output_not_supported');
      }
      await element
          .callMethod<JSPromise<JSAny?>>('setSinkId'.toJS, device.toJS)
          .toDart;
    }
    await element.play().toDart;
    await Future<void>.delayed(const Duration(milliseconds: 650));
  } finally {
    element.pause();
    element.removeAttribute('src');
    element.load();
    web.URL.revokeObjectURL(url);
  }
}
