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

  /// True when [options] are still the unedited placeholders that
  /// `flutterfire configure` leaves behind.
  ///
  /// Passing those to `Firebase.initializeApp` produces an opaque platform
  /// error, so the app detects them and reports which platform is missing.
  static bool isPlaceholder(FirebaseOptions options) =>
      options.apiKey.startsWith('YOUR_') ||
      options.projectId.startsWith('YOUR_') ||
      options.appId.startsWith('YOUR_');

  /// Platform label used in diagnostics.
  static String get platformName =>
      kIsWeb ? 'web' : defaultTargetPlatform.name;

  /// Throws a descriptive [UnsupportedError] when the current platform has no
  /// real Firebase configuration.
  static void requireConfigured() =>
      requireConfiguredFor(currentPlatform, platformName: platformName);

  /// Same as [requireConfigured] but for an explicit target, so the check can
  /// be exercised for platforms this test host does not run on.
  static void requireConfiguredFor(
      FirebaseOptions options, {required String platformName}) {
    if (!isPlaceholder(options)) return;
    throw UnsupportedError(
      'Firebase is not configured for $platformName. This build of '
      'firebase_options.dart still contains placeholders. Run '
      '"flutterfire configure" to generate the real values for project '
      'barber-book-lycb.',
    );
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