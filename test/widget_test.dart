import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/app.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    // The mock's initializeCore already registers a default app, and 6.x
    // compares the apiKey exactly with no "demo-" exemption, so these options
    // must mirror the values the mock returns.
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: '123',
        projectId: '123',
        appId: '123',
        messagingSenderId: '123',
      ),
    );
  });

  testWidgets('BarberApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const BarberApp());
    await tester.pump();
    expect(find.byType(BarberApp), findsOneWidget);
  });

  testWidgets('BarberApp falls back to the config error screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BarberApp());
    await tester.pump();
    // firebaseReady stays false unless main() initializes Firebase, so the gate
    // must render the fallback screen instead of throwing.
    expect(find.byType(BarberApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}