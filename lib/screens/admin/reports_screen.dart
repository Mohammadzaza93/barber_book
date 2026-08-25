import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/appointment.dart';
import '../../models/expense.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/expense_provider.dart';
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
    final expenses = context.watch<ExpenseProvider>().expenses;
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
    final daily = analytics.dailyRevenue(appointments, start, days);
    final revenue = daily.values.fold(0.0, (a, b) => a + b);
    final expTotal = analytics.totalExpenses(expenses,
        from: DateTime(start.year, start.month, start.day),
        to: now.add(const Duration(days: 1)));
    final netProfit = revenue - expTotal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<_Period>(
          segments: [
            ButtonSegment(value: _Period.daily, label: Text(t(context).periodDaily)),
            ButtonSegment(value: _Period.weekly, label: Text(t(context).periodWeekly)),
            ButtonSegment(value: _Period.monthly, label: Text(t(context).periodMonthly)),
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
                color: netProfit >= 0
                    ? const Color(0xFF059669)
                    : const Color(0xFFB91C1C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.event_note_rounded,
                label: t(context).totalBookings,
                value: '${analytics.bookingsInRange(appointments, from: start)}',
                color: const Color(0xFFC6CBD4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.group_rounded,
                label: t(context).customersCount,
                value: '${analytics.uniqueCustomers(appointments)}',
                color: const Color(0xFF7C3AED),
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
              child: _RevenueBarChart(
                  daily: daily, color: accent, currency: currency),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SectionHeader(title: t(context).popularServices),
        _ServicePie(shop: shop, appointments: appointments),
        const SizedBox(height: 8),
        SectionHeader(title: t(context).expensesByCategory),
        _ExpensePie(expenses: expenses),
        const SizedBox(height: 8),
        SectionHeader(title: t(context).staffPerformance),
        _StaffList(shop: shop, appointments: appointments, currency: currency),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  final Map<DateTime, double> daily;
  final Color color;
  final String currency;
  const _RevenueBarChart(
      {required this.daily, required this.color, required this.currency});

  @override
  Widget build(BuildContext context) {
    final entries = daily.entries.toList();
    final maxVal = entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    return BarChart(
      BarChartData(
        maxY: maxVal == 0 ? 100 : maxVal * 1.25,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
              '${DateFormat('d/M').format(entries[group.x].key)}\n'
              '${rod.toY.toStringAsFixed(0)}',
              const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('d/M').format(entries[i].key),
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
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
                width: 12,
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

class _ServicePie extends StatelessWidget {
  final ShopProvider shop;
  final List<Appointment> appointments;
  const _ServicePie({required this.shop, required this.appointments});

  @override
  Widget build(BuildContext context) {
    final popular = AnalyticsService.instance
        .popularServices(appointments, shop.services);
    if (popular.isEmpty) {
      return Card(
          child: EmptyState(
              icon: Icons.pie_chart_outline_rounded,
              title: t(context).noData));
    }
    const colors = [
      Color(0xFFC6CBD4), Color(0xFF7C3AED), Color(0xFF059669),
      Color(0xFFD97706), Color(0xFFB91C1C),
    ];
    final entries = popular.entries.toList();
    final total = entries.fold<double>(0, (a, b) => a + b.value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 34,
                  sections: entries.asMap().entries.map((e) {
                    return PieChartSectionData(
                      value: e.value.value,
                      color: colors[e.key % colors.length],
                      radius: 22,
                      title: total == 0
                          ? ''
                          : '${(e.value.value / total * 100).toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: entries.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors[e.key % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.value.key,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('${e.value.value.round()}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpensePie extends StatelessWidget {
  final List<Expense> expenses;
  const _ExpensePie({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final byCategory = AnalyticsService.instance
        .expensesByCategory(expenses);
    if (byCategory.isEmpty) {
      return Card(
          child: EmptyState(
              icon: Icons.pie_chart_outline_rounded,
              title: t(context).noData));
    }
    const colors = [
      Color(0xFFB91C1C), Color(0xFFD97706), Color(0xFF059669),
      Color(0xFFC6CBD4), Color(0xFF7C3AED), Color(0xFF0E7490),
      Color(0xFF64748B),
    ];
    final entries = byCategory.entries.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 34,
                  sections: entries.asMap().entries.map((e) {
                    return PieChartSectionData(
                      value: e.value.value,
                      color: colors[e.key % colors.length],
                      radius: 22,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: entries.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors[e.key % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.value.key,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(e.value.value.toStringAsFixed(0),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffList extends StatelessWidget {
  final ShopProvider shop;
  final List<Appointment> appointments;
  final String currency;
  const _StaffList(
      {required this.shop, required this.appointments, required this.currency});

  @override
  Widget build(BuildContext context) {
    final names = {for (final e in shop.employees) e.id: e.name};
    final perf = AnalyticsService.instance
        .staffPerformance(appointments, names);
    if (perf.isEmpty) {
      return Card(
          child: EmptyState(
              icon: Icons.group_outlined, title: t(context).noData));
    }
    final sorted = perf.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Column(
        children: sorted.take(8).map((e) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.person_rounded,
                color: Color(0xFF64748B)),
            title: Text(e.key),
            trailing: Text(fmtPrice(e.value, currency),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          );
        }).toList(),
      ),
    );
  }
}
