import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/strings.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/shop_manager.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/stat_card.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>();
    final currency = context.read<ShopProvider>().settings?.currency ?? 'SAR';
    final analytics = AnalyticsService.instance;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthTotal =
        analytics.totalExpenses(expenses.expenses, from: monthStart);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.payments_outlined,
                    label: t(context).totalExpenses,
                    value: fmtPrice(
                        analytics.totalExpenses(expenses.expenses), currency),
                    color: const Color(0xFFB91C1C),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.calendar_month_rounded,
                    label: t(context).expensesThisMonth,
                    value: fmtPrice(monthTotal, currency),
                    color: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: expenses.expenses.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: t(context).expenses,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: expenses.expenses.length,
                    itemBuilder: (context, i) {
                      final e = expenses.expenses[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.withOpacity(0.1),
                            child: const Icon(Icons.receipt_rounded,
                                color: Colors.redAccent),
                          ),
                          title: Text(e.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${_catLabel(context, e.category)} · ${_fmtDate(e.date)}',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                fmtPrice(e.amount, currency),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.redAccent),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final ok = await confirmDialog(context,
                                      title: t(context).deleteExpenseConfirm,
                                      confirmText: t(context).delete,
                                      destructive: true);
                                  if (ok && context.mounted) {
                                    await context
                                        .read<ExpenseProvider>()
                                        .delete(e.id, ShopManager.shopId!);
                                  }
                                },
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 20),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(t(context).addExpense),
      ),
    );
  }

  String _catLabel(BuildContext context, String category) {
    switch (category) {
      case 'products': return t(context).expProducts;
      case 'supplies': return t(context).expSupplies;
      case 'rent': return t(context).expRent;
      case 'utilities': return t(context).expUtilities;
      case 'equipment': return t(context).expEquipment;
      case 'marketing': return t(context).expMarketing;
      default: return t(context).expOther;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _edit(BuildContext context, {Expense? expense}) async {
    final title = TextEditingController(text: expense?.title ?? '');
    final amount =
        TextEditingController(text: expense?.amount.toString() ?? '');
    final notes = TextEditingController(text: expense?.notes ?? '');
    var category = expense?.category ?? 'supplies';
    var date = expense?.date ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(expense == null
              ? t(ctx).addExpense
              : t(ctx).editExpense),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LabeledField(
                  label: t(ctx).expenseTitle,
                  child: TextField(controller: title),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: t(ctx).price,
                  child: TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration:
                      InputDecoration(labelText: t(ctx).expenseCategory),
                  items: [
                    'products', 'supplies', 'rent', 'utilities', 'equipment', 'marketing', 'other',
                  ].map((c) {
                    return DropdownMenuItem(
                        value: c, child: Text(_catLabel(ctx, c)));
                  }).toList(),
                  onChanged: (v) => setState(() => category = v ?? 'other'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded),
                  title: Text(_fmtDate(date)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(DateTime.now().year + 2),
                    );
                    if (picked != null) setState(() => date = picked);
                  },
                ),
                LabeledField(
                  label: t(ctx).notes,
                  child: TextField(controller: notes),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t(ctx).cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                final data = Expense(
                  id: expense?.id ?? const Uuid().v4(),
                  title: title.text.trim(),
                  category: category,
                  amount: double.tryParse(amount.text) ?? 0,
                  date: date,
                  notes: notes.text.trim(),
                );
                final provider = context.read<ExpenseProvider>();
                final shopId = ShopManager.shopId!;
                if (expense == null) {
                  await provider.add(data, shopId);
                } else {
                  await provider.update(data, shopId);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(t(ctx).save),
            ),
          ],
        ),
      ),
    );
  }
}
