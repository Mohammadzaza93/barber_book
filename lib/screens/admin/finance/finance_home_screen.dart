import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/finance_provider.dart';
import 'barber_settlement_screen.dart';
import 'cash_boxes_screen.dart';
import 'daily_sales_screen.dart';
import 'expenses_screen.dart';
import 'reports_screen.dart';
import 'startup_costs_screen.dart';

class FinanceHomeScreen extends StatelessWidget {
  const FinanceHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();
    final split = f.dailySplit();
    return Scaffold(
      appBar: AppBar(title: const Text('المالية والمحاسبة')),
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
                    'ملخص سريع',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _row('إجمالي التكاليف التأسيسية', f.sumStartup()),
                  _row('إجمالي المصاريف التشغيلية', f.sumExpenses()),
                  _row('إجمالي المبيعات', f.sumDailyTotal()),
                  _row('حصة الحلاقين', f.sumBarberShares()),
                  _row('حصة الصالون', f.sumSalonShares()),
                  const Divider(),
                  _row(
                    'صافي الربح بعد توزيع الصناديق',
                    split.netProfit,
                    bold: true,
                    color: split.netProfit >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _tile(
            context,
            'المبيعات اليومية',
            'أدخل كل عملية: المبلغ، الحلاق، النسبة يدوياً، وتكلفة المواد',
            Icons.point_of_sale_rounded,
            const DailySalesScreen(),
          ),
          _tile(
            context,
            'التكاليف التأسيسية',
            'الإيجار المقدم، التراخيص، الديكور، المعدات',
            Icons.home_repair_service_rounded,
            const StartupCostsScreen(),
          ),
          _tile(
            context,
            'المصاريف التشغيلية',
            'الكهرباء، المولد، الشفرات، غسيل الفوط',
            Icons.receipt_long_rounded,
            const ExpensesScreen(),
          ),
          _tile(
            context,
            'نسب ورواتب الحلاقين',
            'حدد لكل حلاق نسبة مئوية أو راتباً ثابتاً',
            Icons.groups_rounded,
            const BarberSettlementScreen(),
          ),
          _tile(
            context,
            'تقسيم الأموال إلى الصناديق',
            'أجور الحلاقين، المولد، المواد، غسيل الفوط، صافي الربح',
            Icons.account_balance_wallet_rounded,
            const CashBoxesScreen(),
          ),
          _tile(
            context,
            'تقارير الأرباح والخسائر',
            'الإيرادات والمصروفات وصافي ما تبقى',
            Icons.bar_chart_rounded,
            const ReportsScreen(),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double value,
      {bool bold = false, Color? color}) {
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
            '${value.toStringAsFixed(0)} ل.س',
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String title, String subtitle,
      IconData icon, Widget page) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => page)),
      ),
    );
  }
}
