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
import 'customers_to_call_screen.dart';
import 'day_close_screen.dart';

/// لوحة تحكم واحدة شاملة — كل الأرقام من SmartAnalytics فقط.
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
    final appointments = context.watch<AppointmentProvider>();
    final settings = context.watch<ShopProvider>().settings;
    final currency = settings?.currency ?? 'SAR';
    final accent = parseHexColor(settings?.accentColorHex ?? '0xFFC6CBD4');
    final dailyRev =
        SmartAnalytics.instance.dailyRevenueSeries(finance.entries);
    final dailyOps = SmartAnalytics.instance.dailyOpsSeries(finance.entries);
    final pending = appointments.pendingRequests.length;
    final todayAppts = appointments.todayAppointments.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const _Header(),
        const SizedBox(height: 14),
        const _SectionTitle('ملخص اليوم'),
        const SizedBox(height: 8),
        _KpiGrid(
          currency: currency,
          accent: accent,
          todayRevenue: report.today.revenue,
          todayOps: report.today.salesOps > 0
              ? report.today.salesOps
              : report.today.bookings,
          todayNet: report.today.netProfit,
          monthNet: report.thisMonth.netProfit,
          pending: pending,
          todayAppts: todayAppts,
        ),
        const SizedBox(height: 14),
        const _SectionTitle('مقارنة الإيراد'),
        const SizedBox(height: 8),
        _CompareCard(report: report, currency: currency),
        const SizedBox(height: 14),
        const _SectionTitle('تشغيل سريع'),
        const SizedBox(height: 8),
        const _QuickActions(),
        const SizedBox(height: 14),
        const _SectionTitle('الإيراد — آخر 7 أيام'),
        const SizedBox(height: 8),
        _BarChartCard(
          daily: dailyRev,
          color: accent,
          emptyHint: 'سجّل وارد الزبائن ليظهر الرسم',
          valueSuffix: currency,
        ),
        const SizedBox(height: 14),
        const _SectionTitle('العمليات — آخر 7 أيام'),
        const SizedBox(height: 8),
        _BarChartCard(
          daily: dailyOps,
          color: const Color(0xFF059669),
          emptyHint: 'لا عمليات مسجّلة بعد',
          valueSuffix: '',
          isCount: true,
        ),
        const SizedBox(height: 14),
        const _SectionTitle('توقع الإيراد — 7 أيام قادمة'),
        const SizedBox(height: 4),
        Text(
          report.forecastConfidence.isNotEmpty
              ? 'ثقة النموذج: ${report.forecastConfidence}'
              : 'حساب محلي من متوسط متحرك + اتجاه (بدون أدوات مدفوعة)',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        _ForecastCard(values: report.forecastNext7, currency: currency),
        const SizedBox(height: 14),
        const _SectionTitle('أبرز النقاط'),
        const SizedBox(height: 8),
        _HighlightsCard(report: report, currency: currency),
        const SizedBox(height: 14),
        const _SectionTitle('هذا الشهر مقابل السابق'),
        const SizedBox(height: 8),
        _MonthVsCard(report: report, currency: currency),
        const SizedBox(height: 14),
        const _SectionTitle('رؤى ذكية'),
        const SizedBox(height: 8),
        ...report.insights.map((i) => _InsightTile(insight: i)),
        if (report.insights.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'سجّل الوارد والمصاريف بانتظام لتظهر الرؤى هنا.',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

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
          shopName.isEmpty ? 'لوحة التحكم' : shopName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormat('EEEE, d MMMM yyyy', Intl.getCurrentLocale()).format(now),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.currency,
    required this.accent,
    required this.todayRevenue,
    required this.todayOps,
    required this.todayNet,
    required this.monthNet,
    required this.pending,
    required this.todayAppts,
  });

  final String currency;
  final Color accent;
  final double todayRevenue;
  final int todayOps;
  final double todayNet;
  final double monthNet;
  final int pending;
  final int todayAppts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.payments_rounded,
                label: 'إيراد اليوم',
                value: fmtPrice(todayRevenue, currency),
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiTile(
                icon: Icons.receipt_long_rounded,
                label: 'عمليات اليوم',
                value: '$todayOps',
                color: const Color(0xFF059669),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.trending_up_rounded,
                label: 'صافي اليوم',
                value: fmtPrice(todayNet, currency),
                color: todayNet >= 0
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiTile(
                icon: Icons.calendar_month_rounded,
                label: 'صافي الشهر',
                value: fmtPrice(monthNet, currency),
                color: monthNet >= 0
                    ? const Color(0xFF0EA5E9)
                    : const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.event_available_rounded,
                label: 'مواعيد اليوم',
                value: '$todayAppts',
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiTile(
                icon: Icons.hourglass_top_rounded,
                label: 'طلبات معلّقة',
                value: '$pending',
                color: pending > 0
                    ? const Color(0xFFD97706)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.report, required this.currency});
  final SmartAnalyticsReport report;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final pct = report.monthVsLast.revenuePct;
    final pctLabel = pct.isFinite
        ? '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%'
        : '—';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _mini('اليوم', fmtPrice(report.today.revenue, currency)),
            ),
            Expanded(
              child: _mini(
                  'هذا الأسبوع', fmtPrice(report.thisWeek.revenue, currency)),
            ),
            Expanded(
              child: _mini(
                'هذا الشهر',
                fmtPrice(report.thisMonth.revenue, currency),
                sub: 'مقابل السابق $pctLabel',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, String value, {String? sub}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10)),
        ],
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DayCloseScreen()),
            ),
            icon: const Icon(Icons.nightlight_round, size: 18),
            label: const Text('إغلاق اليوم'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomersToCallScreen()),
            ),
            icon: const Icon(Icons.phone_callback_outlined, size: 18),
            label: const Text('زبائن للاتصال'),
          ),
        ),
      ],
    );
  }
}

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({
    required this.daily,
    required this.color,
    required this.emptyHint,
    required this.valueSuffix,
    this.isCount = false,
  });

  final Map<DateTime, double> daily;
  final Color color;
  final String emptyHint;
  final String valueSuffix;
  final bool isCount;

  @override
  Widget build(BuildContext context) {
    final entries = daily.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final hasData = entries.any((e) => e.value > 0);
    final total = entries.fold<double>(0.0, (s, e) => s + e.value);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasData)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
                child: Text(
                  isCount
                      ? 'المجموع: ${total.toStringAsFixed(0)} عملية'
                      : 'المجموع: ${total.toStringAsFixed(0)} $valueSuffix',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            SizedBox(
              height: 168,
              child: !hasData
                  ? Center(
                      child: Text(
                        emptyHint,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        maxY: () {
                          final m = entries.fold<double>(
                              0.0, (x, e) => e.value > x ? e.value : x);
                          return m == 0 ? 10.0 : m * 1.25;
                        }(),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          ),
                        ),
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
                              reservedSize: 22,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i < 0 || i >= entries.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    DateFormat('E', Intl.getCurrentLocale())
                                        .format(entries[i].key),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
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
                                width: 14,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.values, required this.currency});
  final List<double> values;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final has = values.any((v) => v > 0);
    final sum = values.fold(0.0, (a, b) => a + b);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              child: !has
                  ? Center(
                      child: Text(
                        'يحتاج بيانات وارد تاريخية لبناء التوقع',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt() + 1;
                                if (i < 1 || i > values.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'ي$i',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < values.length; i++)
                                FlSpot(i.toDouble(), values[i]),
                            ],
                            isCurved: true,
                            color: const Color(0xFF7C3AED),
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color:
                                  const Color(0xFF7C3AED).withOpacity(0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (has) ...[
              const SizedBox(height: 8),
              Text(
                'مجموع متوقع للأسبوع: ${fmtPrice(sum, currency)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({required this.report, required this.currency});
  final SmartAnalyticsReport report;
  final String currency;

  String _hourLabel(int h) {
    final period = h < 12 ? 'ص' : 'م';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12 $period';
  }

  @override
  Widget build(BuildContext context) {
    final peak = report.peakHourRatio > 0
        ? '${_hourLabel(report.peakHour)} '
            '(${(report.peakHourRatio * 100).toStringAsFixed(0)}%)'
        : '—';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.content_cut_rounded),
            title: const Text('الخدمة الأكثر طلباً'),
            subtitle: Text(report.topServiceName ?? '—'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.person_rounded),
            title: const Text('أفضل أداء'),
            subtitle: Text(report.topStaffName ?? '—'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('ساعة الذروة'),
            subtitle: Text(peak),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_rounded),
            title: const Text('صافي ربح الشهر'),
            subtitle: Text(
              fmtPrice(report.thisMonth.netProfit, currency),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: report.thisMonth.netProfit >= 0
                    ? const Color(0xFF059669)
                    : const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthVsCard extends StatelessWidget {
  const _MonthVsCard({required this.report, required this.currency});
  final SmartAnalyticsReport report;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final cur = report.thisMonth;
    final prev = report.lastMonth;
    final cmp = report.monthVsLast;

    String delta(double pct) {
      if (!pct.isFinite) return '—';
      return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%';
    }

    double opsPct() {
      if (prev.salesOps == 0 && cur.salesOps == 0) return double.nan;
      if (prev.salesOps == 0) return cur.salesOps > 0 ? 100.0 : 0.0;
      return ((cur.salesOps - prev.salesOps) / prev.salesOps) * 100;
    }

    Widget row(String label, double a, double b, double pct) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(
                label.contains('عمليات')
                    ? a.toStringAsFixed(0)
                    : fmtPrice(a, currency),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Text(
                label.contains('عمليات')
                    ? b.toStringAsFixed(0)
                    : fmtPrice(b, currency),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            Expanded(
              child: Text(
                delta(pct),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: !pct.isFinite
                      ? Colors.grey
                      : pct >= 0
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(flex: 2, child: SizedBox()),
                Expanded(
                  child: Text(
                    'الحالي',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'السابق',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'التغير',
                    textAlign: TextAlign.end,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            const Divider(),
            row('الإيراد', cur.revenue, prev.revenue, cmp.revenuePct),
            row('صافي الربح', cur.netProfit, prev.netProfit, cmp.netPct),
            row(
              'العمليات',
              cur.salesOps.toDouble(),
              prev.salesOps.toDouble(),
              opsPct(),
            ),
          ],
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
        InsightKind.warning => const Color(0xFFD97706),
        InsightKind.tip => const Color(0xFF7C3AED),
        InsightKind.info => const Color(0xFF0EA5E9),
      };

  IconData get _icon => switch (insight.kind) {
        InsightKind.positive => Icons.trending_up_rounded,
        InsightKind.warning => Icons.warning_amber_rounded,
        InsightKind.tip => Icons.lightbulb_outline_rounded,
        InsightKind.info => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _color.withOpacity(0.15),
          child: Icon(_icon, color: _color, size: 20),
        ),
        title: Text(
          insight.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(insight.body),
        isThreeLine: insight.body.length > 50,
      ),
    );
  }
}
