import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/appointment_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/smart_analytics.dart';
import '../../theme/app_theme.dart';

/// لوحة تحليلات ذكية — مؤشرات + رؤى + توقع 7 أيام.
class SmartAnalyticsScreen extends StatelessWidget {
  const SmartAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final appts = context.watch<AppointmentProvider>().appointments;
    final shop = context.watch<ShopProvider>();
    final staffNames = {for (final e in shop.employees) e.id: e.name};

    final report = SmartAnalytics.instance.build(
      financeEntries: finance.entries,
      expenses: finance.expenses,
      appointments: appts,
      services: shop.services,
      staffNames: staffNames,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحليلات ذكية'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'ملخص فوري',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _KpiRow(
            items: [
              _Kpi('اليوم', report.today.revenue, report.today.bookings),
              _Kpi('هذا الأسبوع', report.thisWeek.revenue, report.thisWeek.bookings),
              _Kpi('هذا الشهر', report.thisMonth.revenue, report.thisMonth.bookings),
            ],
          ),
          const SizedBox(height: 12),
          _MonthCompareCard(report: report),
          const SizedBox(height: 16),
          const Text(
            'رؤى ذكية',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          for (final i in report.insights) _InsightTile(insight: i),
          const SizedBox(height: 16),
          const Text(
            'توقع الإيراد — 7 أيام قادمة',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'حساب محلي من متوسط متحرك + اتجاه بسيط (بدون أدوات مدفوعة)',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 180,
                child: _ForecastChart(values: report.forecastNext7),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (report.forecastNext7.isNotEmpty)
            Text(
              'مجموع متوقع للأسبوع: '
              '${report.forecastNext7.fold(0.0, (a, b) => a + b).toStringAsFixed(0)} ل.س',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 16),
          const Text(
            'أبرز النقاط',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.content_cut_rounded),
                  title: const Text('الخدمة الأكثر طلباً'),
                  subtitle: Text(report.topServiceName ?? '—'),
                ),
                ListTile(
                  leading: const Icon(Icons.person_rounded),
                  title: const Text('أفضل أداء'),
                  subtitle: Text(report.topStaffName ?? '—'),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('ساعة الذروة'),
                  subtitle: Text(
                    report.peakHourRatio > 0
                        ? '${_hourLabel(report.peakHour)} '
                            '(${(report.peakHourRatio * 100).toStringAsFixed(0)}% من الحجوزات)'
                        : '—',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_rounded),
                  title: const Text('صافي ربح الشهر'),
                  subtitle: Text(
                    '${report.thisMonth.netProfit.toStringAsFixed(0)} ل.س',
                    style: TextStyle(
                      color: report.thisMonth.netProfit >= 0
                          ? const Color(0xFF059669)
                          : const Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static String _hourLabel(int h) {
    final period = h < 12 ? 'ص' : 'م';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12 $period';
  }
}

class _Kpi {
  final String label;
  final double revenue;
  final int bookings;
  const _Kpi(this.label, this.revenue, this.bookings);
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.items});
  final List<_Kpi> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items[i].label,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[i].revenue.toStringAsFixed(0),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${items[i].bookings} حجز',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MonthCompareCard extends StatelessWidget {
  const _MonthCompareCard({required this.report});
  final SmartAnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final pct = report.monthVsLast.revenuePct;
    final up = pct >= 0;
    return Card(
      color: (up ? const Color(0xFF059669) : const Color(0xFFB91C1C))
          .withOpacity(0.08),
      child: ListTile(
        leading: Icon(
          up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: up ? const Color(0xFF059669) : const Color(0xFFB91C1C),
        ),
        title: const Text(
          'مقارنة الإيراد بالشهر السابق',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'الحالي: ${report.thisMonth.revenue.toStringAsFixed(0)} · '
          'السابق: ${report.lastMonth.revenue.toStringAsFixed(0)}',
        ),
        trailing: Text(
          '${up ? '+' : ''}${pct.toStringAsFixed(0)}%',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: up ? const Color(0xFF059669) : const Color(0xFFB91C1C),
          ),
        ),
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight});
  final SmartInsight insight;

  Color get _color => switch (insight.kind) {
        InsightKind.positive => const Color(0xFF059669),
        InsightKind.warning => const Color(0xFFB91C1C),
        InsightKind.tip => const Color(0xFFD97706),
        InsightKind.info => const Color(0xFF2563EB),
      };

  IconData get _icon => switch (insight.icon) {
        IconKey.trendingUp => Icons.trending_up_rounded,
        IconKey.trendingDown => Icons.trending_down_rounded,
        IconKey.schedule => Icons.schedule_rounded,
        IconKey.star => Icons.star_rounded,
        IconKey.money => Icons.payments_rounded,
        IconKey.people => Icons.groups_rounded,
        IconKey.insights => Icons.lightbulb_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _color.withOpacity(0.15),
          child: Icon(_icon, color: _color, size: 20),
        ),
        title: Text(
          insight.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(insight.body),
        isThreeLine: insight.body.length > 60,
      ),
    );
  }
}

class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Center(child: Text('لا بيانات كافية للتوقع'));
    }
    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m);
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
                if (i < 0 || i >= values.length) return const SizedBox.shrink();
                return Text(
                  'ي${i + 1}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 14,
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
