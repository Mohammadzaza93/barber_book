import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// PHASE 4.3 regression coverage.
///
/// The admin business tools screens previously rendered hard-coded Arabic even
/// when the app locale was English. These tests lock the localization layer the
/// screens now depend on:
///  * every user-facing key exists in BOTH `app_en.arb` and `app_ar.arb`;
///  * no key resolves to an empty string in either locale;
///  * multi-placeholder messages interpolate their arguments in the declared
///    order (the source of the earlier positional-argument bug);
///  * translated labels actually differ between Arabic and English.
void main() {
  Map<String, dynamic> readArb(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  /// Translation keys only (drop `@@locale`, `@@last_modified` and `@meta`).
  Set<String> translationKeys(Map<String, dynamic> arb) =>
      arb.keys.where((key) => !key.startsWith('@')).toSet();

  group('ARB resource parity (PH4.3-L10N)', () {
    late Map<String, dynamic> en;
    late Map<String, dynamic> ar;

    setUpAll(() {
      en = readArb('lib/l10n/app_en.arb');
      ar = readArb('lib/l10n/app_ar.arb');
    });

    test('English and Arabic define the exact same translation keys', () {
      final enKeys = translationKeys(en);
      final arKeys = translationKeys(ar);
      expect(arKeys.difference(enKeys), isEmpty,
          reason: 'Arabic defines keys missing from English');
      expect(enKeys.difference(arKeys), isEmpty,
          reason: 'English defines keys missing from Arabic');
    });

    test('no translation value is empty in either locale', () {
      for (final locale in [en, ar]) {
        for (final key in translationKeys(locale)) {
          expect((locale[key] as String).trim(), isNotEmpty,
              reason: 'empty translation for "$key"');
        }
      }
    });

    test('multi-placeholder messages declare matching placeholders', () {
      for (final key in translationKeys(en)) {
        final meta = en['@$key'];
        if (meta is! Map || meta['placeholders'] == null) continue;
        final declared = (meta['placeholders'] as Map).keys.toSet();
        final arMeta = ar['@$key'];
        expect(arMeta, isA<Map>(),
            reason: 'Arabic is missing metadata for "$key"');
        final arDeclared = (arMeta['placeholders'] as Map).keys.toSet();
        expect(arDeclared, equals(declared),
            reason: 'placeholder mismatch for "$key"');
      }
    });
  });

  group('migrated admin strings resolve in both locales (PH4.3-L10N)', () {
    late AppLocalizations en;
    late AppLocalizations ar;

    setUpAll(() async {
      en = await AppLocalizations.delegate.load(const Locale('en'));
      ar = await AppLocalizations.delegate.load(const Locale('ar'));
    });

    test('key tab and section labels differ between locales', () {
      expect(en.addCustomer, isNot(equals(ar.addCustomer)));
      expect(en.metricTotalCustomers, isNot(equals(ar.metricTotalCustomers)));
      expect(en.sectionEarningRules, isNot(equals(ar.sectionEarningRules)));
      expect(en.sectionChairSupplies, isNot(equals(ar.sectionChairSupplies)));
      expect(en.metricWeekProfit, isNot(equals(ar.metricWeekProfit)));
      expect(en.menuEditProfile, isNot(equals(ar.menuEditProfile)));
    });

    test('customerSummary interpolates all eight arguments in order', () {
      final result = ar.customerSummary(
          'PHONE', 'STATUS', 'VISITS', 'LAST', 'AVG', 'TIME', 'SERVICES', 'BARBER');
      for (final value in [
        'PHONE', 'STATUS', 'VISITS', 'LAST', 'AVG', 'TIME', 'SERVICES', 'BARBER',
      ]) {
        expect(result, contains(value));
      }
      expect(result.indexOf('PHONE'), lessThan(result.indexOf('STATUS')));
      expect(result.indexOf('STATUS'), lessThan(result.indexOf('VISITS')));
    });

    test('chairReportSummary interpolates all four arguments', () {
      final result = en.chairReportSummary('VISITS', 'UTIL', 'REVENUE', 'MATERIALS');
      expect(result, contains('VISITS'));
      expect(result, contains('UTIL'));
      expect(result, contains('REVENUE'));
      expect(result, contains('MATERIALS'));
    });

    test('ruleSummary and giftSummary interpolate their arguments', () {
      final rule = en.ruleSummary('PPV', 'PPC', 'DAYS');
      expect(rule, contains('PPV'));
      expect(rule, contains('PPC'));
      expect(rule, contains('DAYS'));

      final gift = ar.giftSummary('POINTS', 'TIER', 'STOCK');
      expect(gift, contains('POINTS'));
      expect(gift, contains('TIER'));
      expect(gift, contains('STOCK'));
    });

    test('single-placeholder messages interpolate their argument', () {
      expect(ar.giftStockUsed('REDEEMED', 'STOCK'), contains('REDEEMED'));
      expect(ar.giftStockUsed('REDEEMED', 'STOCK'), contains('STOCK'));
      expect(en.loyaltyAccountSubtitle('PHONE', 'TIER'), contains('PHONE'));
      expect(en.redeemGiftTitle('GIFT'), contains('GIFT'));
      expect(en.pointsAmount('42'), contains('42'));
      expect(en.dueGifts('A, B'), contains('A, B'));
      expect(en.chairAssignedBarber('BARBER'), contains('BARBER'));
      expect(ar.chairProfitTitle('CHAIR', 'DATE'), contains('CHAIR'));
      expect(ar.chairProfitTitle('CHAIR', 'DATE'), contains('DATE'));
      expect(en.chairProfitRevenue('REV', 'MAT'), contains('MAT'));
      expect(ar.daysCount('7'), contains('7'));
    });
  });
}
