import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feature_labels.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final appointments = context.watch<AppointmentProvider>();
    final expenses = context.watch<ExpenseProvider>();
    final settings = shop.settings;
    final currency = settings?.currency ?? 'SAR';
    final accent = parseHexColor(settings?.accentColorHex ?? '0xFFC6CBD4');

    final analytics = AnalyticsService.instance;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final revenueMonth = analytics.revenue(appointments.appointments, from: monthStart);
    final expenseMonth = analytics.totalExpenses(expenses.expenses, from: monthStart);
    final profitMonth = revenueMonth - expenseMonth;
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final daily = analytics.dailyRevenue(appointments.appointments, weekStart, 7);
    final dailyBookings = analytics.dailyBookings(appointments.appointments, weekStart, 7);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          t(context).welcomeBackName(settings?.shopName ?? ''),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, d MMMM', Intl.getCurrentLocale()).format(now),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            StatCard(
              icon: Icons.event_available_rounded,
              label: t(context).todayAppointments,
              value: '${appointments.todayAppointments.length}',
              color: accent,
            ),
            StatCard(
              icon: Icons.event_note_rounded,
              label: t(context).upcomingAppointments,
              value: '${appointments.upcomingAppointments.length}',
              color: const Color(0xFF059669),
            ),
            StatCard(
              icon: Icons.payments_rounded,
              label: t(context).revenueThisMonth,
              value: fmtPrice(revenueMonth, currency),
              color: const Color(0xFFD97706),
            ),
            StatCard(
              icon: Icons.person_off_rounded,
              label: t(context).noShowRate,
              value: '${analytics.noShowRate(appointments.appointments).toStringAsFixed(0)}%',
              color: const Color(0xFFB91C1C),
            ),
            StatCard(
              icon: Icons.trending_up_rounded,
              label: t(context).netProfit,
              value: fmtPrice(profitMonth, currency),
              color: const Color(0xFF7C3AED),
            ),
            StatCard(
              icon: Icons.people_alt_rounded,
              label: t(context).customersCount,
              value: '${analytics.uniqueCustomers(appointments.appointments)}',
              color: const Color(0xFF0891B2),
            ),
            StatCard(
              icon: Icons.receipt_long_rounded,
              label: t(context).avgTicket,
              value: fmtPrice(analytics.avgTicket(appointments.appointments), currency),
              color: const Color(0xFFEA580C),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SectionHeader(
          title: t(context).revenueLast7Days,
          trailing: Text(
            t(context).last7Days,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 160,
              child: _RevenueChart(daily: daily, color: accent, currency: currency),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SectionHeader(
          title: FeatureLabels.text(context, 'الحجوزات (آخر 7 أيام)', 'Bookings (last 7 days)'),
          trailing: Text(
            FeatureLabels.text(context, 'مكتمل', 'Completed') + ': ${analytics.completionRate(appointments.appointments).toStringAsFixed(0)}%',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 160,
              child: _BookingsChart(daily: dailyBookings, color: const Color(0xFF059669)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SectionHeader(title: t(context).popularServices),
        _PopularServices(shop: shop, appointments: appointments.appointments),
        const SizedBox(height: 8),
        SectionHeader(title: t(context).topStaff),
        _TopStaff(shop: shop, appointments: appointments.appointments, currency: currency),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final Map<DateTime, double> daily;
  final Color color;
  final String currency;
  const _RevenueChart({required this.daily, required this.color, required this.currency});

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
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${DateFormat('d/M').format(entries[group.x].key)}\n${rod.toY.toStringAsFixed(0)}',
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
                if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('E').format(entries[i].key),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _BookingsChart extends StatelessWidget {
  final Map<DateTime, int> daily;
  final Color color;
  const _BookingsChart({required this.daily, required this.color});

  @override
  Widget build(BuildContext context) {
    final entries = daily.entries.toList();
    final maxVal = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    return BarChart(
      BarChartData(
        maxY: (maxVal == 0 ? 1 : maxVal).toDouble() * 1.25,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${DateFormat('d/M').format(entries[group.x].key)}\\n${rod.toY.round()} حجز',
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
                if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('E').format(entries[i].key),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                );
              },
            ),
          ),
        ),
        barGroups: entries.asMap().entries.map((e) => BarChartGroupData(
          x: e.key,
          barRods: [BarChartRodData(
            toY: e.value.value.toDouble(),
            color: color,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          )],
        )).toList(),
      ),
    );
  }
}

class _PopularServices extends StatelessWidget {
  final ShopProvider shop;
  final List<Appointment> appointments;
  const _PopularServices({required this.shop, required this.appointments});

  @override
  Widget build(BuildContext context) {
    final popular = AnalyticsService.instance
        .popularServices(appointments, shop.services);
    if (popular.isEmpty) {
      return Card(
          child: EmptyState(
              icon: Icons.bar_chart_rounded, title: t(context).noData));
    }
    final max = popular.values.fold<double>(0, (m, v) => v > m ? v : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: popular.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${e.value.round()}×', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value / max,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEEF2F7),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TopStaff extends StatelessWidget {
  final ShopProvider shop;
  final List<Appointment> appointments;
  final String currency;
  const _TopStaff({required this.shop, required this.appointments, required this.currency});

  @override
  Widget build(BuildContext context) {
    final names = {for (final e in shop.employees) e.id: e.name};
    final perf = AnalyticsService.instance.staffPerformance(appointments, names);
    if (perf.isEmpty) {
      return Card(
          child: EmptyState(
              icon: Icons.group_outlined, title: t(context).noData));
    }
    final sorted = perf.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Column(
        children: sorted.take(5).map((e) {
          return ListTile(
            leading: const Icon(Icons.person_rounded, color: Color(0xFF64748B)),
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
