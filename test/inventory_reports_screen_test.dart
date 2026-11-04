import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:barber_app/models/inventory_models.dart';
import 'package:barber_app/providers/business_tools_provider.dart';
import 'package:barber_app/providers/shop_provider.dart';
import 'package:barber_app/screens/admin/inventory_reports_screen.dart';

void main() {
  final now = DateTime.now();
  final item = InventoryItem(
    id: 'i1',
    name: 'شامبو',
    quantity: 10,
    unitCost: 5,
    reorderLevel: 3,
    createdAt: now,
    updatedAt: now,
  );

  InventoryMovement movement({
    required String id,
    required String type,
    required double quantity,
    double unitCost = 5,
    double? before,
    double? after,
  }) =>
      InventoryMovement(
        id: id,
        itemId: 'i1',
        type: type,
        quantity: quantity,
        unitCost: unitCost,
        balanceBefore: before,
        balanceAfter: after,
        createdAt: now,
      );

  Widget harness({
    required BusinessToolsProvider tools,
    required InventoryPeriodLoader loader,
  }) =>
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
        child: MaterialApp(
          home: InventoryReportsScreen(loader: loader),
        ),
      );

  testWidgets('renders period totals and movement analytics', (tester) async {
    final tools = BusinessToolsProvider()..bindForTest('shop-A');
    tools.inventory = [item];
    tools.inventoryMovements = [
      movement(id: 'p1', type: 'purchase', quantity: 10),
      movement(id: 'u1', type: 'usage', quantity: 2),
      movement(id: 'w1', type: 'waste', quantity: 1),
      movement(
        id: 'a1',
        type: 'adjustment',
        quantity: 1,
        before: 8,
        after: 9,
      ),
    ];

    await tester.pumpWidget(
      harness(
        tools: tools,
        loader: (from, to) async => tools.inventoryMovements,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ملخص الفترة'), findsOneWidget);
    expect(find.textContaining('المشتريات'), findsOneWidget);
    expect(find.textContaining('الاستهلاك'), findsOneWidget);
    expect(find.text('أكثر المواد استهلاكاً'), findsOneWidget);
    expect(find.textContaining('تسويات الجرد'), findsOneWidget);
  });

  testWidgets('reloads when another period is selected', (tester) async {
    final tools = BusinessToolsProvider()..bindForTest('shop-A');
    tools.inventory = [item];
    var calls = 0;

    await tester.pumpWidget(
      harness(
        tools: tools,
        loader: (from, to) async {
          calls++;
          return const [];
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.tap(find.text('هذا الشهر'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('لا حركات في هذه الفترة'), findsOneWidget);
  });

  testWidgets('the yearly period starts on January 1', (tester) async {
    final tools = BusinessToolsProvider()..bindForTest('shop-A');
    tools.inventory = [item];
    DateTime? capturedFrom;

    await tester.pumpWidget(
      harness(
        tools: tools,
        loader: (from, to) async {
          capturedFrom = from;
          return const [];
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('هذا العام'));
    await tester.pumpAndSettle();

    expect(capturedFrom, isNotNull);
    expect(capturedFrom!.month, 1);
    expect(capturedFrom!.day, 1);
    expect(capturedFrom!.year, DateTime.now().year);
  });

  testWidgets('shows a retry card when loading fails', (tester) async {
    final tools = BusinessToolsProvider()..bindForTest('shop-A');

    await tester.pumpWidget(
      harness(
        tools: tools,
        loader: (from, to) async => throw StateError('offline'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذّر تحميل تقرير المخزون'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });
}
