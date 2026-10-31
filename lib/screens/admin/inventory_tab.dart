import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/business_features.dart';
import '../../providers/business_tools_provider.dart';
import '../../widgets/confirm_dialogs.dart';
import '../../providers/shop_provider.dart';

const _categories = [
  ('general', 'عام'),
  ('shampoo', 'شامبو وبلسم'),
  ('dye', 'صبغات وكيماويات'),
  ('styling', 'جل وسبراي'),
  ('shaving', 'حلاقة'),
  ('blades', 'شفرات ومواد استهلاكية'),
  ('hygiene', 'نظافة وتعقيم'),
  ('retail', 'منتجات للبيع'),
];

const _units = [
  ('piece', 'قطعة'),
  ('bottle', 'زجاجة'),
  ('box', 'علبة'),
  ('pack', 'عبوة'),
  ('ml', 'مل'),
  ('liter', 'لتر'),
  ('g', 'غرام'),
  ('kg', 'كغ'),
];

class InventoryTab extends StatelessWidget {
  const InventoryTab({super.key});

  Future<void> _showItemDialog(BuildContext context, {InventoryItem? item}) async {
    final name = TextEditingController(text: item?.name ?? '');
    final supplier = TextEditingController(text: item?.supplier ?? '');
    final quantity = TextEditingController(
        text: item == null ? '0' : item.quantity.toString());
    final cost = TextEditingController(
        text: item == null ? '0' : item.unitCost.toString());
    final consumeCtrl = TextEditingController(
      text: (item?.consumePerUse ?? 0) == 0
          ? '0'
          : item!.consumePerUse.toString(),
    );
    var linked = List<String>.from(item?.linkedServiceIds ?? const []);
    final reorder = TextEditingController(
        text: item == null ? '0' : item.reorderLevel.toString());
    var category = item?.category ?? 'general';
    if (!_categories.any((c) => c.$1 == category)) category = 'general';
    var unit = item?.unit ?? 'piece';
    if (!_units.any((u) => u.$1 == unit)) unit = 'piece';
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setLocal) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item == null ? 'مادة جديدة' : 'تعديل المادة',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'اسم المادة',
                          prefixIcon: Icon(Icons.label_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'التصنيف',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: [
                          for (final c in _categories)
                            DropdownMenuItem(
                              value: c.$1,
                              child: Text(
                                c.$2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) =>
                            setLocal(() => category = v ?? 'general'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: unit,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'الوحدة',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                              ),
                              items: [
                                for (final u in _units)
                                  DropdownMenuItem(
                                    value: u.$1,
                                    child: Text(
                                      u.$2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setLocal(() => unit = v ?? 'piece'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: quantity,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]')),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'الكمية الحالية',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: cost,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]')),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'تكلفة الوحدة',
                                helperText: 'آخر شراء',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: reorder,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]')),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'حد إعادة الطلب',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: consumeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'استهلاك لكل خدمة (اختياري)',
                          helperText: 'يُخصم تلقائياً عند تحصيل خدمة مرتبطة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(builder: (ctx) {
                        final services = ctx
                            .watch<ShopProvider>()
                            .services
                            .where((s) => s.active)
                            .toList();
                        if (services.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ربط بخدمات (للاستهلاك التلقائي)',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final s in services)
                                  FilterChip(
                                    label: Text(s.name),
                                    selected: linked.contains(s.id),
                                    onSelected: (v) => setLocal(() {
                                      if (v) {
                                        linked = [...linked, s.id];
                                      } else {
                                        linked = linked
                                            .where((x) => x != s.id)
                                            .toList();
                                      }
                                    }),
                                  ),
                              ],
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 12),
                      TextField(
                        controller: supplier,
                        decoration: const InputDecoration(
                          labelText: 'المورد (اختياري)',
                          prefixIcon: Icon(Icons.local_shipping_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            Navigator.pop(ctx, true);
                          }
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('حفظ'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    final nameValue = name.text.trim();
    final supplierValue = supplier.text.trim();
    final quantityValue =
        double.tryParse(quantity.text.replaceAll(',', '.')) ?? 0;
    final costValue = double.tryParse(cost.text.replaceAll(',', '.')) ?? 0;
    final reorderValue =
        double.tryParse(reorder.text.replaceAll(',', '.')) ?? 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      supplier.dispose();
      quantity.dispose();
      cost.dispose();
      reorder.dispose();
      consumeCtrl.dispose();
    });

    if (saved != true || !context.mounted || nameValue.isEmpty) return;

    final tools = context.read<BusinessToolsProvider>();
    final now = DateTime.now();
    final consumeValue =
        double.tryParse(consumeCtrl.text.replaceAll(',', '.')) ?? 0;
    await tools.saveInventoryItem(InventoryItem(
      id: item?.id ?? const Uuid().v4(),
      name: nameValue,
      sku: item?.sku ?? '',
      category: category,
      unit: unit,
      quantity: quantityValue,
      unitCost: costValue,
      reorderLevel: reorderValue,
      supplier: supplierValue,
      createdAt: item?.createdAt ?? now,
      updatedAt: now,
      active: item?.active ?? true,
      consumePerUse: consumeValue,
      linkedServiceIds: linked,
    ));
  }

  Future<void> _showMovementDialog(
      BuildContext context, InventoryItem item, String type) async {
    final quantity = TextEditingController();
    final unitCost = TextEditingController(text: item.unitCost.toString());
    final reason = TextEditingController();
    final labels = {
      'purchase': 'شراء وإضافة للمخزون',
      'usage': 'صرف يدوي',
      'waste': 'هدر أو تلف',
      'adjustment': 'جرد وتصحيح الرصيد',
    };
    final unitLabel =
        _units.where((u) => u.$1 == item.unit).map((u) => u.$2).firstOrNull ??
            item.unit;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                labels[type] ?? 'حركة مخزون',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${item.name} · الرصيد: ${item.quantity.toStringAsFixed(2)} $unitLabel',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantity,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: type == 'adjustment'
                      ? 'الرصيد الفعلي بعد الجرد'
                      : 'الكمية ($unitLabel)',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (type == 'purchase') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: unitCost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'تكلفة الوحدة (تحدّث آخر شراء)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: type == 'purchase'
                      ? 'ملاحظة (اختياري)'
                      : 'السبب (مطلوب)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('تسجيل'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        );
      },
    );

    final quantityValue =
        double.tryParse(quantity.text.replaceAll(',', '.')) ?? 0;
    final costValue =
        double.tryParse(unitCost.text.replaceAll(',', '.')) ?? item.unitCost;
    final reasonValue = reason.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      quantity.dispose();
      unitCost.dispose();
      reason.dispose();
    });
    if (saved != true || !context.mounted || quantityValue < 0) return;
    if (type != 'purchase' && reasonValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السبب مطلوب لصرف / هدر / جرد')),
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
            content:
                Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }

  String _catLabel(String code) =>
      _categories.where((c) => c.$1 == code).map((c) => c.$2).firstOrNull ??
      code;

  String _unitLabel(String code) =>
      _units.where((u) => u.$1 == code).map((u) => u.$2).firstOrNull ?? code;

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final currency =
        context.watch<ShopProvider>().settings?.currency ?? 'SAR';
    final items = tools.inventory;
    final active = items.where((i) => i.active).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزون'),
        actions: [
          IconButton(
            tooltip: 'إضافة مادة',
            onPressed: () => _showItemDialog(context),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inventory_main_fab',
        onPressed: () => _showItemDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('مادة'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _SummaryCard(items: active, currency: currency),
          const SizedBox(height: 16),
          Text(
            'المواد',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'لا مواد بعد',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'أضف شامبو، صبغة، شفرات… ثم سجّل الشراء والصرف',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            ...items.map((item) {
              final unitL = _unitLabel(item.unit);
              Color? badgeColor;
              String? badgeText;
              if (!item.active) {
                badgeText = 'معطّل';
                badgeColor = Colors.grey;
              } else if (item.outOfStock) {
                badgeText = 'نافد';
                badgeColor = Colors.red;
              } else if (item.lowStock) {
                badgeText = 'تحت الحد';
                badgeColor = Colors.orange;
              }
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: (badgeColor ??
                            Theme.of(context).colorScheme.primary)
                        .withOpacity(0.12),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: badgeColor ??
                          Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity.toStringAsFixed(2)} $unitL'
                          '  ·  ${_catLabel(item.category)}'
                          '  ·  ${item.stockValue.toStringAsFixed(0)} $currency',
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor!.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  isThreeLine: badgeText != null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _showItemDialog(context, item: item);
                      } else if (value == 'delete') {
                        final ok = await confirmDelete(
                          context,
                          title: 'حذف المادة؟',
                          message: 'سيتم حذف «${item.name}» من المخزون.',
                        );
                        if (ok && context.mounted) {
                          await context
                              .read<BusinessToolsProvider>()
                              .deleteInventoryItem(item.id);
                        }
                      } else {
                        await _showMovementDialog(context, item, value);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'purchase', child: Text('شراء')),
                      PopupMenuItem(value: 'usage', child: Text('صرف')),
                      PopupMenuItem(value: 'waste', child: Text('هدر')),
                      PopupMenuItem(value: 'adjustment', child: Text('جرد')),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'edit', child: Text('تعديل')),
                      PopupMenuItem(
                          value: 'delete', child: Text('حذف / تعطيل')),
                    ],
                  ),
                ),
              );
            }),
          if (tools.inventoryMovements.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'آخر الحركات',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...tools.inventoryMovements.take(25).map((m) {
              final item =
                  items.where((x) => x.id == m.itemId).firstOrNull;
              final sign = m.type == 'purchase'
                  ? '+'
                  : m.type == 'adjustment'
                      ? '↔'
                      : '−';
              return Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    m.type == 'purchase'
                        ? Icons.add_circle_outline
                        : Icons.remove_circle_outline,
                    color: m.type == 'purchase'
                        ? Colors.green
                        : Colors.orange.shade800,
                  ),
                  title: Text(
                      '${item?.name ?? 'مادة'}  $sign${m.quantity.toStringAsFixed(2)}'),
                  subtitle: Text(
                    '${m.reason.isEmpty ? _moveLabel(m.type) : m.reason}'
                    '${m.balanceAfter != null ? '  → ${m.balanceAfter!.toStringAsFixed(2)}' : ''}',
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _moveLabel(String type) => switch (type) {
        'purchase' => 'شراء',
        'usage' => 'صرف',
        'waste' => 'هدر',
        'adjustment' => 'جرد',
        _ => 'حركة',
      };
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.items, required this.currency});
  final List<InventoryItem> items;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final value = items.fold<double>(0, (s, i) => s + i.stockValue);
    final low = items.where((i) => i.lowStock).length;
    final out = items.where((i) => i.outOfStock).length;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withOpacity(0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'ملخص المخزون',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'التقييم: تكلفة آخر شراء',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _metric('أصناف', '${items.length}', scheme.primary)),
                Expanded(
                    child: _metric(
                        'القيمة',
                        '${value.toStringAsFixed(0)} $currency',
                        Colors.teal.shade700)),
                Expanded(
                    child: _metric('تحت الحد', '$low', Colors.orange.shade800)),
                Expanded(
                    child: _metric('نافد', '$out', Colors.red.shade700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15, color: color)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }
}
