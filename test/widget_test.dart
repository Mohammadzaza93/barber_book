import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/app.dart';

void main() {
  testWidgets('BarberApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const BarberApp());
    await tester.pump();
    expect(find.byType(BarberApp), findsOneWidget);
  });
}
