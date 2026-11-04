import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/business_features.dart';
import '../../models/inventory_catalog.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import '../../widgets/confirm_dialogs.dart';
import '../../widgets/empty_state.dart';
import 'inventory_item_editor.dart';
import 'inventory_movement_sheet.dart';

/// بطاقة مادة مخزون: رصيدها، بياناتها، تدقيقها، وسجل حركاتها الكامل.
class InventoryItemScreen extends StatelessWidget {
  const InventoryItemScreen({super.key, required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final shop = context.watch<ShopProvider>();
    final currency = shop.settings?.currency ?? 'SAR';
    final current =
        tools.inventory.where((i) => i.id == item.id).firstOrNull ?? item;
    final unit = inventoryUnitLabel(current.unit);
    final movements =
        tools.inventoryMovements.where((m) => m.itemId == current.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(current.name),
        actions: [
          IconButton(
            tooltip: 'تعديل المادة',
            onPressed: () => _edit(context, current),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _delete(context, current);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Text('حذف / تعطيل'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          _Header(item: current, currency: currency, unit: unit),
          const SizedBox(height: 12),
          _Metrics(item: current, currency: currency, unit: unit),
          if (current.isExpired && current.quantity > 0) ...[
            const SizedBox(height: 12),
            _AlertCard(
              icon: Icons.warning_amber_rounded,
              color: Colors.red.shade700,
              title: 'مادة منتهية الصلاحية',
              message:
                  'انتهت في ${DateFormat('yyyy/MM/dd').format(current.expiresAt!)} '
                  'وما زال لها رصيد. سجّل إتلافاً لإخراجها من التقييم.',
              actionLabel: 'تسجيل إتلاف',
              onAction: () => showInventoryMovementSheet(
                context,
                item: current,
                type: 'expiry',
                initialQuantity: current.quantity,
              ),
            ),
          ] else if (current.expiringSoon && current.quantity > 0) ...[
            const SizedBox(height: 12),
            _AlertCard(
              icon: Icons.schedule_rounded,
              color: Colors.orange.shade800,
              title: 'قريبة من الانتهاء',
              message:
                  'تنتهي في ${DateFormat('yyyy/MM/dd').format(current.expiresAt!)}.',
            ),
          ],
          if (current.lowStock || current.outOfStock) ...[
            const SizedBox(height: 12),
            _AlertCard(
              icon: Icons.shopping_cart_outlined,
              color: Colors.deepOrange.shade700,
              title: current.outOfStock ? 'المادة نافدة' : 'تحت حد إعادة الطلب',
              message: 'اقتراح الشراء: '
                  '${_formatQty(current.suggestedReorder)} $unit',
              actionLabel: 'تسجيل شراء',
              onAction: () => showInventoryMovementSheet(
                context,
                item: current,
                type: 'purchase',
                initialQuantity: current.suggestedReorder,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Details(item: current, currency: currency, unit: unit),
          const SizedBox(height: 12),
          _Actions(item: current),
          if (_hasBalanceDrift(current, movements)) ...[
            const SizedBox(height: 12),
            _AlertCard(
              icon: Icons.rule_rounded,
              color: Colors.blueGrey,
              title: 'تدقيق الرصيد',
              message:
                  'الرصيد الحالي (${_formatQty(current.quantity)} $unit) لا يطابق '
                  'آخر حركة مسجّلة. إن كان ذلك مقصوداً فسجّل جرداً لتوثيق الفرق.',
            ),
          ],
          const SizedBox(height: 16),
          _MovementHistory(
            item: current,
            movements: movements,
            unit: unit,
            currency: currency,
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, InventoryItem current) async {
    final updated = await showInventoryItemEditor(context, item: current);
    if (updated == null || !context.mounted) return;
    try {
      await context.read<BusinessToolsProvider>().saveInventoryItem(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث المادة')),
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

  Future<void> _delete(BuildContext context, InventoryItem current) async {
    final ok = await confirmDelete(
      context,
      title: 'حذف / تعطيل المادة؟',
      message: current.quantity > 0 || _hasHistory(context, current)
          ? 'المادة لها رصيد أو حركات، لذا ستُعطَّل بدل حذفها للحفاظ على السجل.'
          : 'سيتم حذف «${current.name}» من المخزون.',
    );
    if (!ok || !context.mounted) return;
    final tools = context.read<BusinessToolsProvider>();
    final navigator = Navigator.of(context);
    try {
      await tools.deleteInventoryItem(current.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف / تعطيل المادة')),
        );
        navigator.pop();
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

  bool _hasHistory(BuildContext context, InventoryItem current) => context
      .read<BusinessToolsProvider>()
      .inventoryMovements
      .any((m) => m.itemId == current.id);

  bool _hasBalanceDrift(InventoryItem item, List<InventoryMovement> movements) {
    if (movements.isEmpty) return false;
    final latest = movements.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
    final after = latest.balanceAfter;
    if (after == null) return false;
    return (after - item.quantity).abs() > kStockEpsilon;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.item,
    required this.currency,
    required this.unit,
  });

  final InventoryItem item;
  final String currency;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _status(item);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: status.$2.withOpacity(0.12),
              child: Icon(
                Icons.inventory_2_outlined,
                color: status.$2,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${inventoryCategoryLabel(item.category)}'
                    '${item.brand.trim().isEmpty ? '' : ' · ${item.brand}'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_formatQty(item.quantity)} $unit'
                    '  ·  ${item.stockValue.toStringAsFixed(2)} $currency',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status.$2.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.$1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: status.$2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({
    required this.item,
    required this.currency,
    required this.unit,
  });

  final InventoryItem item;
  final String currency;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _metric('التكلفة', '${_formatQty(item.unitCost)} / $unit'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metric('حد الطلب', '${_formatQty(item.reorderLevel)} $unit'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metric(
            'القيمة',
            '${item.stockValue.toStringAsFixed(0)} $currency',
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.item,
    required this.currency,
    required this.unit,
  });

  final InventoryItem item;
  final String currency;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final services = context.watch<ShopProvider>();
    final linkedNames = item.linkedServiceIds
        .map((id) => services.serviceById(id)?.name ?? id)
        .where((name) => name.trim().isNotEmpty)
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.info_outline,
              title: 'بيانات المادة',
            ),
            const SizedBox(height: 8),
            if (item.sku.trim().isNotEmpty) _row('رمز SKU', item.sku),
            if (item.barcode.trim().isNotEmpty) _row('الباركود', item.barcode),
            if (item.supplier.trim().isNotEmpty) _row('المورد', item.supplier),
            if (item.location.trim().isNotEmpty)
              _row('موقع التخزين', item.location),
            if (item.maxStock > 0)
              _row('الحد الأقصى', '${_formatQty(item.maxStock)} $unit'),
            if (item.reorderQty > 0)
              _row('كمية إعادة الطلب', '${_formatQty(item.reorderQty)} $unit'),
            if (item.expiresAt != null)
              _row(
                'انتهاء الصلاحية',
                DateFormat('yyyy/MM/dd').format(item.expiresAt!),
              ),
            if (item.consumePerUse > 0)
              _row('الاستهلاك لكل خدمة',
                  '${_formatQty(item.consumePerUse)} $unit'),
            if (linkedNames.isNotEmpty)
              _row('خدمات مرتبطة', linkedNames.join(' · ')),
            if (item.description.trim().isNotEmpty)
              _row('ملاحظات', item.description),
            _row('تاريخ الإضافة',
                DateFormat('yyyy/MM/dd').format(item.createdAt.toLocal())),
            _row(
                'آخر تحديث',
                DateFormat('yyyy/MM/dd HH:mm')
                    .format(item.updatedAt.toLocal())),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _Actions extends StatelessWidget {
  const _Actions({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final actions = <(String, String, IconData)>[
      ('purchase', 'شراء', Icons.add_shopping_cart),
      ('usage', 'صرف', Icons.remove_circle_outline),
      ('waste', 'هدر', Icons.delete_outline),
      ('damage', 'تلف', Icons.broken_image_outlined),
      ('adjustment', 'جرد', Icons.fact_check_outlined),
      ('expiry', 'إتلاف منتهي', Icons.event_busy_outlined),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.flash_on_outlined,
              title: 'حركة سريعة',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in actions)
                  ActionChip(
                    avatar: Icon(action.$3, size: 17),
                    label: Text(action.$2),
                    onPressed: () => showInventoryMovementSheet(
                      context,
                      item: item,
                      type: action.$1,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementHistory extends StatelessWidget {
  const _MovementHistory({
    required this.item,
    required this.movements,
    required this.unit,
    required this.currency,
  });

  final InventoryItem item;
  final List<InventoryMovement> movements;
  final String unit;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final sorted = [...movements]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.history_rounded,
              title: 'سجل الحركات (${sorted.length})',
            ),
            const SizedBox(height: 10),
            if (sorted.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'لا حركات بعد',
                subtitle: 'ستظهر هنا كل عمليات الشراء والصرف والجرد.',
              )
            else
              for (final movement in sorted.take(100))
                _MovementTile(
                  movement: movement,
                  unit: unit,
                  currency: currency,
                ),
            if (sorted.length > 100)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'تُعرض آخر 100 حركة من أصل ${sorted.length}.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({
    required this.movement,
    required this.unit,
    required this.currency,
  });

  final InventoryMovement movement;
  final String unit;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final isIn = movement.signedDelta > 0;
    final color = movement.type == 'adjustment'
        ? Colors.blueGrey
        : isIn
            ? Colors.green.shade700
            : Colors.orange.shade800;
    final sign = movement.type == 'adjustment'
        ? '↔'
        : isIn
            ? '+'
            : '−';
    final value = movement.quantity * movement.unitCost;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            movement.type == 'purchase'
                ? Icons.add_circle_outline
                : movement.type == 'adjustment'
                    ? Icons.swap_vert_rounded
                    : Icons.remove_circle_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        inventoryMovementLabel(movement.type),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '$sign${_formatQty(movement.quantity)} $unit',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('yyyy/MM/dd HH:mm')
                      .format(movement.createdAt.toLocal()),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (movement.reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    movement.reason,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ],
                if (movement.balanceAfter != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'الرصيد بعدها: ${_formatQty(movement.balanceAfter!)} $unit'
                    '${value > 0 ? '  ·  ${value.toStringAsFixed(2)} $currency' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

(String, Color) _status(InventoryItem item) {
  if (!item.active) return ('معطّل', Colors.grey);
  if (item.quantity <= 0) return ('نافد', Colors.red.shade700);
  if (item.isExpired) return ('منتهي الصلاحية', Colors.red.shade700);
  if (item.lowStock) return ('تحت الحد', Colors.orange.shade800);
  if (item.expiringSoon) return ('قريب الانتهاء', Colors.orange.shade700);
  return ('متوفر', Colors.green.shade700);
}

String _formatQty(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
