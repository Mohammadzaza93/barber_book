import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/ops_helpers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feature_labels.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';
import 'customers_to_call_screen.dart';
import 'day_close_screen.dart';
import 'smart_analytics_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _DashboardHeader(),
        SizedBox(height: 12),
        _CompareStrip(),
        SizedBox(height: 12),
        _OpsShortcuts(),
        SizedBox(height: 12),
        _SmartAnalyticsEntry(),
        SizedBox(height: 16),
        _DashboardStatsGrid(),
        SizedBox(height: 8),
        _RevenueSection(),
        SizedBox(height: 8),
        _BookingsSection(),
        SizedBox(height: 8),
        _PopularServicesSection(),
        SizedBox(height: 8),
        _TopStaffSection(),
        SizedBox(height: 16),
      ],
    );
  }
}

class _CompareStrip extends StatelessWidget {
  const _CompareStrip();

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final now = DateTime.now();
    final todayStart = OpsHelpers.dayStart(now);
    final todayEnd = OpsHelpers.dayEnd(now);
    final yStart = OpsHelpers.dayStart(now.subtract(const Duration(days: 1)));
    final yEnd = OpsHelpers.dayEnd(now.subtract(const Duration(days: 1)));
    final wStart = OpsHelpers.weekStart(now);
    final today = finance.sumDailyTotal(from: todayStart, to: todayEnd);
    final yesterday = finance.sumDailyTotal(from: yStart, to: yEnd);
    final week = finance.sumDailyTotal(from: wStart, to: todayEnd);
    final delta = today - yesterday;
    final deltaLabel =
        delta >= 0 ? '+${delta.toStringAsFixed(0)}' : delta.toStringAsFixed(0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: _mini('اليوم', today.toStringAsFixed(0))),
            Expanded(
              child: _mini('أمس', yesterday.toStringAsFixed(0),
                  sub: 'فرق $deltaLabel'),
            ),
            Expanded(child: _mini('هذا الأسبوع', week.toStringAsFixed(0))),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, String value, {String? sub}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (sub != null) Text(sub, style: const TextStyle(fontSize: 10)),
        ],
      );
}

class _OpsShortcuts extends StatelessWidget {
  const _OpsShortcuts();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DayCloseScreen()),
            ),
            icon: const Icon(Icons.nightlight_round, size: 18),
            label: const Text('إغلاق اليوم'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomersToCallScreen()),
            ),
            icon: const Icon(Icons.phone_callback_outlined, size: 18),
            label: const Text('اتصال'),
          ),
        ),
      ],
    );
  }
}

class _SmartAnalyticsEntry extends StatelessWidget {
  const _SmartAnalyticsEntry();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
      child: ListTile(
        leading: const Icon(Icons.auto_awesome_rounded),
        title: const Text(
          'تحليلات ذكية',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('رؤى · مقارنة شهرية · توقع 7 أيام · ساعة الذروة'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SmartAnalyticsScreen()),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final shopName = context.select<ShopProvider, String>(
      (s) => s.settings?.shopName ?? '',
    );
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context).welcomeBackName(shopName),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, d MMMM', Intl.getCurrentLocale()).format(now),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }
}

class _DashboardStatsGrid extends StatelessWidget {
  const _DashboardStatsGrid();

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<AppointmentProvider>();
    final finance = context.watch<FinanceProvider>();
    final settings = context.watch<ShopProvider>().settings;
    final currency = settings?.currency ?? 'SAR';
    final accent = parseHexColor(settings?.accentColorHex ?? '0xFFC6CBD4');
    final analytics = AnalyticsService.instance;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final revenueToday = analytics.revenue(appointments.appointments,
        from: dayStart, to: now);
    final bookingsToday = appointments.todayAppointments.length;
    final pending = appointments.pendingRequests.length;
    final net = finance.sumSalonShares() - finance.sumExpenses();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.payments_rounded,
                label:
                    FeatureLabels.text(context, 'إيراد اليوم', 'Today revenue'),
                value: fmtPrice(revenueToday, currency),
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.event_available_rounded,
                label: FeatureLabels.text(
                    context, 'مواعيد اليوم', 'Today bookings'),
                value: '$bookingsToday',
                color: const Color(0xFF059669),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.hourglass_top_rounded,
                label: FeatureLabels.text(context, 'طلبات معلّقة', 'Pending'),
                value: '$pending',
                color: const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.trending_up_rounded,
                label: FeatureLabels.text(context, 'صافي تقديري', 'Est. net'),
                value: fmtPrice(net, currency),
                color: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RevenueSection extends StatelessWidget {
  const _RevenueSection();

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<AppointmentProvider>().appointments;
    final settings = context.watch<ShopProvider>().settings;
    final accent = parseHexColor(settings?.accentColorHex ?? '0xFFC6CBD4');
    final start = DateTime.now().subtract(const Duration(days: 6));
    final daily =
        AnalyticsService.instance.dailyRevenue(appointments, start, 7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: t(context).revenueChart),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 160,
              child: _MiniBarChart(daily: daily, color: accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingsSection extends StatelessWidget {
  const _BookingsSection();

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<AppointmentProvider>().appointments;
    final start = DateTime.now().subtract(const Duration(days: 6));
    final daily =
        AnalyticsService.instance.dailyBookings(appointments, start, 7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
            title: FeatureLabels.text(context, 'الحجوزات', 'Bookings')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 140,
              child: _MiniBarChart(
                daily: {
                  for (final e in daily.entries) e.key: e.value.toDouble()
                },
                color: const Color(0xFF059669),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PopularServicesSection extends StatelessWidget {
  const _PopularServicesSection();

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<AppointmentProvider>().appointments;
    final services = context.watch<ShopProvider>().services;
    final map =
        AnalyticsService.instance.popularServices(appointments, services);
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: t(context).popularServices),
        Card(
          child: sorted.isEmpty
              ? EmptyState(icon: Icons.content_cut, title: t(context).noData)
              : Column(
                  children: sorted.take(5).map((e) {
                    return ListTile(
                      title: Text(e.key),
                      trailing: Text('${e.value}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _TopStaffSection extends StatelessWidget {
  const _TopStaffSection();

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<AppointmentProvider>().appointments;
    final employees = context.watch<ShopProvider>().employees;
    final currency =
        context.watch<ShopProvider>().settings?.currency ?? 'SAR';
    final names = {for (final e in employees) e.id: e.name};
    final map =
        AnalyticsService.instance.staffPerformance(appointments, names);
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: t(context).staffPerformance),
        Card(
          child: sorted.isEmpty
              ? EmptyState(icon: Icons.groups, title: t(context).noData)
              : Column(
                  children: sorted.take(5).map((e) {
                    return ListTile(
                      title: Text(e.key),
                      trailing: Text(
                        fmtPrice(e.value, currency),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final Map<DateTime, double> daily;
  final Color color;
  const _MiniBarChart({required this.daily, required this.color});

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
                  DateFormat('E', Intl.getCurrentLocale())
                      .format(entries[i].key),
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
