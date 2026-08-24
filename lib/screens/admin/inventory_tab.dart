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
        title: Text(item == null ? 'إضافة مادة للمخزون' : 'تعديل مادة المخزون'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المادة')),
            TextField(controller: sku, decoration: const InputDecoration(labelText: 'رمز المادة (اختياري)')),
            Row(children: [
              Expanded(child: TextField(controller: category, decoration: const InputDecoration(labelText: 'الفئة'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'الوحدة'))),
            ]),
            Row(children: [
              Expanded(child: TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الرصيد الحالي'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'تكلفة الوحدة'))),
            ]),
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
    await tools.saveInventoryItem(InventoryItem(
      id: item?.id ?? const Uuid().v4(),
      name: nameValue,
      sku: skuValue,
      category: categoryValue.isEmpty ? 'general' : categoryValue,
      unit: unitValue.isEmpty ? 'piece' : unitValue,
      quantity: quantityValue,
      unitCost: costValue,
      reorderLevel: reorderValue,
      updatedAt: DateTime.now(),
      active: item?.active ?? true,
    ));
  }

  Future<void> _showMovementDialog(BuildContext context, InventoryItem item, String type) async {
    final quantity = TextEditingController();
    final unitCost = TextEditingController(text: item.unitCost.toString());
    final reason = TextEditingController();
    final labels = {'purchase': 'شراء وإضافة للمخزون', 'usage': 'صرف يدوي', 'waste': 'هدر أو تلف', 'adjustment': 'جرد وتصحيح الرصيد'};
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(labels[type] ?? 'حركة مخزون'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: quantity, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: type == 'adjustment' ? 'الرصيد الفعلي بعد الجرد' : 'الكمية')),
          if (type == 'purchase') TextField(controller: unitCost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'تكلفة الوحدة')),
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'السبب أو الملاحظة')),
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
    quantity.dispose(); unitCost.dispose(); reason.dispose();
    if (saved != true || !context.mounted || quantityValue < 0) return;
    try {
      await context.read<BusinessToolsProvider>().applyInventoryMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item.id,
        type: type,
        quantity: quantityValue,
        unitCost: costValue,
        reason: reasonValue,
        createdAt: DateTime.now(),
      ));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل حركة المخزون')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final lowStock = tools.inventory.where((item) => item.lowStock).length;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemDialog(context),
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('إضافة مادة'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            const Icon(Icons.inventory_2_outlined, size: 30),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('المخزون المركزي', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('${tools.inventory.length} مادة  •  $lowStock مواد تحت حد الطلب', style: TextStyle(color: Colors.grey.shade600)),
            ])),
          ]))),
          const SizedBox(height: 8),
          if (tools.inventory.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لم تتم إضافة مواد بعد'))))
          else
            ...tools.inventory.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _showItemDialog(context, item: item),
                leading: CircleAvatar(child: Icon(item.lowStock ? Icons.warning_amber_rounded : Icons.inventory_2_outlined, color: item.lowStock ? Colors.orange : null)),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${item.quantity.toStringAsFixed(2)} ${item.unit}  •  قيمة ${item.stockValue.toStringAsFixed(2)}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _showItemDialog(context, item: item);
                    if (value == 'purchase' || value == 'usage' || value == 'waste' || value == 'adjustment') _showMovementDialog(context, item, value);
                    if (value == 'delete') context.read<BusinessToolsProvider>().deleteInventoryItem(item.id);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'purchase', child: Text('تسجيل شراء')),
                    PopupMenuItem(value: 'usage', child: Text('تسجيل صرف')),
                    PopupMenuItem(value: 'waste', child: Text('تسجيل هدر')),
                    PopupMenuItem(value: 'adjustment', child: Text('جرد وتصحيح')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'edit', child: Text('تعديل المادة')),
                    PopupMenuItem(value: 'delete', child: Text('حذف المادة')),
                  ],
                ),
              ),
            )),
          if (tools.inventoryMovements.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('آخر حركات المخزون', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...tools.inventoryMovements.take(30).map((movement) {
              final item = tools.inventory.where((x) => x.id == movement.itemId).firstOrNull;
              final sign = movement.type == 'purchase' ? '+' : movement.type == 'adjustment' ? '↔' : '-';
              return Card(child: ListTile(
                dense: true,
                leading: Icon(movement.type == 'purchase' ? Icons.add_circle_outline : Icons.remove_circle_outline),
                title: Text('${item?.name ?? 'مادة محذوفة'}  $sign${movement.quantity.toStringAsFixed(2)}'),
                subtitle: Text('${movement.reason.isEmpty ? _movementLabel(movement.type) : movement.reason}  •  ${_movementLabel(movement.type)}'),
              ));
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
        _ => 'حركة',
      };
}
