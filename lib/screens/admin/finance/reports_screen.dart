import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/finance_provider.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();
    final total = f.sumDailyTotal();
    final barber = f.sumBarberShares();
    final salon = f.sumSalonShares();
    final startup = f.sumStartup();
    final expenses = f.sumExpenses();
    final net = salon - expenses;
    final afterAll = salon - expenses - startup;

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
    final text = isCount ? value.toStringAsFixed(0) : '${value.toStringAsFixed(0)} ل.س';
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
