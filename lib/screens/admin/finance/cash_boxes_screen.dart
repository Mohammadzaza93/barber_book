import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/finance_provider.dart';

class CashBoxesScreen extends StatelessWidget {
  const CashBoxesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();
    final split = f.dailySplit();
    return Scaffold(
      appBar: AppBar(title: const Text('تقسيم الأموال إلى الصناديق')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'توزيع حصة الصالون تلقائياً وفق النسب: 25% مولد، 25% مواد، 10% غسيل فوط، والباقي صافي ربح.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _card('صندوق أجور الحلاقين', split.barberWages,
              Icons.people_alt_rounded),
          _card('صندوق تشغيل المولد / الأمبيرات', split.generatorFuel,
              Icons.bolt_rounded),
          _card('صندوق تجديد المواد الأسبوعي', split.operatingMaterials,
              Icons.cleaning_services_rounded),
          _card('أجور غسيل الفوط', split.laundryTowels,
              Icons.local_laundry_service_rounded),
          _card('صافي ربح صاحب الصالون', split.netProfit, Icons.savings_rounded,
              highlight: true),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ملاحظات',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  SizedBox(height: 6),
                  Text(
                      '• تكلفة المواد المكلفة (صبغة/بروتين) تُخصم من قيمة الزبون أولاً قبل حساب النسبة.\n'
                      '• نسبة الحلاق تُدخل يدوياً لكل عملية ويمكن تعديلها.\n'
                      '• حصة الصالون ليست ربحاً صافياً قبل اقتطاع المصاريف التشغيلية.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, double amount, IconData icon,
      {bool highlight = false}) {
    return Card(
      color: highlight ? Colors.green.shade50 : null,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          '${amount.toStringAsFixed(0)} ل.س',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: highlight ? Colors.green.shade800 : null,
          ),
        ),
      ),
    );
  }
}
