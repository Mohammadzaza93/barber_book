// IMPORTANT:
// This file is a placeholder. Run the Firebase CLI to generate the real file:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// It will overwrite this file with your Firebase project options
// (apiKey, appId, messagingSenderId, projectId, storageBucket, ...).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDOyYgnAkz0HjDK3jZW6imW3TyEUX-KoDU',
    appId: '1:21464729425:android:aba5121a2d77be6b813570',
    messagingSenderId: '21464729425',
    projectId: 'barber-book-lycb',
    storageBucket: 'barber-book-lycb.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCfdPmDhqZe-CQZ8uwvG94czXCaEl0kW5s',
    appId: '1:21464729425:ios:535741cd5b1d9d9e813570',
    messagingSenderId: '21464729425',
    projectId: 'barber-book-lycb',
    storageBucket: 'barber-book-lycb.firebasestorage.app',
    iosBundleId: 'com.barberbook.barberbook',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );
}
