import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/business_features.dart';
import '../../models/day_close_record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/finance_provider.dart';
import '../../services/ops_helpers.dart';

class DayCloseScreen extends StatefulWidget {
  const DayCloseScreen({super.key});

  @override
  State<DayCloseScreen> createState() => _DayCloseScreenState();
}

class _DayCloseScreenState extends State<DayCloseScreen> {
  final _notes = TextEditingController();
  bool _saving = false;
  DayCloseRecord? _existing;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String get _dayId {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  CollectionReference<Map<String, dynamic>>? _col(String? shopId) {
    if (shopId == null || shopId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('day_closes');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    final shopId = context.read<AuthProvider>().shopId;
    final col = _col(shopId);
    if (col == null) return;
    final doc = await col.doc(_dayId).get();
    if (doc.exists && mounted) {
      setState(() {
        _existing = DayCloseRecord.fromMap(doc.id, doc.data()!);
        _notes.text = _existing!.notes;
      });
    }
  }

  Future<void> _closeDay() async {
    final finance = context.read<FinanceProvider>();
    final tools = context.read<BusinessToolsProvider>();
    final auth = context.read<AuthProvider>();
    final col = _col(auth.shopId);
    if (col == null) return;

    final start = OpsHelpers.dayStart(DateTime.now());
    final end = OpsHelpers.dayEnd(DateTime.now());
    final revenue = finance.sumDailyTotal(from: start, to: end);
    final barber = finance.sumBarberShares(from: start, to: end);
    final dayExpenses = finance.expenses
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .fold<double>(0, (s, e) => s + e.amountSyp);
    final services = finance.entries
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .length;
    final chairsWorked = tools.queue
        .where((q) =>
            q.status == QueueStatus.completed &&
            q.completedAt != null &&
            OpsHelpers.isSameDay(q.completedAt!, DateTime.now()))
        .map((q) => q.chairId ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;

    final record = DayCloseRecord(
      id: _dayId,
      date: start,
      servicesCount: services,
      revenue: revenue,
      barberShare: barber,
      expenses: dayExpenses,
      net: revenue - barber - dayExpenses,
      chairsWorked: chairsWorked,
      closedBy: auth.user?.email ?? auth.user?.uid ?? 'owner',
      closedAt: DateTime.now(),
      notes: _notes.text.trim(),
    );

    setState(() => _saving = true);
    await col.doc(_dayId).set(record.toMap());
    if (!mounted) return;
    setState(() {
      _saving = false;
      _existing = record;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إغلاق اليوم وحفظ الملخص')),
    );
  }

  Future<void> _exportCsv() async {
    final finance = context.read<FinanceProvider>();
    final start = OpsHelpers.dayStart(DateTime.now());
    final end = OpsHelpers.dayEnd(DateTime.now());
    final list = finance.entries
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .toList();
    final csv = OpsHelpers.dailySalesCsv(list);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ CSV ليوم اليوم — الصقه في Excel')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final tools = context.watch<BusinessToolsProvider>();
    final start = OpsHelpers.dayStart(DateTime.now());
    final end = OpsHelpers.dayEnd(DateTime.now());
    final revenue = finance.sumDailyTotal(from: start, to: end);
    final barber = finance.sumBarberShares(from: start, to: end);
    final dayExpenses = finance.expenses
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .fold<double>(0, (s, e) => s + e.amountSyp);
    final services = finance.entries
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .length;
    final net = revenue - barber - dayExpenses;
    final lowStock = OpsHelpers.lowStockItems(tools.inventory);
    final closed = _existing != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إغلاق اليوم'),
        actions: [
          IconButton(
            tooltip: 'تصدير CSV',
            onPressed: _exportCsv,
            icon: const Icon(Icons.table_view_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            DateFormat('EEEE d MMMM yyyy', 'ar').format(DateTime.now()),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (closed) ...[
            const SizedBox(height: 8),
            Card(
              color: Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.lock_outline, color: Colors.green),
                title: const Text('اليوم مغلق'),
                subtitle: Text(
                  'أُغلق عند ${DateFormat('HH:mm').format(_existing!.closedAt)}',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _row('عدد الخدمات', '$services'),
          _row('إجمالي الوارد', revenue.toStringAsFixed(0)),
          _row('حصة الحلاقين', barber.toStringAsFixed(0)),
          _row('مصروفات اليوم', dayExpenses.toStringAsFixed(0)),
          _row('الصافي التقديري', net.toStringAsFixed(0)),
          const SizedBox(height: 12),
          if (lowStock.isNotEmpty) ...[
            const Text('تنبيه مخزون منخفض',
                style: TextStyle(fontWeight: FontWeight.w700)),
            ...lowStock.take(5).map(
                  (i) => ListTile(
                    dense: true,
                    title: Text(i.name),
                    trailing: Text(
                        '${i.quantity.toStringAsFixed(0)} / حد ${i.reorderLevel.toStringAsFixed(0)}'),
                  ),
                ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 2,
            enabled: !closed,
            decoration: const InputDecoration(
              labelText: 'ملاحظات الإغلاق',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: closed || _saving ? null : _closeDay,
            icon: const Icon(Icons.nightlight_round),
            label: Text(closed ? 'مغلق مسبقاً' : 'إغلاق اليوم وحفظ الملخص'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Card(
        child: ListTile(
          title: Text(label),
          trailing:
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
}
