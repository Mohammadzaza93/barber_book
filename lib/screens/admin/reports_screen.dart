import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/appointment.dart';
import '../../models/finance/finance_models.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

enum _Period { daily, weekly, monthly }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Period _period = _Period.weekly;

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<AppointmentProvider>().appointments;
    final finance = context.watch<FinanceProvider>();
    final shop = context.watch<ShopProvider>();
    final settings = shop.settings;
    final currency = settings?.currency ?? 'SAR';
    final accent = parseHexColor(settings?.accentColorHex ?? '0xFFC6CBD4');
    final analytics = AnalyticsService.instance;

    final now = DateTime.now();
    final (days, start) = switch (_period) {
      _Period.daily => (1, now),
      _Period.weekly => (7, now.subtract(const Duration(days: 6))),
      _Period.monthly => (30, now.subtract(const Duration(days: 29))),
    };
    final rangeStart = DateTime(start.year, start.month, start.day);
    final daily = analytics.dailyRevenue(appointments, start, days);
    final revenue = daily.values.fold(0.0, (a, b) => a + b);
    final expTotal = finance.expenses
        .where((e) => !e.date.isBefore(rangeStart) && !e.date.isAfter(now))
        .fold<double>(0, (s, e) => s + e.amountSyp);
    final netProfit = revenue - expTotal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<_Period>(
          segments: [
            ButtonSegment(
                value: _Period.daily, label: Text(t(context).periodDaily)),
            ButtonSegment(
                value: _Period.weekly, label: Text(t(context).periodWeekly)),
            ButtonSegment(
                value: _Period.monthly,
                label: Text(t(context).periodMonthly)),
          ],
          selected: {_period},
          onSelectionChanged: (s) => setState(() => _period = s.first),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.payments_rounded,
                label: t(context).revenueChart,
                value: fmtPrice(revenue, currency),
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.trending_up_rounded,
                label: t(context).netProfit,
                value: fmtPrice(netProfit, currency),
                color: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.receipt_long_rounded,
                label: t(context).totalExpenses,
                value: fmtPrice(expTotal, currency),
                color: const Color(0xFFB91C1C),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.event_note_rounded,
                label: t(context).bookings,
                value: '${appointments.length}',
                color: const Color(0xFF059669),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionHeader(title: t(context).revenueChart),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 180,
              child: _SimpleBarChart(daily: daily, color: accent),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SectionHeader(title: t(context).expensesByCategory),
        _OperatingExpenseBreakdown(expenses: finance.expenses),
        const SizedBox(height: 16),
        SectionHeader(title: t(context).staffPerformance),
        _StaffPerf(
          appointments: appointments,
          shop: shop,
          currency: currency,
        ),
      ],
    );
  }
}

class _SimpleBarChart extends StatelessWidget {
  final Map<DateTime, double> daily;
  final Color color;
  const _SimpleBarChart({required this.daily, required this.color});

  @override
  Widget build(BuildContext context) {
    final entries = daily.entries.toList();
    if (entries.isEmpty) {
      return Center(child: Text(t(context).noData));
    }
    final maxVal =
        entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    return BarChart(
      BarChartData(
        maxY: maxVal == 0 ? 100 : maxVal * 1.25,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  DateFormat('d/M').format(entries[i].key),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                );
              },
            ),
          ),
        ),
        barGroups: entries.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: color,
                width: 14,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _OperatingExpenseBreakdown extends StatelessWidget {
  final List<OperatingExpense> expenses;
  const _OperatingExpenseBreakdown({required this.expenses});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return Card(
        child: EmptyState(
          icon: Icons.pie_chart_outline_rounded,
          title: t(context).noData,
        ),
      );
    }
    final byType = <String, double>{};
    for (final e in expenses) {
      final key = e.type.name;
      byType[key] = (byType[key] ?? 0) + e.amountSyp;
    }
    final total = byType.values.fold<double>(0, (a, b) => a + b);
    final colors = [
      const Color(0xFFB91C1C),
      const Color(0xFFD97706),
      const Color(0xFF059669),
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFF0891B2),
      const Color(0xFFEA580C),
    ];
    final entries = byType.entries.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(entries[i].key)),
                    Text(
                      '${entries[i].value.toStringAsFixed(0)} (${total == 0 ? 0 : (entries[i].value / total * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
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

class _StaffPerf extends StatelessWidget {
  final List<Appointment> appointments;
  final ShopProvider shop;
  final String currency;
  const _StaffPerf({
    required this.appointments,
    required this.shop,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final names = {for (final e in shop.employees) e.id: e.name};
    final perf =
        AnalyticsService.instance.staffPerformance(appointments, names);
    if (perf.isEmpty) {
      return Card(
        child: EmptyState(
            icon: Icons.group_outlined, title: t(context).noData),
      );
    }
    final sorted = perf.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Column(
        children: sorted.take(8).map((e) {
          return ListTile(
            title: Text(e.key),
            trailing: Text(
              fmtPrice(e.value, currency),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        }).toList(),
      ),
    );
  }
}
