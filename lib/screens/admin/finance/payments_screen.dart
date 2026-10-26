import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../l10n/strings.dart';
import '../../../models/business_features.dart';
import '../../../providers/business_tools_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../widgets/confirm.dart';
import '../discounts_screen.dart';

/// سجل المدفوعات — ضمن قسم المالية والمحاسبة.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  Future<void> _addPayment(BuildContext context) async {
    final customer = TextEditingController();
    final phone = TextEditingController();
    final amount = TextEditingController();
    final materialCost = TextEditingController(text: '0');
    final appointment = TextEditingController();
    final tools = context.read<BusinessToolsProvider>();
    final shop = context.read<ShopProvider>();
    String? chairId =
        tools.chairs.where((chair) => chair.active).firstOrNull?.id;
    String? employeeId;
    String method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(t(context).paymentDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: customer,
                  decoration:
                      InputDecoration(labelText: t(context).customerNameField),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      InputDecoration(labelText: t(context).customerPhoneField),
                ),
                TextField(
                  controller: appointment,
                  decoration:
                      InputDecoration(labelText: t(context).appointmentRefField),
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: t(context).amountCollected),
                ),
                TextField(
                  controller: materialCost,
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: t(context).materialCostField),
                ),
                if (tools.chairs.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: chairId,
                    decoration:
                        InputDecoration(labelText: t(context).chairField),
                    items: tools.chairs
                        .where((chair) => chair.active)
                        .map(
                          (chair) => DropdownMenuItem(
                            value: chair.id,
                            child: Text(
                              chair.number.isEmpty
                                  ? chair.name
                                  : t(context).chairLabel(
                                      chair.number, chair.name),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => chairId = value),
                  ),
                DropdownButtonFormField<String>(
                  value: employeeId,
                  decoration: InputDecoration(labelText: t(context).employee),
                  items: shop.activeEmployees
                      .map(
                        (employee) => DropdownMenuItem(
                          value: employee.id,
                          child: Text(employee.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => employeeId = value),
                ),
                DropdownButtonFormField<String>(
                  value: method,
                  items: [
                    DropdownMenuItem(
                        value: 'cash', child: Text(t(context).payCash)),
                    DropdownMenuItem(
                        value: 'card', child: Text(t(context).payCard)),
                    DropdownMenuItem(
                        value: 'transfer',
                        child: Text(t(context).payTransfer)),
                  ],
                  onChanged: (v) => setState(() => method = v ?? 'cash'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t(context).save),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final value = double.tryParse(amount.text);
    if (value == null || value <= 0) return;
    final cost = double.tryParse(materialCost.text) ?? 0;
    try {
      await tools.addPayment(
        Payment(
          id: tools.newId(),
          appointmentId: appointment.text.trim(),
          customerName: customer.text.trim(),
          customerPhone: phone.text.trim(),
          chairId: chairId,
          employeeId: employeeId,
          amount: value,
          materialCost: cost,
          method: method,
          paidAt: DateTime.now(),
        ),
      );
    } catch (error) {
      debugPrint('recordPayment unexpected failure: $error');
      if (context.mounted) showSnack(context, t(context).error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final total = tools.payments.fold<double>(0, (sum, p) => sum + p.amount);
    final materialTotal =
        tools.payments.fold<double>(0, (sum, p) => sum + p.materialCost);
    final currency =
        context.watch<ShopProvider>().settings?.currency ?? 'SAR';

    return Scaffold(
      appBar: AppBar(title: Text(t(context).tabPayments)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'finance_payments_fab',
        onPressed: () => _addPayment(context),
        icon: const Icon(Icons.add_card),
        label: Text(t(context).recordPayment),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: Text(t(context).salesCard),
                    subtitle: Text(fmtPrice(total, currency)),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(t(context).materialsCard),
                    subtitle: Text(fmtPrice(materialTotal, currency)),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.trending_up),
                    title: Text(t(context).netCard),
                    subtitle: Text(fmtPrice(total - materialTotal, currency)),
                  ),
                ),
              ),
            ],
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_offer_outlined),
              title: Text(t(context).promoServicesTitle),
              subtitle: Text(t(context).promoServicesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiscountsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (tools.payments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  'لا توجد مدفوعات مسجّلة بعد',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ...tools.payments.map(
              (payment) => Card(
                child: ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(
                    payment.customerName.isEmpty
                        ? t(context).anonymousCustomer
                        : payment.customerName,
                  ),
                  subtitle: Text(
                    '${payment.method} · ${DateFormat('yyyy/MM/dd HH:mm').format(payment.paidAt)} · ${t(context).netShort} ${fmtPrice(payment.profit, currency)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fmtPrice(payment.amount, currency),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => tools.deletePayment(payment.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
