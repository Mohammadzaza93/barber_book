import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/business_features.dart';
import '../../models/inventory_catalog.dart';
import '../../providers/business_tools_provider.dart';
import '../../widgets/controller_scope.dart';

/// نافذة تسجيل حركة مخزون (شراء / صرف / هدر / تلف / انتهاء / جرد).
///
/// تُستخدم من قائمة المخزون، صفحة المادة، وتقارير إعادة الطلب. تُرجع `true`
/// عند نجاح الحفظ. تتحقق من الكمية والسبب قبل الكتابة، وتُظهر خطأ Firestore
/// بدل تركه استثناءً غير معالج.
Future<bool> showInventoryMovementSheet(
  BuildContext context, {
  required InventoryItem item,
  required String type,
  double? initialQuantity,
}) async {
  final quantity = TextEditingController(
    text: initialQuantity == null ? '' : _formatQty(initialQuantity),
  );
  final unitCost = TextEditingController(text: _formatQty(item.unitCost));
  final reason = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final unitLabel = inventoryUnitLabel(item.unit);
  final isPurchase = type == 'purchase';
  final isAdjustment = type == 'adjustment';

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return ControllerScope(
        controllers: [quantity, unitCost, reason],
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
                final qty =
                    double.tryParse(quantity.text.replaceAll(',', '.')) ?? 0;
                final cost =
                    double.tryParse(unitCost.text.replaceAll(',', '.')) ?? 0;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        inventoryMovementLabel(type),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.name} · الرصيد: '
                        '${_formatQty(item.quantity)} $unitLabel',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: quantity,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: InputDecoration(
                          labelText: isAdjustment
                              ? 'الرصيد الفعلي بعد الجرد'
                              : 'الكمية ($unitLabel)',
                          border: const OutlineInputBorder(),
                          helperText: isAdjustment
                              ? 'سيُسجَّل الفرق كحركة جرد، لا يُستبدل الرصيد بصمت'
                              : null,
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(
                              (value ?? '').replaceAll(',', '.'));
                          if (parsed == null) return 'أدخل رقماً صحيحاً';
                          if (parsed < 0) return 'لا يمكن أن تكون سالبة';
                          if (!isAdjustment && parsed == 0) {
                            return 'الكمية يجب أن تكون أكبر من صفر';
                          }
                          if ((type == 'usage' ||
                                  type == 'waste' ||
                                  type == 'damage' ||
                                  type == 'expiry') &&
                              parsed > item.quantity + kStockEpsilon) {
                            return 'الرصيد غير كافٍ';
                          }
                          return null;
                        },
                        onChanged: (_) => setLocal(() {}),
                      ),
                      if (isPurchase) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: unitCost,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'تكلفة الوحدة',
                            helperText: 'تحدّث تكلفة آخر شراء',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setLocal(() {}),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'إجمالي الشراء: ${(qty * cost).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: reason,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText:
                              isPurchase ? 'ملاحظة (اختياري)' : 'السبب (مطلوب)',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (isPurchase) return null;
                          return (value ?? '').trim().isEmpty
                              ? 'السبب مطلوب'
                              : null;
                        },
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            Navigator.pop(ctx, true);
                          }
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('تسجيل الحركة'),
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
                );
              },
            ),
          ),
        ),
      );
    },
  );

  final quantityValue =
      double.tryParse(quantity.text.replaceAll(',', '.')) ?? 0;
  final costValue =
      double.tryParse(unitCost.text.replaceAll(',', '.')) ?? item.unitCost;
  final reasonValue = reason.text.trim();

  if (saved != true || !context.mounted) return false;

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
        SnackBar(
          content: Text(
            type == 'adjustment'
                ? 'تم تسجيل الجرد وتصحيح الرصيد'
                : 'تم تسجيل حركة ${inventoryMovementLabel(type)}',
          ),
        ),
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
    return false;
  }
}

String _formatQty(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
