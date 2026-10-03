import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/firebase_status.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    DefaultFirebaseOptions.requireConfigured();
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
    // Logged so `adb logcat` shows whether Firebase came up, rather than the
    // user having to infer it from whether a screen appeared.
    developer.log('Firebase initialized for '
        '${DefaultFirebaseOptions.platformName}', name: 'firebase-init');
  } catch (e, stack) {
    firebaseReady = false;
    firebaseError = e.toString();
    developer.log('Firebase initialization FAILED: $e', name: 'firebase-init');
    developer.log('$stack', name: 'firebase-init', level: 1000);
  }
  if (firebaseReady) {
    try {
      await NotificationService.instance.init();
    } catch (_) {}
  }
  runApp(const BarberApp());
}
