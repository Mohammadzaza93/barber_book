import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/finance/finance_models.dart';
import '../../../models/service.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../services/finance_pdf_export.dart';

/// شاشة وارد الزبائن — مقسّمة حتى لا يعيد setState بناء الملخص والسجل معاً.
class DailySalesScreen extends StatelessWidget {
  const DailySalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('وارد الزبائن'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _RevenueByServiceSummary(),
          SizedBox(height: 12),
          _NewRevenueForm(),
          SizedBox(height: 16),
          _EntriesHeader(),
          SizedBox(height: 8),
          _EntriesList(),
        ],
      ),
    );
  }
}

class _RevenueByServiceSummary extends StatelessWidget {
  const _RevenueByServiceSummary();

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();
    if (f.entries.isEmpty) return const SizedBox.shrink();

    final byService = <String, double>{};
    for (final e in f.entries) {
      final key =
          e.serviceName.trim().isEmpty ? 'غير محدد' : e.serviceName.trim();
      byService[key] = (byService[key] ?? 0) + e.totalAmount;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'ملخص الوارد حسب النوع',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  'المجموع ${f.sumDailyTotal().toStringAsFixed(0)}',
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(e.value.toStringAsFixed(0)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewRevenueForm extends StatefulWidget {
  const _NewRevenueForm();

  @override
  State<_NewRevenueForm> createState() => _NewRevenueFormState();
}

class _NewRevenueFormState extends State<_NewRevenueForm> {
  static const _customServiceId = '__custom__';

  final _total = TextEditingController();
  final _material = TextEditingController(text: '0');
  final _percent = TextEditingController(text: '50');
  final _customer = TextEditingController();
  final _customService = TextEditingController();
  final _notes = TextEditingController();
  final _tip = TextEditingController(text: '0');

  String? _barberId;
  String? _serviceId;
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
    _tip.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  double get _totalValue => _num(_total);
  double get _tipValue => _num(_tip).clamp(0, double.infinity).toDouble();
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
      _toast('أدخل أجرة الخدمة أولاً');
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
      tipAmount: _tipValue,
    );
    await f.addDailyEntry(entry);
    if (!mounted) return;
    _total.clear();
    _material.text = '0';
    _customer.clear();
    _customService.clear();
    _notes.clear();
    _tip.text = '0';
    setState(() => _saving = false);
    _toast('تم تسجيل الوارد: $serviceName');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final activeServices = shop.services.where((s) => s.active).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تسجيل وارد من زبون',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'حدّد نوع الوارد بدقة، ثم الأجرة والحلاق وطريقة الدفع. البقشيش اختياري ومنفصل.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _serviceId,
              isExpanded: true,
              items: [
                ...activeServices.map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      s.price > 0
                          ? '${s.name} — ${s.price.toStringAsFixed(0)}'
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
                labelText: 'أجرة الخدمة *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tip,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'بقشيش (اختياري)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.volunteer_activism_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _material,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'تكلفة المواد (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _barberId,
              isExpanded: true,
              items: shop.employees
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(e.name),
                    ),
                  )
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
            _SharePreview(
              netAfterMaterial: _netAfterMaterial,
              barberShare: _barberShare,
              salonShare: _salonShare,
              tip: _tipValue,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الوارد'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharePreview extends StatelessWidget {
  const _SharePreview({
    required this.netAfterMaterial,
    required this.barberShare,
    required this.salonShare,
    required this.tip,
  });

  final double netAfterMaterial;
  final double barberShare;
  final double salonShare;
  final double tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _CalcRow(label: 'الصافي بعد المواد', value: netAfterMaterial),
          _CalcRow(label: 'حصة الحلاق', value: barberShare),
          _CalcRow(
            label: 'حصة الصالون (وارد المحل)',
            value: salonShare,
            bold: true,
          ),
          if (tip > 0) _CalcRow(label: 'بقشيش', value: tip),
        ],
      ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  const _CalcRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value.toStringAsFixed(0), style: style),
        ],
      ),
    );
  }
}

class _EntriesHeader extends StatelessWidget {
  const _EntriesHeader();

  @override
  Widget build(BuildContext context) {
    final count = context.select<FinanceProvider, int>((f) => f.entries.length);
    return Row(
      children: [
        const Text(
          'سجل الواردات',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const Spacer(),
        Text(
          '$count عملية',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

enum _PeriodFilter { day, month, all }

class _EntriesList extends StatefulWidget {
  const _EntriesList();

  @override
  State<_EntriesList> createState() => _EntriesListState();
}

class _EntriesListState extends State<_EntriesList> {
  String? _barberId;
  String? _service;
  PaymentMethod? _payment;
  _PeriodFilter _period = _PeriodFilter.day;

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

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _PeriodFilter.day:
        return (startDay, DateTime(now.year, now.month, now.day, 23, 59, 59));
      case _PeriodFilter.month:
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case _PeriodFilter.all:
        return (DateTime(2000), DateTime(2100));
    }
  }

  List<DailyFinanceEntry> _filter(List<DailyFinanceEntry> all) {
    final (from, to) = _range();
    return all.where((e) {
      if (e.date.isBefore(from) || e.date.isAfter(to)) return false;
      if (_barberId != null && e.barberId != _barberId) return false;
      if (_service != null && e.serviceName != _service) return false;
      if (_payment != null && e.paymentMethod != _payment) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _exportPdf(List<DailyFinanceEntry> all) async {
    final shop = context.read<ShopProvider>();
    final (from, to) = _range();
    final currency = shop.settings?.currency ?? 'SAR';
    final name = shop.settings?.shopName ?? '';
    try {
      await FinancePdfExport.instance.sharePeriodSummary(
        entries: all,
        from: from,
        to: to,
        currency: currency,
        shopName: name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر التصدير: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = context
        .select<FinanceProvider, List<DailyFinanceEntry>>((f) => f.entries);
    final f = context.read<FinanceProvider>();
    final filtered = _filter(entries);

    final services = {
      for (final e in entries)
        if (e.serviceName.trim().isNotEmpty) e.serviceName
    }.toList()
      ..sort();
    final barbers = {
      for (final e in entries)
        if (e.barberId.isNotEmpty) e.barberId: e.barberName
    };

    final sumService = filtered.fold<double>(0, (s, e) => s + e.totalAmount);
    final sumTips = filtered.fold<double>(0, (s, e) => s + e.tipAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<_PeriodFilter>(
                        segments: const [
                          ButtonSegment(
                              value: _PeriodFilter.day, label: Text('اليوم')),
                          ButtonSegment(
                              value: _PeriodFilter.month, label: Text('الشهر')),
                          ButtonSegment(
                              value: _PeriodFilter.all, label: Text('الكل')),
                        ],
                        selected: {_period},
                        onSelectionChanged: (s) =>
                            setState(() => _period = s.first),
                      ),
                    ),
                    IconButton(
                      tooltip: 'تصدير PDF',
                      onPressed:
                          entries.isEmpty ? null : () => _exportPdf(entries),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  value: _barberId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الحلاق',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('كل الحلاقين')),
                    ...barbers.entries.map(
                      (e) => DropdownMenuItem(
                          value: e.key, child: Text(e.value)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _barberId = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: _service,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الخدمة',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('كل الخدمات')),
                    ...services.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _service = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PaymentMethod?>(
                  value: _payment,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'طريقة الدفع',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('كل الطرق')),
                    DropdownMenuItem(
                        value: PaymentMethod.cash, child: Text('نقداً')),
                    DropdownMenuItem(
                        value: PaymentMethod.card, child: Text('بطاقة')),
                    DropdownMenuItem(
                        value: PaymentMethod.transfer, child: Text('حوالة')),
                    DropdownMenuItem(
                        value: PaymentMethod.other, child: Text('أخرى')),
                  ],
                  onChanged: (v) => setState(() => _payment = v),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'أجور: ${sumService.toStringAsFixed(0)}  •  بقشيش: ${sumTips.toStringAsFixed(0)}  •  ${filtered.length} عملية',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('لا توجد واردات ضمن التصفية')),
          )
        else
          for (final d in filtered)
            _EntryCard(
              entry: d,
              paymentLabel: _paymentLabel(d.paymentMethod),
              onDelete: () => f.deleteDailyEntry(d.id),
            ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.paymentLabel,
    required this.onDelete,
  });

  final DailyFinanceEntry entry;
  final String paymentLabel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final serviceLabel = entry.serviceName.trim().isEmpty
        ? 'وارد غير محدد'
        : entry.serviceName.trim();
    final customer =
        entry.customerName.trim().isEmpty ? 'زبون' : entry.customerName.trim();
    final dateStr = entry.date.toLocal().toString().split(' ').first;
    final tipPart = entry.tipAmount <= 0
        ? ''
        : ' + بقشيش ${entry.tipAmount.toStringAsFixed(0)}';

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
          '$customer • ${entry.barberName}\n'
          '$dateStr • $paymentLabel • '
          'أجرة ${entry.totalAmount.toStringAsFixed(0)}$tipPart'
          ' • صالون ${entry.salonShare.toStringAsFixed(0)}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
