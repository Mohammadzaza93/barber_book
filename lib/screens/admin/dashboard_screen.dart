import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/smart_analytics.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feature_labels.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';
import 'customers_to_call_screen.dart';
import 'day_close_screen.dart';
import 'smart_analytics_screen.dart';

/// لوحة التحكم — تعتمد فقط على SmartAnalytics (نفس مصدر التحليلات الذكية).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  SmartAnalyticsReport _report(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final appts = context.watch<AppointmentProvider>().appointments;
    final shop = context.watch<ShopProvider>();
    final staffNames = {for (final e in shop.employees) e.id: e.name};
    return SmartAnalytics.instance.build(
      financeEntries: finance.entries,
      expenses: finance.expenses,
      appointments: appts,
      services: shop.services,
      staffNames: staffNames,
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report(context);
    final finance = context.watch<FinanceProvider>();
    final settings = context.watch<ShopProvider>().settings;
    final currency = settings?.currency ?? 'SAR';
    final accent = parseHexColor(settings?.accentColorHex ?? '0xFFC6CBD4');
    final dailyRev =
        SmartAnalytics.instance.dailyRevenueSeries(finance.entries);
    final dailyOps = SmartAnalytics.instance.dailyOpsSeries(finance.entries);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _DashboardHeader(),
        const SizedBox(height: 12),
        _CompareStrip(report: report),
        const SizedBox(height: 12),
        const _OpsShortcuts(),
        const SizedBox(height: 12),
        const _SmartAnalyticsEntry(),
        const SizedBox(height: 16),
        _StatsFromSmart(report: report, currency: currency, accent: accent),
        const SizedBox(height: 16),
        SectionHeader(
          title:
              FeatureLabels.text(context, 'الإيرادات (7 أيام)', 'Revenue 7d'),
        ),
        _SeriesChart(
            daily: dailyRev, color: accent, emptyLabel: t(context).noData),
        const SizedBox(height: 12),
        SectionHeader(
          title: FeatureLabels.text(context, 'العمليات / الوارد', 'Ops'),
        ),
        _SeriesChart(
          daily: dailyOps,
          color: const Color(0xFF059669),
          emptyLabel: t(context).noData,
        ),
        const SizedBox(height: 12),
        SectionHeader(title: t(context).popularServices),
        _TopLine(
          icon: Icons.content_cut,
          title: report.topServiceName ?? '—',
          empty: report.topServiceName == null,
        ),
        const SizedBox(height: 12),
        SectionHeader(title: t(context).staffPerformance),
        _TopLine(
          icon: Icons.groups,
          title: report.topStaffName ?? '—',
          empty: report.topStaffName == null,
        ),
        const SizedBox(height: 12),
        if (report.insights.isNotEmpty) ...[
          SectionHeader(
            title: FeatureLabels.text(context, 'أبرز الرؤى', 'Insights'),
          ),
          ...report.insights.take(3).map(
                (i) => Card(
                  child: ListTile(
                    leading: Icon(
                      i.kind == InsightKind.warning
                          ? Icons.warning_amber_rounded
                          : i.kind == InsightKind.positive
                              ? Icons.trending_up
                              : Icons.lightbulb_outline,
                    ),
                    title: Text(i.title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(i.body),
                  ),
                ),
              ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _StatsFromSmart extends StatelessWidget {
  const _StatsFromSmart({
    required this.report,
    required this.currency,
    required this.accent,
  });
  final SmartAnalyticsReport report;
  final String currency;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final today = report.today;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.payments_rounded,
                label:
                    FeatureLabels.text(context, 'إيراد اليوم', 'Today revenue'),
                value: fmtPrice(today.revenue, currency),
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.receipt_long_rounded,
                label:
                    FeatureLabels.text(context, 'عمليات اليوم', 'Today ops'),
                value:
                    '${today.salesOps > 0 ? today.salesOps : today.bookings}',
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
                icon: Icons.trending_up_rounded,
                label: FeatureLabels.text(context, 'صافي اليوم', 'Today net'),
                value: fmtPrice(today.netProfit, currency),
                color: today.netProfit >= 0
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.calendar_month_rounded,
                label:
                    FeatureLabels.text(context, 'صافي الشهر', 'Month net'),
                value: fmtPrice(report.thisMonth.netProfit, currency),
                color: report.thisMonth.netProfit >= 0
                    ? const Color(0xFF0EA5E9)
                    : const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompareStrip extends StatelessWidget {
  const _CompareStrip({required this.report});
  final SmartAnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final today = report.today.revenue;
    final week = report.thisWeek.revenue;
    final month = report.thisMonth.revenue;
    final pct = report.monthVsLast.revenuePct;
    final pctLabel = pct.isFinite
        ? '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}% شهري'
        : '—';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: _mini('اليوم', today.toStringAsFixed(0))),
            Expanded(child: _mini('هذا الأسبوع', week.toStringAsFixed(0))),
            Expanded(
              child:
                  _mini('هذا الشهر', month.toStringAsFixed(0), sub: pctLabel),
            ),
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
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
        subtitle: const Text('المصدر الوحيد للأرقام والتوقعات والرؤى'),
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

class _TopLine extends StatelessWidget {
  const _TopLine({
    required this.icon,
    required this.title,
    required this.empty,
  });
  final IconData icon;
  final String title;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: empty
          ? EmptyState(icon: icon, title: t(context).noData)
          : ListTile(
              leading: Icon(icon),
              title:
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }
}

class _SeriesChart extends StatelessWidget {
  const _SeriesChart({
    required this.daily,
    required this.color,
    required this.emptyLabel,
  });
  final Map<DateTime, double> daily;
  final Color color;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final entries = daily.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final hasData = entries.any((e) => e.value > 0);
    if (!hasData) {
      return Card(
        child: SizedBox(
          height: 140,
          child: Center(child: Text(emptyLabel)),
        ),
      );
    }
    final maxVal =
        entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: maxVal == 0 ? 100 : maxVal * 1.25,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
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
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade600),
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
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
