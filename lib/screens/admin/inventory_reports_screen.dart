import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/business_features.dart';
import '../../models/inventory_catalog.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/inventory_analytics.dart';
import '../../widgets/empty_state.dart';
import 'inventory_item_screen.dart';
import 'inventory_movement_sheet.dart';

typedef InventoryPeriodLoader = Future<List<InventoryMovement>> Function(
    DateTime from, DateTime to);

/// تقارير المخزون: مشتريات، استهلاك، هدر، صافي التغيّر، مواد راكدة،
/// وتنبيهات إعادة الطلب وانتهاء الصلاحية — محسوبة محلياً من حركات الفترة.
class InventoryReportsScreen extends StatefulWidget {
  const InventoryReportsScreen({
    super.key,
    this.loader,
    this.initialPeriodIndex = 1,
  });

  /// يُستخدم في الاختبارات لتفادي Firestore.
  final InventoryPeriodLoader? loader;
  final int initialPeriodIndex;

  @override
  State<InventoryReportsScreen> createState() => _InventoryReportsScreenState();
}

const _periods = [
  ('هذا الشهر', 0),
  ('آخر 30 يوماً', 30),
  ('آخر 90 يوماً', 90),
  ('هذا العام', -1),
];

class _InventoryReportsScreenState extends State<InventoryReportsScreen> {
  late int _periodIndex;
  List<InventoryMovement>? _movements;
  bool _loading = false;
  bool _degraded = false;
  String? _error;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _periodIndex = widget.initialPeriodIndex.clamp(0, _periods.length - 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  DateTime get _from {
    final now = DateTime.now();
    final days = _periods[_periodIndex].$2;
    if (days == 0) return DateTime(now.year, now.month);
    if (days < 0) return DateTime(now.year);
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final from = _from;
    final to = DateTime.now();
    try {
      final tools = context.read<BusinessToolsProvider>();
      final list = widget.loader != null
          ? await widget.loader!(from, to)
          : await tools.loadInventoryMovements(from: from, to: to);
      if (!mounted) return;
      setState(() {
        _movements = list;
        _degraded = tools.inventoryHistoryDegraded;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _selectPeriod(int index) {
    if (index == _periodIndex) return;
    setState(() => _periodIndex = index);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final shop = context.watch<ShopProvider>();
    final currency = shop.settings?.currency ?? 'SAR';
    final items = tools.inventory;
    final movements = _movements;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير المخزون'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            _periodSelector(),
            const SizedBox(height: 10),
            if (_loading && movements != null) const LinearProgressIndicator(),
            if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else if (movements == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ..._report(
                movements: movements,
                items: items,
                currency: currency,
              ),
          ],
        ),
      ),
    );
  }

  Widget _periodSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (var i = 0; i < _periods.length; i++)
          ChoiceChip(
            label: Text(_periods[i].$1),
            selected: i == _periodIndex,
            onSelected: (_) => _selectPeriod(i),
          ),
      ],
    );
  }

  List<Widget> _report({
    required List<InventoryMovement> movements,
    required List<InventoryItem> items,
    required String currency,
  }) {
    final report = InventoryAnalytics.periodReport(
      movements: movements,
      from: _from,
      to: DateTime.now(),
    );
    final health = InventoryAnalytics.health(items);
    final restock = InventoryAnalytics.restockSuggestions(items);
    final expiring = InventoryAnalytics.expiringItems(items);
    final expired = InventoryAnalytics.expiredItems(items);
    final slow = InventoryAnalytics.slowMovingItems(
      items: items,
      movements: movements,
      from: _from,
    );
    final names = {for (final item in items) item.id: item.name};
    final restockTotal =
        restock.fold<double>(0, (sum, s) => sum + s.estimatedCost);
    final maxConsumed = report.topConsumed(1);
    final maxConsumedValue =
        maxConsumed.isEmpty ? 0.0 : maxConsumed.first.usedValue;

    return [
      Text(
        '${DateFormat('yyyy/MM/dd').format(report.from)}'
        ' — ${DateFormat('yyyy/MM/dd').format(report.to)}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      ),
      const SizedBox(height: 10),
      if (_degraded) ...[
        const _NoteCard(
          icon: Icons.cloud_off_outlined,
          message:
              'تعذّر تحميل السجل الكامل من الخادم؛ الحسابات تعتمد على الحركات '
              'المحمّلة على هذا الجهاز وقد تكون ناقصة.',
        ),
        const SizedBox(height: 10),
      ],
      _SummaryCard(report: report, health: health, currency: currency),
      if (health.needsAttention > 0) ...[
        const SizedBox(height: 12),
        _AttentionCard(health: health),
      ],
      if (restock.isNotEmpty) ...[
        const SizedBox(height: 12),
        _RestockSection(
          suggestions: restock,
          currency: currency,
          total: restockTotal,
          onPurchase: (item, quantity) => showInventoryMovementSheet(
            context,
            item: item,
            type: 'purchase',
            initialQuantity: quantity,
          ),
        ),
      ],
      if (expired.isNotEmpty) ...[
        const SizedBox(height: 12),
        _ItemsSection(
          title: 'منتهية الصلاحية',
          subtitle: 'لها رصيد وما زالت نشطة — سجّل إتلافاً',
          icon: Icons.warning_amber_rounded,
          color: Colors.red.shade700,
          items: expired,
          currency: currency,
          onTap: (item) => _openItem(item),
        ),
      ],
      if (expiring.isNotEmpty) ...[
        const SizedBox(height: 12),
        _ItemsSection(
          title: 'تنتهي خلال 30 يوماً',
          subtitle: 'رتّب الاستخدام أو الإتلاف قبل انتهائها',
          icon: Icons.schedule_rounded,
          color: Colors.orange.shade800,
          items: expiring,
          currency: currency,
          onTap: (item) => _openItem(item),
        ),
      ],
      if (report.isEmpty) ...[
        const SizedBox(height: 12),
        const EmptyState(
          icon: Icons.insights_outlined,
          title: 'لا حركات في هذه الفترة',
          subtitle:
              'سجّل شراءً أو صرفاً أو جرداً ليظهر التحليل هنا. الحركات السابقة '
              'تبقى محفوظة في سجل المادة.',
        ),
      ] else ...[
        const SizedBox(height: 12),
        _ConsumedSection(
          title: 'أكثر المواد استهلاكاً',
          icon: Icons.trending_down_rounded,
          stats: report.topConsumed(5),
          names: names,
          currency: currency,
          maxValue: maxConsumedValue,
        ),
        if (report.topWasted(1).isNotEmpty) ...[
          const SizedBox(height: 12),
          _ConsumedSection(
            title: 'أكثر المواد هدراً',
            icon: Icons.delete_sweep_outlined,
            stats: report.topWasted(5),
            names: names,
            currency: currency,
            maxValue: report.topWasted(1).first.wastedValue,
            valueOf: (s) => s.wastedValue,
            quantityOf: (s) => s.wastedQty,
            color: Colors.orange.shade800,
          ),
        ],
        if (report.topPurchased(1).isNotEmpty) ...[
          const SizedBox(height: 12),
          _ConsumedSection(
            title: 'أكثر المواد شراءً',
            icon: Icons.shopping_bag_outlined,
            stats: report.topPurchased(5),
            names: names,
            currency: currency,
            maxValue: report.topPurchased(1).first.purchasedValue,
            valueOf: (s) => s.purchasedValue,
            quantityOf: (s) => s.purchasedQty,
            color: Colors.teal.shade700,
          ),
        ],
        if (slow.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ItemsSection(
            title: 'مواد راكدة',
            subtitle: 'لها رصيد ولم تُحرَّك منذ بداية الفترة',
            icon: Icons.hourglass_empty_rounded,
            color: Colors.blueGrey,
            items: slow,
            currency: currency,
            onTap: (item) => _openItem(item),
          ),
        ],
        const SizedBox(height: 12),
        _MovementLog(
          movements: movements.take(40).toList(),
          names: names,
          currency: currency,
        ),
      ],
      const SizedBox(height: 14),
      const _NoteCard(
        icon: Icons.info_outline,
        message:
            'كل الأرقام محسوبة من حركات المخزون المسجلة. لا تُحتسب الكميات '
            'المعدّلة يدوياً خارج الحركات، لذا استخدم «جرد» لتوثيق أي فرق.',
      ),
    ];
  }

  void _openItem(InventoryItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryItemScreen(item: item),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.report,
    required this.health,
    required this.currency,
  });

  final InventoryPeriodReport report;
  final InventoryHealth health;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, String, IconData, Color)>[
      (
        'المشتريات',
        '${_money(report.purchasedValue)} $currency',
        Icons.shopping_cart_outlined,
        Colors.teal.shade700
      ),
      (
        'الاستهلاك',
        '${_money(report.usedValue)} $currency',
        Icons.content_cut_rounded,
        Colors.blue.shade700
      ),
      (
        'الهدر والتلف',
        '${_money(report.wastedValue)} $currency',
        Icons.delete_outline,
        Colors.orange.shade800
      ),
      (
        'صافي التغيّر',
        '${_money(report.netChangeValue)} $currency',
        Icons.trending_up_rounded,
        report.netChangeValue >= 0 ? Colors.green.shade700 : Colors.red.shade700
      ),
      (
        'الحركات',
        '${report.movementCount}',
        Icons.swap_vert_rounded,
        Colors.blueGrey
      ),
      (
        'قيمة المخزون الآن',
        '${_money(health.totalValue)} $currency',
        Icons.inventory_2_outlined,
        Colors.indigo,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.insights_outlined,
              title: 'ملخص الفترة',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final metric in metrics)
                      SizedBox(
                        width: width,
                        child: _Metric(
                          label: metric.$1,
                          value: metric.$2,
                          icon: metric.$3,
                          color: metric.$4,
                        ),
                      ),
                  ],
                );
              },
            ),
            if (report.adjustmentGainValue > 0 ||
                report.adjustmentLossValue > 0) ...[
              const SizedBox(height: 10),
              Text(
                'تسويات الجرد: '
                '+${_money(report.adjustmentGainValue)} / '
                '−${_money(report.adjustmentLossValue)} $currency',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.health});

  final InventoryHealth health;

  @override
  Widget build(BuildContext context) {
    final chips = <(String, int, Color)>[
      ('نافد', health.outOfStock, Colors.red.shade700),
      ('تحت الحد', health.lowStock, Colors.orange.shade800),
      ('تنتهي قريباً', health.expiringSoon, Colors.orange.shade700),
      ('منتهية', health.expired, Colors.red.shade900),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.notification_important_outlined,
              title: 'يحتاج انتباهك',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in chips)
                  if (chip.$2 > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: chip.$3.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${chip.$1}: ${chip.$2}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: chip.$3,
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RestockSection extends StatelessWidget {
  const _RestockSection({
    required this.suggestions,
    required this.currency,
    required this.total,
    required this.onPurchase,
  });

  final List<RestockSuggestion> suggestions;
  final String currency;
  final double total;
  final void Function(InventoryItem item, double quantity) onPurchase;

  @override
  Widget build(BuildContext context) {
    final shown = suggestions.take(10).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.shopping_cart_checkout_rounded,
              title: 'قائمة الشراء المقترحة',
            ),
            const SizedBox(height: 4),
            Text(
              'التكلفة التقديرية: ${_money(total)} $currency',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            for (final suggestion in shown)
              _RestockRow(
                suggestion: suggestion,
                currency: currency,
                onPurchase: () =>
                    onPurchase(suggestion.item, suggestion.quantity),
              ),
            if (suggestions.length > shown.length)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'و${suggestions.length - shown.length} مادة أخرى تحتاج شراءً.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RestockRow extends StatelessWidget {
  const _RestockRow({
    required this.suggestion,
    required this.currency,
    required this.onPurchase,
  });

  final RestockSuggestion suggestion;
  final String currency;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final item = suggestion.item;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${suggestion.reason} · اطلب '
                  '${_formatQty(suggestion.quantity)} '
                  '${inventoryUnitLabel(item.unit)} · '
                  '≈ ${_money(suggestion.estimatedCost)} $currency',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onPurchase,
            child: const Text('شراء'),
          ),
        ],
      ),
    );
  }
}

class _ConsumedSection extends StatelessWidget {
  const _ConsumedSection({
    required this.title,
    required this.icon,
    required this.stats,
    required this.names,
    required this.currency,
    required this.maxValue,
    this.valueOf,
    this.quantityOf,
    this.color,
  });

  final String title;
  final IconData icon;
  final List<ItemMovementStats> stats;
  final Map<String, String> names;
  final String currency;
  final double maxValue;
  final double Function(ItemMovementStats)? valueOf;
  final double Function(ItemMovementStats)? quantityOf;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Colors.blue.shade700;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(icon: icon, title: title),
            const SizedBox(height: 10),
            if (stats.isEmpty)
              Text(
                'لا بيانات في هذه الفترة.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              )
            else
              for (final stat in stats)
                _StatRow(
                  name: names[stat.itemId] ?? 'مادة محذوفة',
                  value: (valueOf ?? (s) => s.usedValue)(stat),
                  quantity: (quantityOf ?? (s) => s.usedQty)(stat),
                  unit: '',
                  currency: currency,
                  fraction: maxValue <= 0
                      ? 0
                      : ((valueOf ?? (s) => s.usedValue)(stat) / maxValue)
                          .clamp(0.0, 1.0),
                  color: accent,
                ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.name,
    required this.value,
    required this.quantity,
    required this.unit,
    required this.currency,
    required this.fraction,
    required this.color,
  });

  final String name;
  final double value;
  final double quantity;
  final String unit;
  final String currency;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatQty(quantity)}$unit · ${_money(value)} $currency',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
    required this.currency,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<InventoryItem> items;
  final String currency;
  final void Function(InventoryItem item) onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(icon: icon, title: '$title (${items.length})'),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            for (final item in items.take(10))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(icon, size: 18, color: color),
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${_formatQty(item.quantity)} '
                  '${inventoryUnitLabel(item.unit)}'
                  '${item.expiresAt != null ? ' · تنتهي ${DateFormat('yyyy/MM/dd').format(item.expiresAt!)}' : ''}'
                  ' · ${_money(item.stockValue)} $currency',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => onTap(item),
              ),
            if (items.length > 10)
              Text(
                'و${items.length - 10} مادة أخرى.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }
}

class _MovementLog extends StatelessWidget {
  const _MovementLog({
    required this.movements,
    required this.names,
    required this.currency,
  });

  final List<InventoryMovement> movements;
  final Map<String, String> names;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.receipt_long_outlined,
              title: 'آخر الحركات (${movements.length})',
            ),
            const SizedBox(height: 8),
            if (movements.isEmpty)
              Text(
                'لا حركات في هذه الفترة.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              )
            else
              for (final movement in movements)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        movement.type == 'purchase'
                            ? Icons.add_circle_outline
                            : movement.type == 'adjustment'
                                ? Icons.swap_vert_rounded
                                : Icons.remove_circle_outline,
                        size: 17,
                        color: movement.type == 'purchase'
                            ? Colors.green.shade700
                            : movement.type == 'adjustment'
                                ? Colors.blueGrey
                                : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${names[movement.itemId] ?? 'مادة'} · '
                          '${inventoryMovementLabel(movement.type)}',
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${_formatQty(movement.quantity)} · '
                        '${_money(movement.quantity * movement.unitCost)} $currency',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            const Text(
              'تعذّر تحميل تقرير المخزون',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

String _formatQty(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _money(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
