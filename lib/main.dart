import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/firebase_status.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (e) {
    firebaseReady = false;
    firebaseError = e.toString();
  }
  if (firebaseReady) {
    try {
      await NotificationService.instance.init();
    } catch (_) {}
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: appBrandBackground,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: appBrandBackground,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const BarberApp());
}
