// Generated manually from existing platform config files in the repo.
// Verify values if you change Firebase project settings.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured in this file.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBT_hBtq7g6cOHNqej_UD3DgIsvV8tKHrg',
    appId: '1:428310411419:android:3c47a77b79db9d82186e3e',
    messagingSenderId: '428310411419',
    projectId: 'hishab-pro-new',
    storageBucket: 'hishab-pro-new.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAmiaU7Dm23-u7XmE1McUrYNQHcyeu6OVc',
    appId: '1:428310411419:ios:15e5ab483d05ce58186e3e',
    messagingSenderId: '428310411419',
    projectId: 'hishab-pro-new',
    storageBucket: 'hishab-pro-new.firebasestorage.app',
    iosBundleId: 'com.Ranat.hishab-pro',
  );
}
