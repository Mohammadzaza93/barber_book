import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/screens/config_error_screen.dart';
import 'package:barber_app/screens/root_gate.dart';

void main() {
  testWidgets('ConfigErrorScreen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ConfigErrorScreen()));
    await tester.pump();
    expect(find.byType(ConfigErrorScreen), findsOneWidget);
  });

  testWidgets('RootGate widget renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RootGate()));
    expect(find.byType(RootGate), findsOneWidget);
  });
}
