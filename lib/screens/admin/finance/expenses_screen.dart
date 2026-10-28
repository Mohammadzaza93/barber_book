import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/finance/finance_models.dart';
import '../../../providers/finance_provider.dart';

/// المصاريف التشغيلية — النموذج منفصل عن القائمة لتقليل rebuild.
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المصاريف التشغيلية')),
      body: const Column(
        children: [
          _ExpenseForm(),
          Expanded(child: _ExpenseList()),
          _ExpenseTotal(),
        ],
      ),
    );
  }
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm();

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  ExpenseType _type = ExpenseType.recurring;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final amt = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    if (_title.text.trim().isEmpty || amt <= 0) return;
    final e = OperatingExpense(
      id: const Uuid().v4(),
      title: _title.text.trim(),
      amountSyp: amt,
      date: DateTime.now(),
      type: _type,
    );
    await context.read<FinanceProvider>().addExpense(e);
    _title.clear();
    _amount.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText:
                    'البند (كهرباء / مياه / إنترنت / شفرات / معقمات / غسيل فوط / بنزين مولد)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ (ل.س)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ExpenseType>(
              isExpanded: true,
              value: _type,
              items: const [
                DropdownMenuItem(
                    value: ExpenseType.fixed, child: Text('ثابت')),
                DropdownMenuItem(
                    value: ExpenseType.recurring, child: Text('متجدد')),
                DropdownMenuItem(
                    value: ExpenseType.material, child: Text('مواد')),
                DropdownMenuItem(
                    value: ExpenseType.fuel, child: Text('وقود/مولد')),
                DropdownMenuItem(
                    value: ExpenseType.laundry, child: Text('غسيل فوط')),
                DropdownMenuItem(
                    value: ExpenseType.marketing, child: Text('تسويق')),
                DropdownMenuItem(
                    value: ExpenseType.other, child: Text('أخرى')),
              ],
              onChanged: (v) =>
                  setState(() => _type = v ?? ExpenseType.other),
              decoration: const InputDecoration(
                labelText: 'نوع المصروف',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة مصروف'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseList extends StatelessWidget {
  const _ExpenseList();

  @override
  Widget build(BuildContext context) {
    final expenses = context.select<FinanceProvider, List<OperatingExpense>>(
        (f) => f.expenses);
    final f = context.read<FinanceProvider>();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: expenses.length,
      itemBuilder: (_, i) {
        final e = expenses[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${e.type.name} • ${e.date.toLocal().toString().split(' ').first}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${e.amountSyp.toStringAsFixed(0)} ل.س'),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => f.deleteExpense(e.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExpenseTotal extends StatelessWidget {
  const _ExpenseTotal();

  @override
  Widget build(BuildContext context) {
    final total =
        context.select<FinanceProvider, double>((f) => f.sumExpenses());
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'المجموع: ${total.toStringAsFixed(0)} ل.س',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}
