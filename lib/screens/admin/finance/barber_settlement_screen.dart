import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/finance/finance_models.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/shop_provider.dart';

class BarberSettlementScreen extends StatelessWidget {
  const BarberSettlementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final f = context.watch<FinanceProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('نسب ورواتب الحلاقين')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'حدد لكل حلاق نسبة مئوية أو راتباً ثابتاً. تُستخدم النسبة كقيمة افتراضية في المبيعات اليومية ويمكن تعديلها يدوياً لكل عملية.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (shop.employees.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('أضف حلاقين من شاشة الموظفين أولاً')),
            ),
          ...shop.employees.map((e) {
            final bs = f.barberSettlements.firstWhere(
              (x) => x.barberId == e.id,
              orElse: () => BarberSettlement(
                barberId: e.id,
                barberName: e.name,
                percent: 50,
              ),
            );
            return _BarberCard(barberId: e.id, barberName: e.name, initial: bs);
          }),
        ],
      ),
    );
  }
}

class _BarberCard extends StatefulWidget {
  const _BarberCard({
    required this.barberId,
    required this.barberName,
    required this.initial,
  });

  final String barberId;
  final String barberName;
  final BarberSettlement initial;

  @override
  State<_BarberCard> createState() => _BarberCardState();
}

class _BarberCardState extends State<_BarberCard> {
  late BarberPayType _payType;
  late final TextEditingController _value;

  @override
  void initState() {
    super.initState();
    _payType = widget.initial.payType;
    _value = TextEditingController(
      text: _payType == BarberPayType.percent
          ? widget.initial.percent.toStringAsFixed(0)
          : widget.initial.fixedRate.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(covariant _BarberCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.initial;
    final old = oldWidget.initial;
    if (incoming.payType != old.payType ||
        incoming.percent != old.percent ||
        incoming.fixedRate != old.fixedRate) {
      _payType = incoming.payType;
      _value.text = _payType == BarberPayType.percent
          ? incoming.percent.toStringAsFixed(0)
          : incoming.fixedRate.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  BarberSettlement _current() {
    final numv = double.tryParse(_value.text.replaceAll(',', '')) ?? 0;
    return BarberSettlement(
      barberId: widget.barberId,
      barberName: widget.barberName,
      payType: _payType,
      percent: _payType == BarberPayType.percent ? numv : widget.initial.percent,
      fixedRate: _payType == BarberPayType.fixed
          ? numv
          : widget.initial.fixedRate,
    );
  }

  Future<void> _save() async {
    await context.read<FinanceProvider>().saveBarber(_current());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ إعداد الحلاق')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.barberName,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<BarberPayType>(
                    value: _payType,
                    items: const [
                      DropdownMenuItem(
                          value: BarberPayType.percent,
                          child: Text('نسبة مئوية %')),
                      DropdownMenuItem(
                          value: BarberPayType.fixed,
                          child: Text('راتب ثابت')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _payType = v;
                        _value.text =
                            v == BarberPayType.percent ? '50' : '0';
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'طريقة الحساب',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _value,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _payType == BarberPayType.percent
                          ? 'النسبة %'
                          : 'المبلغ الثابت ل.س',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
