import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/finance/finance_models.dart';
import '../../../models/service.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/shop_provider.dart';

/// شاشة واحدة: وارد الزبائن = المبيعات + المدفوعات.
/// يحدّد نوع الوارد بدقة (مثل أجرة حلاقة شعر) من خدمات الصالون أو نص مخصص.
class DailySalesScreen extends StatefulWidget {
  const DailySalesScreen({super.key});

  @override
  State<DailySalesScreen> createState() => _DailySalesScreenState();
}

class _DailySalesScreenState extends State<DailySalesScreen> {
  static const _customServiceId = '__custom__';

  final _total = TextEditingController();
  final _material = TextEditingController(text: '0');
  final _percent = TextEditingController(text: '50');
  final _customer = TextEditingController();
  final _customService = TextEditingController();
  final _notes = TextEditingController();

  String? _barberId;
  String? _serviceId; // id من قائمة الخدمات أو __custom__
  PaymentMethod _payment = PaymentMethod.cash;
  bool _saving = false;

  @override
  void dispose() {
    _total.dispose();
    _material.dispose();
    _percent.dispose();
    _customer.dispose();
    _customService.dispose();
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

  void _onServicePicked(String? id, List<Service> services) {
    setState(() {
      _serviceId = id;
      if (id == null || id == _customServiceId) return;
      final match = services.where((s) => s.id == id).toList();
      if (match.isEmpty) return;
      final svc = match.first;
      // تعبئة المبلغ من سعر الخدمة إن كان الحقل فارغاً أو صفراً
      if (_totalValue <= 0 && svc.price > 0) {
        _total.text = svc.price.toStringAsFixed(0);
      }
    });
  }

  String _resolvedServiceName(List<Service> services) {
    if (_serviceId == _customServiceId || _serviceId == null) {
      return _customService.text.trim();
    }
    final match = services.where((s) => s.id == _serviceId).toList();
    if (match.isEmpty) return _customService.text.trim();
    return match.first.name.trim();
  }

  Future<void> _save() async {
    final shop = context.read<ShopProvider>();
    final f = context.read<FinanceProvider>();
    if (_totalValue <= 0) {
      _toast('أدخل المبلغ الإجمالي أولاً');
      return;
    }
    final serviceName = _resolvedServiceName(shop.services);
    if (serviceName.isEmpty) {
      _toast('حدّد نوع الوارد (مثال: أجرة حلاقة شعر)');
      return;
    }
    final matches = shop.employees.where((e) => e.id == _barberId).toList();
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
      serviceName: serviceName,
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
    _customService.clear();
    _notes.clear();
    setState(() {
      _saving = false;
      // نُبقي نوع الخدمة والحلاق لتسريع الإدخال المتتالي
    });
    _toast('تم تسجيل الوارد: $serviceName');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _paymentLabel(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return 'نقداً';
      case PaymentMethod.card:
        return 'بطاقة';
      case PaymentMethod.transfer:
        return 'حوالة';
      case PaymentMethod.other:
        return 'أخرى';
    }
  }

  /// تجميع الوارد حسب نوع الخدمة لملخص سريع.
  Map<String, double> _byService(List<DailyFinanceEntry> entries) {
    final map = <String, double>{};
    for (final e in entries) {
      final key = e.serviceName.trim().isEmpty ? 'غير محدد' : e.serviceName.trim();
      map[key] = (map[key] ?? 0) + e.totalAmount;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final f = context.watch<FinanceProvider>();
    final activeServices =
        shop.services.where((s) => s.active).toList();
    final byService = _byService(f.entries);

    return Scaffold(
      appBar: AppBar(
        title: const Text('وارد الزبائن'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // —— ملخص حسب نوع الوارد ——
          if (byService.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'ملخص الوارد حسب النوع',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const Spacer(),
                        Text(
                          'المجموع ${f.sumDailyTotal().toStringAsFixed(0)} ل.س',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...byService.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text('${e.value.toStringAsFixed(0)} ل.س'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // —— نموذج تسجيل ——
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تسجيل وارد من زبون',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'حدّد نوع الوارد بدقة (مثال: أجرة حلاقة شعر)، ثم المبلغ والحلاق وطريقة الدفع.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 12),

                  // نوع الوارد / الخدمة
                  DropdownButtonFormField<String>(
                    value: _serviceId,
                    isExpanded: true,
                    items: [
                      ...activeServices.map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            s.price > 0
                                ? '${s.name} — ${s.price.toStringAsFixed(0)} ل.س'
                                : s.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: _customServiceId,
                        child: Text('أخرى / مخصص...'),
                      ),
                    ],
                    onChanged: (v) => _onServicePicked(v, activeServices),
                    decoration: const InputDecoration(
                      labelText: 'نوع الوارد (الخدمة) *',
                      hintText: 'مثال: أجرة حلاقة شعر',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cut_rounded),
                    ),
                  ),
                  if (_serviceId == _customServiceId ||
                      (activeServices.isEmpty && _serviceId == null)) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customService,
                      decoration: const InputDecoration(
                        labelText: 'اكتب نوع الوارد *',
                        hintText: 'أجرة حلاقة شعر / صبغة / حلاقة ذقن...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  TextField(
                    controller: _total,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المحصّل (ل.س) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payments_outlined),
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
                      labelText: 'الحلاق *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _percent,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'نسبة الحلاق (%)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customer,
                    decoration: const InputDecoration(
                      labelText: 'اسم الزبون (اختياري)',
                      border: OutlineInputBorder(),
                    ),
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
                          value: PaymentMethod.transfer,
                          child: Text('حوالة')),
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
                        _calcRow('حصة الصالون (وارد المحل)', _salonShare,
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
                      label: Text(
                          _saving ? 'جارٍ الحفظ...' : 'حفظ الوارد'),
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
                'سجل الواردات',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const Spacer(),
              Text(
                '${f.entries.length} عملية',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (f.entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('لا توجد واردات مسجّلة بعد')),
            ),
          ...f.entries.map((d) => _entryCard(d, f)),
        ],
      ),
    );
  }

  Widget _entryCard(DailyFinanceEntry d, FinanceProvider f) {
    final serviceLabel =
        d.serviceName.trim().isEmpty ? 'وارد غير محدد' : d.serviceName.trim();
    final customer =
        d.customerName.trim().isEmpty ? 'زبون' : d.customerName.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            Icons.cut_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          serviceLabel,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '$customer • ${d.barberName}\n'
          '${d.date.toLocal().toString().split(' ').first} • '
          '${_paymentLabel(d.paymentMethod)} • '
          'إجمالي ${d.totalAmount.toStringAsFixed(0)} • '
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
