import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:barber_app/screens/config_error_screen.dart';

void main() {
  testWidgets('ConfigErrorScreen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        supportedLocales: [Locale('ar'), Locale('en')],
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ConfigErrorScreen(),
      ),
    );
    await tester.pump();
    expect(find.byType(ConfigErrorScreen), findsOneWidget);
  });
}
