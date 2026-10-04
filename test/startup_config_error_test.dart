import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/app.dart';
import 'package:barber_app/screens/config_error_screen.dart';
import 'package:barber_app/services/firebase_status.dart';

/// Regression test for the startup crash reported as
/// `[core/no-app] No Firebase App '[DEFAULT]' has been created`.
///
/// This file deliberately does NOT call `Firebase.initializeApp`, so it
/// reproduces the state `main()` lands in when initialization throws. Before
/// the fix, `BarberApp` resolved `FirebaseAuth.instance` in a field
/// initializer while building its providers, which threw inside the widget
/// build and took down the whole app instead of showing the config error screen.
void main() {
  testWidgets('BarberApp shows the config error screen when Firebase failed',
      (WidgetTester tester) async {
    firebaseReady = false;
    firebaseError = 'simulated initialization failure';

    await tester.pumpWidget(const BarberApp());
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'building the tree must not throw without a Firebase app');
    expect(find.byType(ConfigErrorScreen), findsOneWidget);
    expect(find.textContaining('simulated initialization failure'),
        findsWidgets);
  });
}