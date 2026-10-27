import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/appointment_provider.dart';
import '../../providers/finance_provider.dart';
import '../../services/performance_report.dart';
import '../../theme/app_theme.dart';

/// تقرير أداء شامل: مقارنة شهرية وسنوية.
class PerformanceReportScreen extends StatefulWidget {
  const PerformanceReportScreen({super.key});

  @override
  State<PerformanceReportScreen> createState() =>
      _PerformanceReportScreenState();
}

class _PerformanceReportScreenState extends State<PerformanceReportScreen> {
  int _tab = 0; // 0 شهري · 1 سنوي
  late int _yearA;
  late int _yearB;

  @override
  void initState() {
    super.initState();
    final y = DateTime.now().year;
    _yearA = y;
    _yearB = y - 1;
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final appointments = context.watch<AppointmentProvider>().appointments;
    final svc = PerformanceReportService.instance;

    final months = svc.last12Months(
      financeEntries: finance.entries,
      expenses: finance.expenses,
      appointments: appointments,
    );

    final years = svc.availableYears(
      financeEntries: finance.entries,
      appointments: appointments,
    );
    if (!years.contains(_yearA)) _yearA = years.last;
    if (!years.contains(_yearB) && years.length > 1) {
      _yearB = years[years.length - 2];
    } else if (!years.contains(_yearB)) {
      _yearB = years.first;
    }

    final yearSnapA = svc.yearSnapshot(
      year: _yearA,
      financeEntries: finance.entries,
      expenses: finance.expenses,
      appointments: appointments,
    );
    final yearSnapB = svc.yearSnapshot(
      year: _yearB,
      financeEntries: finance.entries,
      expenses: finance.expenses,
      appointments: appointments,
    );

    final thisMonth = months.isNotEmpty ? months.last : null;
    final prevMonth =
        months.length >= 2 ? months[months.length - 2] : null;
    final monthCmp = (thisMonth != null && prevMonth != null)
        ? svc.compare(thisMonth, prevMonth)
        : null;

    final yearCmp = svc.compare(yearSnapA, yearSnapB);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الأداء الشامل'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('مقارنة شهرية')),
              ButtonSegment(value: 1, label: Text('مقارنة سنوية')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 16),
          if (_tab == 0) ...[
            if (thisMonth != null) ...[
              Text(
                'الشهر الحالي: ${thisMonth.monthLabel}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _SnapshotCards(snap: thisMonth),
              if (monthCmp != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'مقارنة مع الشهر السابق',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 8),
                _ComparisonTable(cmp: monthCmp),
              ],
              const SizedBox(height: 16),
              const Text(
                'إيرادات آخر 12 شهراً',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 200,
                    child: _MonthRevenueChart(months: months),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _MonthsTable(months: months),
            ] else
              const Text('لا توجد بيانات كافية بعد.'),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _yearA,
                    items: years
                        .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text('$y (أ)'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _yearA = v ?? _yearA),
                    decoration: const InputDecoration(
                      labelText: 'السنة الأساسية',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _yearB,
                    items: years
                        .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text('$y (ب)'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _yearB = v ?? _yearB),
                    decoration: const InputDecoration(
                      labelText: 'للمقارنة مع',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'ملخص $_yearA',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _SnapshotCards(snap: yearSnapA),
            const SizedBox(height: 16),
            Text(
              'مقارنة $_yearA مقابل $_yearB',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            _ComparisonTable(
              cmp: yearCmp,
              currentLabel: '$_yearA',
              previousLabel: '$_yearB',
            ),
            const SizedBox(height: 16),
            const Text(
              'تفصيل السنة الأساسية (شهرياً)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            _YearMonthsBreakdown(
              year: _yearA,
              finance: finance,
              appointments: appointments,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'المصادر: وارد الزبائن + المصاريف التشغيلية + المواعيد. '
            'إن لم تُسجَّل مبيعات يُستخدم إيراد المواعيد المكتملة.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _SnapshotCards extends StatelessWidget {
  const _SnapshotCards({required this.snap});
  final PeriodSnapshot snap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _mini(
                'الإيراد',
                snap.revenue,
                const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _mini(
                'المصاريف',
                snap.expenses,
                const Color(0xFFB91C1C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _mini(
                'صافي الربح',
                snap.netProfit,
                snap.netProfit >= 0
                    ? const Color(0xFF059669)
                    : const Color(0xFFB91C1C),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _miniCount('الحجوزات', snap.bookings),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _miniCount('مكتمل', snap.completed)),
            const SizedBox(width: 8),
            Expanded(
              child: _mini(
                'متوسط التذكرة',
                snap.avgTicket,
                const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _miniCount('لم يحضر', snap.noShows)),
            const SizedBox(width: 8),
            Expanded(child: _miniCount('ملغى', snap.cancelled)),
          ],
        ),
      ],
    );
  }

  Widget _mini(String label, double value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(0)} ل.س',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniCount(String label, int value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({
    required this.cmp,
    this.currentLabel = 'الحالي',
    this.previousLabel = 'السابق',
  });

  final ComparisonResult cmp;
  final String currentLabel;
  final String previousLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _header(),
            _row('الإيراد', cmp.current.revenue, cmp.previous.revenue,
                cmp.revenuePct),
            _row('المصاريف', cmp.current.expenses, cmp.previous.expenses,
                cmp.expensesPct),
            _row('صافي الربح', cmp.current.netProfit, cmp.previous.netProfit,
                cmp.netPct),
            _rowCount('الحجوزات', cmp.current.bookings, cmp.previous.bookings,
                cmp.bookingsPct),
            _rowCount('مكتمل', cmp.current.completed, cmp.previous.completed,
                cmp.completedPct),
            _row('متوسط التذكرة', cmp.current.avgTicket, cmp.previous.avgTicket,
                cmp.avgTicketPct),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Expanded(
              flex: 3,
              child: Text('المؤشر',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          Expanded(
              child: Text(currentLabel,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(
              child: Text(previousLabel,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          const Expanded(
              child: Text('التغير%',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _row(String label, double cur, double prev, double pct) {
    final up = pct >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label)),
          Expanded(
            child: Text(cur.toStringAsFixed(0),
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(prev.toStringAsFixed(0), textAlign: TextAlign.end),
          ),
          Expanded(
            child: Text(
              '${up ? '+' : ''}${pct.toStringAsFixed(0)}%',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: up ? const Color(0xFF059669) : const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowCount(String label, int cur, int prev, double pct) {
    return _row(label, cur.toDouble(), prev.toDouble(), pct);
  }
}

class _MonthRevenueChart extends StatelessWidget {
  const _MonthRevenueChart({required this.months});
  final List<PeriodSnapshot> months;

  @override
  Widget build(BuildContext context) {
    final maxY = months.fold<double>(0, (m, e) => e.revenue > m ? e.revenue : m);
    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 100 : maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= months.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${months[i].from.month}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: months[i].revenue,
                  width: 12,
                  color: kSilver,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MonthsTable extends StatelessWidget {
  const _MonthsTable({required this.months});
  final List<PeriodSnapshot> months;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('الشهر')),
            DataColumn(label: Text('إيراد')),
            DataColumn(label: Text('مصروف')),
            DataColumn(label: Text('صافي')),
            DataColumn(label: Text('حجوزات')),
          ],
          rows: [
            for (final m in months.reversed)
              DataRow(cells: [
                DataCell(Text(m.monthLabel)),
                DataCell(Text(m.revenue.toStringAsFixed(0))),
                DataCell(Text(m.expenses.toStringAsFixed(0))),
                DataCell(Text(
                  m.netProfit.toStringAsFixed(0),
                  style: TextStyle(
                    color: m.netProfit >= 0
                        ? const Color(0xFF059669)
                        : const Color(0xFFB91C1C),
                    fontWeight: FontWeight.w700,
                  ),
                )),
                DataCell(Text('${m.bookings}')),
              ]),
          ],
        ),
      ),
    );
  }
}

class _YearMonthsBreakdown extends StatelessWidget {
  const _YearMonthsBreakdown({
    required this.year,
    required this.finance,
    required this.appointments,
  });

  final int year;
  final FinanceProvider finance;
  final List appointments;

  @override
  Widget build(BuildContext context) {
    final svc = PerformanceReportService.instance;
    final rows = <PeriodSnapshot>[];
    for (var m = 1; m <= 12; m++) {
      final from = DateTime(year, m, 1);
      final to = DateTime(year, m + 1, 0);
      rows.add(svc.snapshot(
        from: from,
        to: to,
        financeEntries: finance.entries,
        expenses: finance.expenses,
        appointments: List.from(appointments),
      ));
    }
    return _MonthsTable(months: rows);
  }
}
