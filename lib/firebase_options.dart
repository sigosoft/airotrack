// File generated manually from android/app/google-services.json.
// Prefer regenerating with: flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS. '
          'Run flutterfire configure to add iOS.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA2gnFWXfFn_x135H86Hzyt1oNnkd6m9Xc',
    appId: '1:521325798783:android:8319344172fca2f457e64a',
    messagingSenderId: '521325798783',
    projectId: 'airotrack-b67c4',
    storageBucket: 'airotrack-b67c4.firebasestorage.app',
  );
}
