import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:barber_app/providers/language_provider.dart';
import 'package:barber_app/widgets/confirm.dart';

/// PHASE 4 regression coverage.
///
/// Two confirmed client defects are locked here:
///  * `confirmDialog` rendered hard-coded English "Cancel"/"Confirm" even in the
///    Arabic UI because the defaults ignored the localization layer.
///    (lib/widgets/confirm.dart)
///  * `DateFormat` always resolved to en_US because `Intl.defaultLocale` was
///    never set, so Arabic screens rendered English dates.
///    (lib/providers/language_provider.dart, lib/main.dart)

void main() {
  group('confirmDialog localization (PH4-L10N-001)', () {
    testWidgets('English locale shows English default buttons',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => confirmDialog(context, title: 'T'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('Arabic locale localizes the default buttons', (tester) async {
      final ar = await AppLocalizations.delegate.load(const Locale('ar'));
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => confirmDialog(context, title: 'T'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(ar.cancel), findsOneWidget);
      expect(find.text(ar.confirm), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });
  });

  group('LanguageProvider drives Intl.defaultLocale (PHASE4-LOCALE)', () {
    setUpAll(() async {
      // Loads the locale data DateFormat needs; without it DateFormat falls back
      // to en_US for every locale, which is the defect being guarded here.
      await initializeDateFormatting();
    });

    test('load() applies the persisted language to Intl', () async {
      // No SharedPreferences binding in a pure unit test: load() catches the
      // missing platform and falls back to the Arabic default, which is exactly
      // the behaviour we want to lock for a fresh install.
      final provider = LanguageProvider();
      await provider.load();
      expect(provider.locale.languageCode, 'ar');
      expect(Intl.defaultLocale, 'ar');
    });

    test('setLocale() switches Intl formatting language', () async {
      final provider = LanguageProvider();
      await provider.setLocale(const Locale('en'));
      expect(Intl.defaultLocale, 'en');
      await provider.setLocale(const Locale('ar'));
      expect(Intl.defaultLocale, 'ar');
    });

    test('dates format in Arabic once the locale is applied', () {
      Intl.defaultLocale = 'ar';
      final formatted = DateFormat.yMMMM().format(DateTime(2026, 1, 15));
      final english = DateFormat.yMMMM('en').format(DateTime(2026, 1, 15));
      expect(formatted, isNot(equals(english)));
      expect(formatted.contains('يناير'), isTrue);
    });
  });
}
