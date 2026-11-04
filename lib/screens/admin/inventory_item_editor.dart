import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/business_features.dart';
import '../../models/inventory_catalog.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/inventory_analytics.dart';
import '../../widgets/controller_scope.dart';

/// محرّر مادة مخزون كامل الحقول.
///
/// يعيد المادة جاهزة للحفظ (بلا كتابة Firestore) حتى يتولى المستدعي اختيار
/// مسار الإنشاء مع رصيد افتتاحي أو التحديث العادي.
Future<InventoryItem?> showInventoryItemEditor(
  BuildContext context, {
  InventoryItem? item,
}) async {
  final isNew = item == null;
  final name = TextEditingController(text: item?.name ?? '');
  final sku = TextEditingController(text: item?.sku ?? '');
  final barcode = TextEditingController(text: item?.barcode ?? '');
  final brand = TextEditingController(text: item?.brand ?? '');
  final supplier = TextEditingController(text: item?.supplier ?? '');
  final location = TextEditingController(text: item?.location ?? '');
  final description = TextEditingController(text: item?.description ?? '');
  final quantity = TextEditingController(
    text: isNew ? '0' : _formatQty(item.quantity),
  );
  final cost = TextEditingController(
    text: isNew ? '0' : _formatQty(item.unitCost),
  );
  final reorderLevel = TextEditingController(
    text: isNew ? '0' : _formatQty(item.reorderLevel),
  );
  final reorderQty = TextEditingController(
    text: isNew ? '0' : _formatQty(item.reorderQty),
  );
  final maxStock = TextEditingController(
    text: isNew ? '0' : _formatQty(item.maxStock),
  );
  final consumeCtrl = TextEditingController(
    text: isNew ? '0' : _formatQty(item.consumePerUse),
  );

  var category = item?.category ?? 'general';
  if (!inventoryCategories.any((c) => c.$1 == category)) category = 'general';
  var unit = item?.unit ?? 'piece';
  if (!inventoryUnits.any((u) => u.$1 == unit)) unit = 'piece';
  var linked = List<String>.from(item?.linkedServiceIds ?? const []);
  var expiresAt = item?.expiresAt;
  var active = item?.active ?? true;
  String? duplicateError;
  final formKey = GlobalKey<FormState>();

  final result = await showModalBottomSheet<InventoryItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return ControllerScope(
        controllers: [
          name,
          sku,
          barcode,
          brand,
          supplier,
          location,
          description,
          quantity,
          cost,
          reorderLevel,
          reorderQty,
          maxStock,
          consumeCtrl,
        ],
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: StatefulBuilder(
              builder: (context, setLocal) {
                final services = context
                    .watch<ShopProvider>()
                    .services
                    .where((s) => s.active)
                    .toList();
                final unitLabel = inventoryUnitLabel(unit);
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isNew ? 'مادة جديدة' : 'تعديل المادة',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _sectionTitle('بيانات أساسية'),
                      TextFormField(
                        controller: name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'اسم المادة',
                          prefixIcon: Icon(Icons.label_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'الاسم مطلوب'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: sku,
                              decoration: const InputDecoration(
                                labelText: 'رمز SKU',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: barcode,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'الباركود',
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
                              controller: brand,
                              decoration: const InputDecoration(
                                labelText: 'الماركة',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: category,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'التصنيف',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                              ),
                              items: [
                                for (final c in inventoryCategories)
                                  DropdownMenuItem(
                                    value: c.$1,
                                    child: Text(c.$2,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setLocal(() => category = v ?? 'general'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _sectionTitle('المخزون والتكلفة'),
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
                                for (final u in inventoryUnits)
                                  DropdownMenuItem(
                                    value: u.$1,
                                    child: Text(u.$2,
                                        overflow: TextOverflow.ellipsis),
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
                              readOnly: !isNew,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]')),
                              ],
                              decoration: InputDecoration(
                                labelText: isNew
                                    ? 'الرصيد الافتتاحي'
                                    : 'الرصيد الحالي',
                                helperText: isNew
                                    ? 'يُسجَّل كحركة شراء افتتاحية'
                                    : 'يتغيّر بالحركات فقط',
                                helperMaxLines: 2,
                                border: const OutlineInputBorder(),
                                suffixText: unitLabel,
                              ),
                              validator: _numberValidator(
                                  allowZero: true, required: isNew),
                              onChanged: (_) => setLocal(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: cost,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'تكلفة الوحدة',
                          helperText: 'تكلفة آخر شراء — تُستخدم لتقييم المخزون',
                          border: const OutlineInputBorder(),
                          suffixText: '/ $unitLabel',
                        ),
                        validator: _numberValidator(allowZero: true),
                        onChanged: (_) => setLocal(() {}),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 0,
                        color: Colors.grey.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              const Icon(Icons.calculate_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'قيمة الرصيد: '
                                  '${((double.tryParse(quantity.text.replaceAll(',', '.')) ?? 0) * (double.tryParse(cost.text.replaceAll(',', '.')) ?? 0)).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _sectionTitle('حدود إعادة الطلب'),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: reorderLevel,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]')),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'حد إعادة الطلب',
                                border: OutlineInputBorder(),
                              ),
                              validator: _numberValidator(allowZero: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: reorderQty,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]')),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'كمية إعادة الطلب',
                                border: OutlineInputBorder(),
                              ),
                              validator: _numberValidator(allowZero: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: maxStock,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'الحد الأقصى للتخزين (اختياري)',
                          helperText: 'يُحسب اقتراح الشراء حتى هذا الحد',
                          border: OutlineInputBorder(),
                        ),
                        validator: _numberValidator(allowZero: true),
                      ),
                      const SizedBox(height: 18),
                      _sectionTitle('بيانات إضافية'),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: supplier,
                              decoration: const InputDecoration(
                                labelText: 'المورد',
                                prefixIcon: Icon(Icons.local_shipping_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: location,
                        decoration: const InputDecoration(
                          labelText: 'موقع التخزين',
                          prefixIcon: Icon(Icons.shelves),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: expiresAt ?? now,
                            firstDate: DateTime(now.year - 5),
                            lastDate: DateTime(now.year + 10),
                          );
                          if (picked != null) {
                            setLocal(() => expiresAt = picked);
                          }
                        },
                        icon: const Icon(Icons.event_busy_outlined),
                        label: Text(
                          expiresAt == null
                              ? 'تاريخ انتهاء الصلاحية (اختياري)'
                              : 'تنتهي في ${DateFormat('yyyy/MM/dd').format(expiresAt!)}',
                        ),
                      ),
                      if (expiresAt != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () => setLocal(() => expiresAt = null),
                            child: const Text('مسح التاريخ'),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: description,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _sectionTitle('الاستهلاك التلقائي'),
                      TextFormField(
                        controller: consumeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'يُخصم لكل خدمة',
                          helperText:
                              'اختياري — يُخصم تلقائياً عند تحصيل خدمة مرتبطة',
                          helperMaxLines: 2,
                          suffixText: unitLabel,
                          border: const OutlineInputBorder(),
                        ),
                        validator: _numberValidator(allowZero: true),
                      ),
                      if (services.isNotEmpty) ...[
                        const SizedBox(height: 10),
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
                                    linked =
                                        linked.where((x) => x != s.id).toList();
                                  }
                                }),
                              ),
                          ],
                        ),
                      ],
                      if (!isNew) ...[
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: active,
                          onChanged: (v) => setLocal(() => active = v),
                          title: const Text('مادة نشطة'),
                          subtitle: const Text(
                              'المعطّلة لا تظهر في الجرد وقد لا تُستهلك تلقائياً'),
                        ),
                      ],
                      if (duplicateError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          duplicateError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final now = DateTime.now();
                          final draft = InventoryItem(
                            id: item?.id ?? const Uuid().v4(),
                            name: name.text.trim(),
                            sku: sku.text.trim(),
                            barcode: barcode.text.trim(),
                            category: category,
                            brand: brand.text.trim(),
                            description: description.text.trim(),
                            unit: unit,
                            quantity:
                                isNew ? _parse(quantity.text) : item.quantity,
                            unitCost: _parse(cost.text),
                            reorderLevel: _parse(reorderLevel.text),
                            reorderQty: _parse(reorderQty.text),
                            maxStock: _parse(maxStock.text),
                            supplier: supplier.text.trim(),
                            location: location.text.trim(),
                            expiresAt: expiresAt,
                            active: active,
                            createdAt: item?.createdAt ?? now,
                            updatedAt: now,
                            consumePerUse: _parse(consumeCtrl.text),
                            linkedServiceIds: linked,
                          );
                          final duplicate =
                              InventoryAnalytics.duplicateItemError(
                            context.read<BusinessToolsProvider>().inventory,
                            draft,
                          );
                          if (duplicate != null) {
                            setLocal(() => duplicateError = duplicate);
                            return;
                          }
                          Navigator.pop(ctx, draft);
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('حفظ'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );

  return result;
}

Widget _sectionTitle(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );

String? Function(String?) _numberValidator({
  bool allowZero = false,
  bool required = false,
}) {
  return (value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      if (required) return 'مطلوب';
      return null;
    }
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    if (parsed == null) return 'أدخل رقماً صحيحاً';
    if (parsed < 0) return 'لا يمكن أن يكون سالباً';
    if (!allowZero && parsed == 0) return 'يجب أن يكون أكبر من صفر';
    return null;
  };
}

double _parse(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.')) ?? 0;

String _formatQty(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
