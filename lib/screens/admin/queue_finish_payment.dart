import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/strings.dart';
import '../../models/business_features.dart';
import '../../models/finance/finance_models.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/shop_provider.dart';

/// ينهي خدمة الطابور ويسجّل أجرة الزبون في المالية.
class QueueFinishPayment {
  static Future<void> show(BuildContext context, QueueEntry entry) async {
    final tools = context.read<BusinessToolsProvider>();
    final shop = context.read<ShopProvider>();
    final finance = context.read<FinanceProvider>();
    final activeServices = shop.activeServices;

    String? serviceId =
        activeServices.isEmpty ? null : activeServices.first.id;
    final amountCtrl = TextEditingController(
      text: activeServices.isEmpty
          ? ''
          : activeServices.first.price.toStringAsFixed(0),
    );
    final materialCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController(
      text: 'من الطابور — ${entry.customerName}',
    );
    PaymentMethod payMethod = PaymentMethod.cash;

    String? barberId = entry.employeeId.isNotEmpty ? entry.employeeId : null;
    if (barberId == null ||
        !shop.activeEmployees.any((e) => e.id == barberId)) {
      barberId = shop.activeEmployees.isEmpty
          ? null
          : shop.activeEmployees.first.id;
    }

    double percent = 50;
    for (final s in finance.barberSettlements) {
      if (s.barberId == barberId && s.payType == BarberPayType.percent) {
        percent = s.percent;
        break;
      }
    }
    final percentCtrl = TextEditingController(text: percent.toStringAsFixed(0));

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          double numOf(TextEditingController c) =>
              double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;
          final total = numOf(amountCtrl);
          final material = numOf(materialCtrl);
          final pct = numOf(percentCtrl).clamp(0, 100);
          final net = (total - material).clamp(0, double.infinity);
          final barberShare = net * pct / 100;
          final salonShare = net - barberShare;

          return AlertDialog(
            title: const Text('تحصيل أجرة الزبون'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(entry.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (entry.customerPhone.isNotEmpty)
                    Text(entry.customerPhone,
                        style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                  if (activeServices.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: serviceId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'الخدمة / نوع الأجرة',
                        border: OutlineInputBorder(),
                      ),
                      items: activeServices
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                '${s.name} — ${s.price.toStringAsFixed(0)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() {
                        serviceId = v;
                        final svc =
                            activeServices.where((s) => s.id == v).firstOrNull;
                        if (svc != null && svc.price > 0) {
                          amountCtrl.text = svc.price.toStringAsFixed(0);
                        }
                      }),
                    )
                  else
                    const Text(
                      'لا توجد خدمات معرّفة — أدخل المبلغ يدوياً',
                      style: TextStyle(fontSize: 12),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ الإجمالي',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: materialCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'تكلفة مواد (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 10),
                  if (shop.activeEmployees.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: barberId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: t(context).assignedBarberField,
                        border: const OutlineInputBorder(),
                      ),
                      items: shop.activeEmployees
                          .map((e) => DropdownMenuItem(
                              value: e.id, child: Text(e.name)))
                          .toList(),
                      onChanged: (v) => setLocal(() {
                        barberId = v;
                        for (final s in finance.barberSettlements) {
                          if (s.barberId == v &&
                              s.payType == BarberPayType.percent) {
                            percentCtrl.text = s.percent.toStringAsFixed(0);
                            break;
                          }
                        }
                      }),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: percentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نسبة الحلاق %',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<PaymentMethod>(
                    value: payMethod,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'طريقة الدفع',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: PaymentMethod.cash, child: Text('نقداً')),
                      DropdownMenuItem(
                          value: PaymentMethod.card, child: Text('بطاقة')),
                      DropdownMenuItem(
                          value: PaymentMethod.transfer, child: Text('حوالة')),
                      DropdownMenuItem(
                          value: PaymentMethod.other, child: Text('أخرى')),
                    ],
                    onChanged: (v) =>
                        setLocal(() => payMethod = v ?? PaymentMethod.cash),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'صافي بعد المواد: ${net.toStringAsFixed(0)}  •  '
                    'حصة الحلاق: ${barberShare.toStringAsFixed(0)}  •  '
                    'الصالون: ${salonShare.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'skip'),
                child: const Text('إنهاء بدون دفع'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: Text(t(context).cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'pay'),
                child: const Text('تحصيل وإنهاء'),
              ),
            ],
          );
        },
      ),
    );

    final amountText = amountCtrl.text;
    final materialText = materialCtrl.text;
    final percentText = percentCtrl.text;
    final notesText = notesCtrl.text;
    final selectedServiceId = serviceId;
    final selectedBarberId = barberId;
    final selectedPay = payMethod;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      amountCtrl.dispose();
      materialCtrl.dispose();
      percentCtrl.dispose();
      notesCtrl.dispose();
    });

    if (result == null || result == 'cancel' || !context.mounted) return;

    await tools.saveQueue(
      entry.copyWith(
        status: QueueStatus.completed,
        completedAt: DateTime.now(),
      ),
    );

    if (result == 'skip') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنهاء الخدمة بدون تسجيل دفع')),
      );
      return;
    }

    final total = double.tryParse(amountText.replaceAll(',', '').trim()) ?? 0;
    if (total <= 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغاً صحيحاً للأجرة')),
      );
      return;
    }

    final material =
        double.tryParse(materialText.replaceAll(',', '').trim()) ?? 0;
    final pct = (double.tryParse(percentText.replaceAll(',', '').trim()) ?? 50)
        .clamp(0, 100)
        .toDouble();
    final net = (total - material).clamp(0, double.infinity).toDouble();
    final barberShare = net * pct / 100;
    final salonShare = net - barberShare;

    String serviceName = 'أجرة خدمة';
    if (selectedServiceId != null) {
      final svc =
          activeServices.where((s) => s.id == selectedServiceId).firstOrNull;
      if (svc != null) serviceName = svc.name;
    }

    final barber = shop.activeEmployees
        .where((e) => e.id == selectedBarberId)
        .firstOrNull;
    final barberName = barber?.name ?? '';
    final barberIdFinal = barber?.id ?? selectedBarberId ?? '';

    await finance.addDailyEntry(
      DailyFinanceEntry(
        id: const Uuid().v4(),
        date: DateTime.now(),
        customerName: entry.customerName,
        serviceName: serviceName,
        totalAmount: total,
        barberId: barberIdFinal,
        barberName: barberName,
        barberPercent: pct,
        materialCost: material,
        netAfterMaterial: net,
        barberShare: barberShare,
        salonShare: salonShare,
        paymentMethod: selectedPay,
        notes: notesText.trim().isEmpty ? 'من الطابور' : notesText.trim(),
        manualBarberShare: true,
      ),
    );

    await tools.addPayment(
      Payment(
        id: const Uuid().v4(),
        appointmentId: '',
        customerName: entry.customerName,
        customerPhone: entry.customerPhone,
        chairId: entry.chairId,
        employeeId: barberIdFinal,
        amount: total,
        materialCost: material,
        method: selectedPay.name,
        paidAt: DateTime.now(),
        notes: 'من الطابور — $serviceName',
      ),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تحصيل $serviceName: ${total.toStringAsFixed(0)}'),
      ),
    );
  }
}
