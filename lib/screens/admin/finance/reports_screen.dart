import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/appointment_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../services/revenue_forecast.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();
    final appointments = context.watch<AppointmentProvider>().appointments;
    final total = f.sumDailyTotal();
    final barber = f.sumBarberShares();
    final salon = f.sumSalonShares();
    final startup = f.sumStartup();
    final expenses = f.sumExpenses();
    final net = salon - expenses;
    final afterAll = salon - expenses - startup;

    final series = RevenueForecastService.instance.buildSeries(
      financeEntries: f.entries,
      appointments: appointments,
    );
    final forecast = RevenueForecastService.instance.forecast(series);

    return Scaffold(
      appBar: AppBar(title: const Text('تقارير الأرباح والخسائر')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تقرير عام',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _row('إجمالي الإيرادات', total),
                  _row('حصة الحلاقين', barber),
                  _row('حصة الصالون', salon),
                  const Divider(),
                  _row('إجمالي المصاريف التشغيلية', expenses),
                  _row('إجمالي التكاليف التأسيسية', startup),
                  const Divider(),
                  _row('صافي بعد المصاريف التشغيلية', net,
                      bold: true,
                      color: net >= 0 ? Colors.green : Colors.red),
                  _row('صافي بعد كل التكاليف', afterAll,
                      bold: true,
                      color: afterAll >= 0 ? Colors.green : Colors.red),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ForecastCard(forecast: forecast),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ملخص العمليات',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _row('عدد عمليات المبيعات', f.entries.length.toDouble(),
                      isCount: true),
                  _row('عدد المصاريف المسجلة', f.expenses.length.toDouble(),
                      isCount: true),
                  _row('عدد بنود التأسيس', f.startupCosts.length.toDouble(),
                      isCount: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double value,
      {bool bold = false, Color? color, bool isCount = false}) {
    final text = isCount
        ? value.toStringAsFixed(0)
        : '${value.toStringAsFixed(0)} ل.س';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
          Text(
            text,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});

  final ForecastResult forecast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final empty = forecast.sampleDays == 0 || forecast.activeDays == 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded, color: cs.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'تنبؤ الإيرادات',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'تحليل محلي مجاني من بياناتك التاريخية (بدون خدمات مدفوعة).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (empty)
              Text(
                'لا توجد مبيعات كافية بعد. سجّل وارد الزبائن لعدة أيام ليظهر التوقع.',
                style: TextStyle(color: Colors.grey.shade700),
              )
            else ...[
              _metric('متوسط يومي (آخر فترة)', forecast.avgDaily),
              _metric('متوقع خلال 7 أيام', forecast.next7Days, emphasize: true),
              _metric('متوقع خلال 30 يوماً', forecast.next30Days),
              _metricText('الاتجاه', forecast.trendLabelAr),
              _metricText('مستوى الثقة', forecast.confidenceLabelAr),
              Text(
                'أيام فيها مبيعات ضمن العينة: ${forecast.activeDays} / ${forecast.sampleDays}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (forecast.nextWeek.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'تفصيل الأسبوع القادم',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...forecast.nextWeek.map((d) {
                  final label =
                      DateFormat('EEEE d/M', 'ar').format(d.date);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label),
                        Text(
                          '${d.amount.toStringAsFixed(0)} ل.س',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 8),
              Text(
                'ملاحظة: التوقع تقدير إحصائي وليس ضماناً. كلّما زادت أيام التسجيل زادت دقته.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, double value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            '${value.toStringAsFixed(0)} ل.س',
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: emphasize ? const Color(0xFF059669) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
