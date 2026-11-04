import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:barber_app/models/inventory_models.dart';
import 'package:barber_app/providers/business_tools_provider.dart';
import 'package:barber_app/providers/shop_provider.dart';
import 'package:barber_app/screens/admin/stocktake_screen.dart';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);

  InventoryItem item({
    required String id,
    required String name,
    double quantity = 0,
    double unitCost = 0,
    String unit = 'piece',
    bool active = true,
  }) =>
      InventoryItem(
        id: id,
        name: name,
        quantity: quantity,
        unitCost: unitCost,
        unit: unit,
        active: active,
        createdAt: now,
        updatedAt: now,
      );

  StocktakeLine line({
    String itemId = 'i1',
    String itemName = 'Shampoo',
    double expected = 10,
    double? counted,
    double unitCost = 2,
    bool posted = false,
    bool conflict = false,
    double? conflictQty,
    String issue = '',
  }) =>
      StocktakeLine(
        itemId: itemId,
        itemName: itemName,
        unitCost: unitCost,
        expectedQty: expected,
        countedQty: counted,
        posted: posted,
        conflict: conflict,
        conflictQty: conflictQty,
        issue: issue,
      );

  group('stocktake model', () {
    test('variance is counted minus expected and only for counted lines', () {
      expect(line(expected: 10).variance, 0);
      expect(line(expected: 10).isCounted, isFalse);
      expect(line(expected: 10, counted: 7).variance, -3);
      expect(line(expected: 10, counted: 13, unitCost: 2.5).varianceValue,
          closeTo(7.5, 0.0001));
      expect(line(expected: 10, counted: 10).hasVariance, isFalse);
      expect(line(expected: 10, counted: 10.00001).hasVariance, isFalse);
      expect(line(expected: 10, counted: 10.5).hasVariance, isTrue);
    });

    test('session totals ignore uncounted lines and split gains/losses', () {
      final session = Stocktake(
        id: 'st1',
        lines: [
          line(itemId: 'a', counted: 12, unitCost: 2), // +4
          line(itemId: 'b', counted: 7, unitCost: 3), // -9
          line(itemId: 'c'), // uncounted
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(session.itemCount, 3);
      expect(session.countedCount, 2);
      expect(session.uncountedCount, 1);
      expect(session.varianceCount, 2);
      expect(session.totalGainValue, closeTo(4, 0.0001));
      expect(session.totalLossValue, closeTo(9, 0.0001));
      expect(session.totalVarianceValue, closeTo(-5, 0.0001));
      expect(session.canPost, isTrue);
      expect(session.allCountedPosted, isFalse);
    });

    test('a completed session cannot be posted again', () {
      final session = Stocktake(
        id: 'st1',
        status: StocktakeStatus.completed,
        lines: [line(counted: 9)],
        createdAt: now,
        updatedAt: now,
        postedAt: now,
      );

      expect(session.isCompleted, isTrue);
      expect(session.isOpen, isFalse);
      expect(session.canPost, isFalse);
    });

    test('only draft and cancelled sessions are deletable', () {
      Stocktake sessionOf(StocktakeStatus status) => Stocktake(
            id: 'st1',
            status: status,
            createdAt: now,
            updatedAt: now,
          );

      expect(sessionOf(StocktakeStatus.draft).isDeletable, isTrue);
      expect(sessionOf(StocktakeStatus.cancelled).isDeletable, isTrue);
      expect(sessionOf(StocktakeStatus.posting).isDeletable, isFalse);
      expect(sessionOf(StocktakeStatus.completed).isDeletable, isFalse);
    });

    test('serializes and restores every field, including null counts', () {
      final session = Stocktake(
        id: 'st1',
        status: StocktakeStatus.posting,
        note: 'جرد الشهر',
        lines: [
          line(counted: 8, posted: true),
          line(itemId: 'i2', expected: 4, conflict: true, conflictQty: 5),
        ],
        createdAt: now,
        createdBy: 'owner',
        updatedAt: now.add(const Duration(minutes: 5)),
        postedAt: now.add(const Duration(minutes: 6)),
        postedBy: 'owner',
      );

      final restored = Stocktake.fromMap('st1', session.toMap());

      expect(restored.status, StocktakeStatus.posting);
      expect(restored.note, 'جرد الشهر');
      expect(restored.createdBy, 'owner');
      expect(restored.postedBy, 'owner');
      expect(restored.lines, hasLength(2));
      expect(restored.lines.first.countedQty, 8);
      expect(restored.lines.first.posted, isTrue);
      expect(restored.lines.last.countedQty, isNull);
      expect(restored.lines.last.conflict, isTrue);
      expect(restored.lines.last.conflictQty, 5);
      expect(restored.createdAt, now);
      expect(restored.postedAt, now.add(const Duration(minutes: 6)));
    });

    test('unknown status falls back to draft', () {
      expect(stocktakeStatusFromName('bogus'), StocktakeStatus.draft);
      expect(stocktakeStatusFromName(null), StocktakeStatus.draft);
      expect(stocktakeStatusFromName('completed'), StocktakeStatus.completed);
    });

    test('post result is only a success when completed with no issues', () {
      const completed = StocktakePostResult(
        stocktakeId: 'st1',
        posted: 3,
        conflicts: 0,
        failed: 0,
        completed: true,
      );
      const withConflict = StocktakePostResult(
        stocktakeId: 'st1',
        posted: 2,
        conflicts: 1,
        failed: 0,
        completed: false,
      );

      expect(completed.isSuccess, isTrue);
      expect(completed.hasIssues, isFalse);
      expect(withConflict.isSuccess, isFalse);
      expect(withConflict.hasIssues, isTrue);
    });
  });

  group('stocktake provider', () {
    test('startStocktake snapshots only active items, sorted by name',
        () async {
      String? savedShop;
      Stocktake? saved;
      final tools = BusinessToolsProvider(
        saveStocktake: (shopId, stocktake) async {
          savedShop = shopId;
          saved = stocktake;
        },
      );
      tools.bindForTest('shop-A');
      tools.inventory = [
        item(id: 'i1', name: 'Shampoo', quantity: 4, unitCost: 2.5),
        item(id: 'i2', name: 'Retired', quantity: 9, active: false),
        item(id: 'i3', name: 'Dye', quantity: 1.5, unitCost: 10, unit: 'box'),
      ];

      final session = await tools.startStocktake(
        note: '  جرد الشهر  ',
        actorId: 'owner',
      );

      expect(savedShop, 'shop-A');
      expect(saved, isNotNull);
      expect(session.note, 'جرد الشهر');
      expect(session.createdBy, 'owner');
      expect(session.status, StocktakeStatus.draft);
      expect(session.lines.map((l) => l.itemName), ['Dye', 'Shampoo']);
      expect(session.lines.map((l) => l.itemId), ['i3', 'i1']);
      expect(session.lines.first.expectedQty, 1.5);
      expect(session.lines.first.unitCost, 10);
      expect(session.lines.first.unit, 'box');
      expect(session.lines.every((l) => l.countedQty == null), isTrue);
      expect(tools.stocktakeById(session.id), isNotNull);
    });

    test('startStocktake refuses an empty active inventory', () async {
      var saved = false;
      final tools = BusinessToolsProvider(
        saveStocktake: (_, __) async => saved = true,
      );
      tools.bindForTest('shop-A');
      tools.inventory = [item(id: 'i1', name: 'Retired', active: false)];

      await expectLater(
        tools.startStocktake(),
        throwsA(isA<StateError>()),
      );
      expect(saved, isFalse);
    });

    test('startStocktake refuses an unbound shop', () async {
      final tools = BusinessToolsProvider(
        saveStocktake: (_, __) async {},
      );
      tools.inventory = [item(id: 'i1', name: 'Shampoo')];

      await expectLater(
        tools.startStocktake(),
        throwsA(isA<StateError>()),
      );
    });

    test('saveStocktakeCounts forwards one write with the counted map',
        () async {
      Map<String, double?>? sent;
      final tools = BusinessToolsProvider(
        saveStocktakeCounts: ({
          required String shopId,
          required String stocktakeId,
          required Map<String, double?> counts,
        }) async {
          expect(shopId, 'shop-A');
          expect(stocktakeId, 'st1');
          sent = counts;
          return Stocktake(
            id: stocktakeId,
            lines: [line(counted: counts['i1'])],
            createdAt: now,
            updatedAt: now,
          );
        },
      );
      tools.bindForTest('shop-A');

      await tools.saveStocktakeCounts('st1', {'i1': 7, 'i2': null});

      expect(sent, {'i1': 7, 'i2': null});
      expect(tools.stocktakeById('st1'), isNotNull);
    });

    test('postStocktake surfaces per-line conflicts instead of success',
        () async {
      final conflicts = StocktakePostResult(
        stocktakeId: 'st1',
        posted: 1,
        conflicts: 2,
        failed: 0,
        completed: false,
        session: Stocktake(
          id: 'st1',
          status: StocktakeStatus.posting,
          lines: [
            line(counted: 7, posted: true),
            line(itemId: 'i2', conflict: true, conflictQty: 5),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      );
      final tools = BusinessToolsProvider(
        postStocktake: ({
          required String shopId,
          required String stocktakeId,
          String? actorId,
        }) async {
          expect(shopId, 'shop-A');
          expect(stocktakeId, 'st1');
          expect(actorId, 'owner');
          return conflicts;
        },
      );
      tools.bindForTest('shop-A');

      final result = await tools.postStocktake('st1', actorId: 'owner');

      expect(result.isSuccess, isFalse);
      expect(result.conflicts, 2);
      expect(tools.stocktakeById('st1')?.status, StocktakeStatus.posting);
    });

    test('deleteStocktake refuses a posted audit record', () async {
      var deleted = false;
      final tools = BusinessToolsProvider(
        deleteStocktake: (_, __) async => deleted = true,
      );
      tools.bindForTest('shop-A');
      final session = Stocktake(
        id: 'st1',
        status: StocktakeStatus.completed,
        lines: [line(counted: 7, posted: true)],
        createdAt: now,
        updatedAt: now,
      );

      await expectLater(
        tools.deleteStocktake(session),
        throwsA(isA<StateError>()),
      );
      expect(deleted, isFalse);
    });

    test('deleteStocktake refuses a session still posting', () async {
      var deleted = false;
      final tools = BusinessToolsProvider(
        deleteStocktake: (_, __) async => deleted = true,
      );
      tools.bindForTest('shop-A');
      final session = Stocktake(
        id: 'st1',
        status: StocktakeStatus.posting,
        lines: [line(counted: 7)],
        createdAt: now,
        updatedAt: now,
      );

      await expectLater(
        tools.deleteStocktake(session),
        throwsA(isA<StateError>()),
      );
      expect(deleted, isFalse);
    });

    test('cancelStocktake only closes an open session', () async {
      Stocktake? saved;
      final tools = BusinessToolsProvider(
        saveStocktake: (_, session) async => saved = session,
      );
      tools.bindForTest('shop-A');
      final draft = Stocktake(
        id: 'st1',
        lines: [line(counted: 7)],
        createdAt: now,
        updatedAt: now,
      );

      final cancelled = await tools.cancelStocktake(draft);

      expect(cancelled.status, StocktakeStatus.cancelled);
      expect(saved?.status, StocktakeStatus.cancelled);

      await expectLater(
        tools.cancelStocktake(cancelled),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('stocktake screen', () {
    Future<void> pumpDetail(
      WidgetTester tester,
      BusinessToolsProvider tools,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BusinessToolsProvider>.value(value: tools),
            ChangeNotifierProvider<ShopProvider>(
              create: (_) => ShopProvider(
                watchSettings: (_) => const Stream.empty(),
                watchServices: (_) => const Stream.empty(),
                watchEmployees: (_) => const Stream.empty(),
              ),
            ),
          ],
          child: const MaterialApp(
            home: StocktakeDetailScreen(stocktakeId: 'st1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('variance updates live as the counted quantity is typed',
        (tester) async {
      final tools = BusinessToolsProvider();
      tools.bindForTest('shop-A');
      tools.stocktakes = [
        Stocktake(
          id: 'st1',
          lines: [
            const StocktakeLine(
              itemId: 'i1',
              itemName: 'Shampoo',
              expectedQty: 10,
              unitCost: 2,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await pumpDetail(tester, tools);

      expect(find.text('لم يُعد'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '7');
      await tester.pump();

      // لا يظهر الفرق من النموذج المحفوظ (لم يُحفظ بعد)، بل من النص المكتوب.
      expect(find.textContaining('-3 piece'), findsOneWidget);
      expect(find.textContaining('-6.00'), findsOneWidget);
    });

    testWidgets('invalid input is flagged instead of showing a fake variance',
        (tester) async {
      final tools = BusinessToolsProvider();
      tools.bindForTest('shop-A');
      tools.stocktakes = [
        Stocktake(
          id: 'st1',
          lines: [
            const StocktakeLine(
              itemId: 'i1',
              itemName: 'Shampoo',
              expectedQty: 10,
              unitCost: 2,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await pumpDetail(tester, tools);

      await tester.enterText(find.byType(TextField), '1..2');
      await tester.pump();

      expect(find.text('كمية غير صالحة'), findsOneWidget);
      expect(find.text('لم يُعد'), findsOneWidget);
    });
  });
}
