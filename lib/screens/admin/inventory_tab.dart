import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/business_features.dart';
import '../../providers/business_tools_provider.dart';

class InventoryTab extends StatelessWidget {
  const InventoryTab({super.key});

  Future<void> _showItemDialog(BuildContext context, {InventoryItem? item}) async {
    final name = TextEditingController(text: item?.name ?? '');
    final sku = TextEditingController(text: item?.sku ?? '');
    final category = TextEditingController(text: item?.category ?? 'general');
    final unit = TextEditingController(text: item?.unit ?? 'piece');
    final quantity = TextEditingController(text: item?.quantity.toString() ?? '0');
    final cost = TextEditingController(text: item?.unitCost.toString() ?? '0');
    final reorder = TextEditingController(text: item?.reorderLevel.toString() ?? '0');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item == null ? 'مادة جديدة' : 'تعديل المادة'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المادة')),
            TextField(controller: sku, decoration: const InputDecoration(labelText: 'رمز / SKU')),
            TextField(controller: category, decoration: const InputDecoration(labelText: 'التصنيف')),
            TextField(controller: unit, decoration: const InputDecoration(labelText: 'الوحدة')),
            TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الكمية الحالية')),
            TextField(controller: cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'تكلفة الوحدة (آخر شراء)')),
            TextField(controller: reorder, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'حد إعادة الطلب')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
        ],
      ),
    );
    final nameValue = name.text.trim();
    final skuValue = sku.text.trim();
    final categoryValue = category.text.trim();
    final unitValue = unit.text.trim();
    final quantityValue = double.tryParse(quantity.text.replaceAll(',', '.')) ?? 0;
    final costValue = double.tryParse(cost.text.replaceAll(',', '.')) ?? 0;
    final reorderValue = double.tryParse(reorder.text.replaceAll(',', '.')) ?? 0;
    name.dispose(); sku.dispose(); category.dispose(); unit.dispose(); quantity.dispose(); cost.dispose(); reorder.dispose();
    if (saved != true || !context.mounted || nameValue.isEmpty) return;
    final tools = context.read<BusinessToolsProvider>();
    final now = DateTime.now();
    await tools.saveInventoryItem(InventoryItem(
      id: item?.id ?? const Uuid().v4(),
      name: nameValue,
      sku: skuValue,
      category: categoryValue.isEmpty ? 'general' : categoryValue,
      unit: unitValue.isEmpty ? 'piece' : unitValue,
      quantity: quantityValue,
      unitCost: costValue,
      reorderLevel: reorderValue,
      createdAt: item?.createdAt ?? now,
      updatedAt: now,
      active: item?.active ?? true,
    ));
  }

  Future<void> _showMovementDialog(BuildContext context, InventoryItem item, String type) async {
    final quantity = TextEditingController();
    final unitCost = TextEditingController(text: item.unitCost.toString());
    final reason = TextEditingController();
    final labels = {
      'purchase': 'شراء وإضافة للمخزون',
      'usage': 'صرف يدوي',
      'waste': 'هدر أو تلف',
      'adjustment': 'جرد وتصحيح الرصيد',
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(labels[type] ?? 'حركة مخزون'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: type == 'adjustment' ? 'الرصيد الفعلي بعد الجرد' : 'الكمية',
            ),
          ),
          if (type == 'purchase')
            TextField(
              controller: unitCost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'تكلفة الوحدة (تحدّث آخر شراء)'),
            ),
          TextField(
            controller: reason,
            decoration: InputDecoration(
              labelText: type == 'purchase' ? 'ملاحظة (اختياري)' : 'السبب (مطلوب)',
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تسجيل')),
        ],
      ),
    );
    final quantityValue = double.tryParse(quantity.text.replaceAll(',', '.')) ?? 0;
    final costValue = double.tryParse(unitCost.text.replaceAll(',', '.')) ?? item.unitCost;
    final reasonValue = reason.text.trim();
    quantity.dispose();
    unitCost.dispose();
    reason.dispose();
    if (saved != true || !context.mounted || quantityValue < 0) return;
    if (type != 'purchase' && reasonValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السبب مطلوب لصرف/هدر/جرد')),
      );
      return;
    }
    try {
      await context.read<BusinessToolsProvider>().applyInventoryMovement(
            InventoryMovement(
              id: const Uuid().v4(),
              itemId: item.id,
              type: type,
              quantity: quantityValue,
              unitCost: costValue,
              reason: reasonValue,
              createdAt: DateTime.now(),
            ),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل حركة المخزون')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final items = tools.inventory;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inventory_fab',
        onPressed: () => _showItemDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('مادة'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          _InventoryDashboard(items: items),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Card(
              child: ListTile(
                title: Text('لا مواد بعد'),
                subtitle: Text('أضف شامبو، صبغة، شفرات… ثم سجّل الشراء والصرف'),
              ),
            )
          else
            ...items.map((item) => Card(
                  child: ListTile(
                    leading: Icon(
                      item.outOfStock
                          ? Icons.warning_amber_rounded
                          : item.lowStock
                              ? Icons.inventory_2_outlined
                              : Icons.inventory_2,
                      color: item.outOfStock
                          ? Colors.red
                          : item.lowStock
                              ? Colors.orange
                              : null,
                    ),
                    title: Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${item.quantity.toStringAsFixed(2)} ${item.unit}'
                      '  •  قيمة ${item.stockValue.toStringAsFixed(2)}'
                      '${item.lowStock ? '  •  تحت الحد' : ''}'
                      '${!item.active ? '  •  معطّل' : ''}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showItemDialog(context, item: item);
                        }
                        if (value == 'purchase' ||
                            value == 'usage' ||
                            value == 'waste' ||
                            value == 'adjustment') {
                          _showMovementDialog(context, item, value);
                        }
                        if (value == 'delete') {
                          context
                              .read<BusinessToolsProvider>()
                              .deleteInventoryItem(item.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'purchase', child: Text('تسجيل شراء')),
                        PopupMenuItem(value: 'usage', child: Text('تسجيل صرف')),
                        PopupMenuItem(value: 'waste', child: Text('تسجيل هدر')),
                        PopupMenuItem(
                            value: 'adjustment', child: Text('جرد وتصحيح')),
                        PopupMenuDivider(),
                        PopupMenuItem(value: 'edit', child: Text('تعديل المادة')),
                        PopupMenuItem(
                            value: 'delete', child: Text('حذف / تعطيل')),
                      ],
                    ),
                  ),
                )),
          if (tools.inventoryMovements.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('آخر حركات المخزون',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...tools.inventoryMovements.take(30).map((movement) {
              final item = tools.inventory
                  .where((x) => x.id == movement.itemId)
                  .firstOrNull;
              final sign = movement.type == 'purchase'
                  ? '+'
                  : movement.type == 'adjustment'
                      ? '↔'
                      : '-';
              return Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(movement.type == 'purchase'
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline),
                  title: Text(
                      '${item?.name ?? 'مادة'}  $sign${movement.quantity.toStringAsFixed(2)}'),
                  subtitle: Text(
                    '${movement.reason.isEmpty ? _movementLabel(movement.type) : movement.reason}'
                    '  •  ${_movementLabel(movement.type)}'
                    '${movement.balanceAfter != null ? '  → ${movement.balanceAfter!.toStringAsFixed(2)}' : ''}',
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _movementLabel(String type) => switch (type) {
        'purchase' => 'شراء',
        'usage' => 'صرف',
        'waste' => 'هدر',
        'adjustment' => 'جرد',
        'damage' => 'تلف',
        'expiry' => 'انتهاء صلاحية',
        _ => 'حركة',
      };
}

class _InventoryDashboard extends StatelessWidget {
  const _InventoryDashboard({required this.items});
  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final active = items.where((i) => i.active).toList();
    final value = active.fold<double>(0, (s, i) => s + i.stockValue);
    final low = active.where((i) => i.lowStock).length;
    final out = active.where((i) => i.outOfStock).length;
    final exp = active.where((i) => i.isExpired || i.expiringSoon).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص المخزون (تكلفة آخر شراء)',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(label: Text('أصناف: ${active.length}')),
                Chip(label: Text('قيمة ≈ ${value.toStringAsFixed(0)}')),
                Chip(label: Text('تحت الحد: $low')),
                Chip(label: Text('نافد: $out')),
                Chip(label: Text('صلاحية: $exp')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
