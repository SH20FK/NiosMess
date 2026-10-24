import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool _installed = false;
void installNotificationBridge(
  void Function(Map<String, dynamic>) onClick,
  void Function(Map<String, dynamic>) onMessage,
) {
  if (_installed) return;
  _installed = true;
  web.window.navigator.serviceWorker.addEventListener(
    'message',
    ((web.MessageEvent event) {
      final value = event.data.dartify();
      if (value is! Map || value['data'] is! Map) return;
      final data = Map<String, dynamic>.from(value['data'] as Map);
      if (value['type'] == 'niosmess_notification_click') onClick(data);
      if (value['type'] == 'niosmess_notification_message') onMessage(data);
    }).toJS,
  );
}

Future<void> syncNotificationWorker(Map<String, dynamic> settings) async {
  // Do not initialize another notification plugin's service worker or overwrite
  // navigator.serviceWorker.onmessage. FCM owns this one registration.
  final registration = await web.window.navigator.serviceWorker
      .register(
        'firebase-messaging-sw.js'.toJS,
        web.RegistrationOptions(scope: '/firebase-cloud-messaging-push-scope'),
      )
      .toDart;
  final worker =
      registration.active ?? registration.waiting ?? registration.installing;
  worker?.postMessage(
    {
      'type': 'niosmess_notification_settings',
      'data': {...settings, 'ready': _installed},
    }.jsify(),
  );
}
