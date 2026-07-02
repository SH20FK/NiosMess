import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAgIlq9dix4DYlLBNUF4eqsofZqh_uItUI',
    appId: '1:31725064203:android:326bc0c2a61a2aa482370e',
    messagingSenderId: '31725064203',
    projectId: 'niosmess',
    storageBucket: 'niosmess.firebasestorage.app',
  );
}
