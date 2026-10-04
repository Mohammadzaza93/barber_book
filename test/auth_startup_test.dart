import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/providers/auth_provider.dart';
import 'package:barber_app/services/firebase_status.dart';
import 'package:barber_app/services/notification_service.dart';

/// Guards the startup crash reported as
/// `[core/no-app] No Firebase App '[DEFAULT]' has been created`.
///
/// `BarberApp` builds every provider eagerly, and those providers used to
/// resolve `FirebaseAuth.instance` in a field initializer. With no app
/// initialized that threw while the tree was building, so the config error
/// screen could never render.
void main() {
  test('AuthProvider constructs without an initialized Firebase app', () {
    firebaseReady = false;
    expect(() => AuthProvider(), returnsNormally);
  });

  test('services can be referenced without an initialized Firebase app', () {
    firebaseReady = false;
    expect(() => NotificationService.instance, returnsNormally);
  });
}