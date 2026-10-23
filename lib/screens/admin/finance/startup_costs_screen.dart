import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/finance/finance_models.dart';
import '../../../providers/finance_provider.dart';

class StartupCostsScreen extends StatefulWidget {
  const StartupCostsScreen({super.key});

  @override
  State<StartupCostsScreen> createState() => _StartupCostsScreenState();
}

class _StartupCostsScreenState extends State<StartupCostsScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final amt = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    if (_title.text.trim().isEmpty || amt <= 0) return;
    final c = StartupCost(
      id: const Uuid().v4(),
      title: _title.text.trim(),
      amountSyp: amt,
      date: DateTime.now(),
    );
    await context.read<FinanceProvider>().addStartupCost(c);
    _title.clear();
    _amount.clear();
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('التكاليف التأسيسية')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText:
                          'البند (إيجار مقدم / تراخيص / ديكور / معدات...)',
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
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إضافة بند'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: f.startupCosts.length,
              itemBuilder: (_, i) {
                final c = f.startupCosts[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(c.title),
                    subtitle: Text(
                        c.date.toLocal().toString().split(' ')[0]),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${c.amountSyp.toStringAsFixed(0)} ل.س'),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () =>
                              f.deleteStartupCost(c.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'المجموع: ${f.sumStartup().toStringAsFixed(0)} ل.س',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
