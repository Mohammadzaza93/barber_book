import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/finance/finance_models.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/shop_provider.dart';

class DailySalesScreen extends StatefulWidget {
  const DailySalesScreen({super.key});

  @override
  State<DailySalesScreen> createState() => _DailySalesScreenState();
}

class _DailySalesScreenState extends State<DailySalesScreen> {
  final _total = TextEditingController();
  final _material = TextEditingController(text: '0');
  final _percent = TextEditingController(text: '50');
  final _customer = TextEditingController();
  final _service = TextEditingController();
  final _notes = TextEditingController();

  String? _barberId;
  PaymentMethod _payment = PaymentMethod.cash;
  bool _saving = false;

  @override
  void dispose() {
    _total.dispose();
    _material.dispose();
    _percent.dispose();
    _customer.dispose();
    _service.dispose();
    _notes.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  double get _totalValue => _num(_total);
  double get _materialValue => _num(_material);
  double get _percentValue => _num(_percent).clamp(0, 100).toDouble();
  double get _netAfterMaterial =>
      (_totalValue - _materialValue).clamp(0, double.infinity).toDouble();
  double get _barberShare => _netAfterMaterial * _percentValue / 100;
  double get _salonShare => _netAfterMaterial - _barberShare;

  void _prefillForBarber(String? id) {
    if (id == null) return;
    final f = context.read<FinanceProvider>();
    for (final s in f.barberSettlements) {
      if (s.barberId == id && s.payType == BarberPayType.percent) {
        _percent.text = s.percent.toStringAsFixed(0);
        break;
      }
    }
  }

  Future<void> _save() async {
    final shop = context.read<ShopProvider>();
    final f = context.read<FinanceProvider>();
    if (_totalValue <= 0) {
      _toast('أدخل المبلغ الإجمالي أولاً');
      return;
    }
    final matches =
        shop.employees.where((e) => e.id == _barberId).toList();
    if (matches.isEmpty) {
      _toast('اختر الحلاق');
      return;
    }
    final barber = matches.first;
    setState(() => _saving = true);
    final entry = DailyFinanceEntry(
      id: const Uuid().v4(),
      date: DateTime.now(),
      customerName: _customer.text.trim(),
      serviceName: _service.text.trim(),
      totalAmount: _totalValue,
      barberId: barber.id,
      barberName: barber.name,
      barberPercent: _percentValue,
      materialCost: _materialValue,
      netAfterMaterial: _netAfterMaterial,
      barberShare: _barberShare,
      salonShare: _salonShare,
      paymentMethod: _payment,
      notes: _notes.text.trim(),
      manualBarberShare: true,
    );
    await f.addDailyEntry(entry);
    if (!mounted) return;
    _total.clear();
    _material.text = '0';
    _customer.clear();
    _service.clear();
    _notes.clear();
    setState(() => _saving = false);
    _toast('تم حفظ العملية');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final f = context.watch<FinanceProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('المبيعات اليومية')),
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
                    'تسجيل عملية جديدة',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'تُخصم تكلفة المواد أولاً، ثم تُحسب حصة الحلاق من الباقي، وحصة الصالون هي المتبقي.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _total,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ الإجمالي (ل.س)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _material,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'تكلفة المواد (صبغة/بروتين...) (ل.س)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _barberId,
                    items: shop.employees
                        .map((e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(e.name),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _barberId = v;
                        _prefillForBarber(v);
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'الحلاق',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _percent,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'نسبة الحلاق يدوياً (%)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customer,
                          decoration: const InputDecoration(
                            labelText: 'اسم الزبون (اختياري)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _service,
                          decoration: const InputDecoration(
                            labelText: 'الخدمة (اختياري)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<PaymentMethod>(
                    value: _payment,
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
                        setState(() => _payment = v ?? PaymentMethod.cash),
                    decoration: const InputDecoration(
                      labelText: 'طريقة الدفع',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notes,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _calcRow('الصافي بعد المواد', _netAfterMaterial),
                        _calcRow('حصة الحلاق', _barberShare),
                        _calcRow('حصة الصالون (المتبقي)', _salonShare,
                            bold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ العملية'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'آخر العمليات',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const Spacer(),
              Text(
                'الإجمالي: ${f.sumDailyTotal().toStringAsFixed(0)} ل.س',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (f.entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('لا توجد عمليات بعد')),
            ),
          ...f.entries.map((d) => _entryCard(d, f)),
        ],
      ),
    );
  }

  Widget _entryCard(DailyFinanceEntry d, FinanceProvider f) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          '${d.customerName.isEmpty ? 'زبون' : d.customerName} • ${d.barberName}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${d.date.toLocal().toString().split(' ')[0]} — '
          'إجمالي ${d.totalAmount.toStringAsFixed(0)} • '
          'مواد ${d.materialCost.toStringAsFixed(0)} • '
          'نسبة ${d.barberPercent.toStringAsFixed(0)}% • '
          'حلاق ${d.barberShare.toStringAsFixed(0)} • '
          'صالون ${d.salonShare.toStringAsFixed(0)} ل.س',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => f.deleteDailyEntry(d.id),
        ),
      ),
    );
  }

  Widget _calcRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
          Text('${value.toStringAsFixed(0)} ل.س',
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
        ],
      ),
    );
  }
}
