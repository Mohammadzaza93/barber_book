import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/business_features.dart';
import '../../models/inventory_catalog.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/inventory_analytics.dart';
import '../../widgets/confirm_dialogs.dart';
import 'inventory_item_editor.dart';
import 'inventory_item_screen.dart';
import 'inventory_movement_sheet.dart';
import 'inventory_reports_screen.dart';
import 'stocktake_screen.dart';

enum _StockFilter { all, low, out, expiring, inactive }

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final _search = TextEditingController();
  _StockFilter _filter = _StockFilter.all;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor({InventoryItem? item}) async {
    final draft = await showInventoryItemEditor(context, item: item);
    if (draft == null || !mounted) return;
    final tools = context.read<BusinessToolsProvider>();
    try {
      if (item == null) {
        await tools.createInventoryItem(draft, openingQty: draft.quantity);
      } else {
        await tools.saveInventoryItem(draft);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(item == null ? 'تمت إضافة المادة' : 'تم تحديث المادة'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _delete(InventoryItem item) async {
    final tools = context.read<BusinessToolsProvider>();
    final hasMoves = tools.inventoryMovements.any((m) => m.itemId == item.id);
    final ok = await confirmDelete(
      context,
      title: 'حذف / تعطيل المادة؟',
      message: hasMoves || item.quantity > 0
          ? 'المادة لها رصيد أو حركات، لذا ستُعطَّل بدل حذفها للحفاظ على السجل.'
          : 'سيتم حذف «${item.name}» من المخزون.',
    );
    if (!ok || !mounted) return;
    try {
      await tools.deleteInventoryItem(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف / تعطيل المادة')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  List<InventoryItem> _filtered(List<InventoryItem> items) {
    final query = _query.trim().toLowerCase();
    return items.where((item) {
      final matchesQuery = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.sku.toLowerCase().contains(query) ||
          item.barcode.contains(query) ||
          item.brand.toLowerCase().contains(query) ||
          item.supplier.toLowerCase().contains(query);
      if (!matchesQuery) return false;
      return switch (_filter) {
        _StockFilter.all => true,
        _StockFilter.low => item.lowStock,
        _StockFilter.out => item.outOfStock,
        _StockFilter.expiring => item.isExpired || item.expiringSoon,
        _StockFilter.inactive => !item.active,
      };
    }).toList()
      ..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        return a.name.compareTo(b.name);
      });
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final currency = context.watch<ShopProvider>().settings?.currency ?? 'SAR';
    final items = tools.inventory;
    final health = InventoryAnalytics.health(items);
    final restock = InventoryAnalytics.restockSuggestions(items);
    final shown = _filtered(items);
    final names = {for (final item in items) item.id: item.name};
    final recent = tools.inventoryMovements.take(8).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزون'),
        actions: [
          IconButton(
            tooltip: 'تقارير المخزون',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InventoryReportsScreen()),
            ),
            icon: const Icon(Icons.insights_outlined),
          ),
          IconButton(
            tooltip: 'الجرد',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StocktakeScreen()),
            ),
            icon: const Icon(Icons.fact_check_outlined),
          ),
          IconButton(
            tooltip: 'إضافة مادة',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inventory_main_fab',
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('مادة'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _SummaryCard(health: health, currency: currency),
          if (restock.isNotEmpty) ...[
            const SizedBox(height: 10),
            _RestockBanner(
              count: restock.length,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InventoryReportsScreen(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو SKU أو الباركود أو المورد',
              prefixIcon: const Icon(Icons.search_rounded),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _filterChip(
                  _StockFilter.all, 'الكل', items.length, Colors.blueGrey),
              _filterChip(_StockFilter.low, 'تحت الحد', health.lowStock,
                  Colors.orange.shade800),
              _filterChip(_StockFilter.out, 'نافد', health.outOfStock,
                  Colors.red.shade700),
              _filterChip(
                _StockFilter.expiring,
                'الصلاحية',
                health.expiringSoon + health.expired,
                Colors.deepOrange.shade700,
              ),
              _filterChip(_StockFilter.inactive, 'معطّل', health.inactive,
                  Colors.grey.shade700),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'المواد (${shown.length})',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            _EmptyInventory(onAdd: _openEditor)
          else if (shown.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 44, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    const Text(
                      'لا نتائج مطابقة',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'جرّب بحثاً آخر أو أزل الفلاتر.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            ...shown.map(
              (item) => _InventoryTile(
                item: item,
                currency: currency,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InventoryItemScreen(item: item),
                  ),
                ),
                onEdit: () => _openEditor(item: item),
                onDelete: () => _delete(item),
                onMovement: (type) => showInventoryMovementSheet(
                  context,
                  item: item,
                  type: type,
                ),
              ),
            ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'آخر الحركات',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InventoryReportsScreen(),
                    ),
                  ),
                  child: const Text('التقارير'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...recent.map(
              (movement) => _RecentMovement(
                movement: movement,
                itemName: names[movement.itemId] ?? 'مادة',
                currency: currency,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(
    _StockFilter filter,
    String label,
    int count,
    Color color,
  ) {
    final selected = _filter == filter;
    return ChoiceChip(
      label: Text(count > 0 ? '$label ($count)' : label),
      selected: selected,
      selectedColor: color.withOpacity(0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? color : null,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
      ),
      onSelected: (_) => setState(() => _filter = filter),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({
    required this.item,
    required this.currency,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onMovement,
  });

  final InventoryItem item;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String type) onMovement;

  @override
  Widget build(BuildContext context) {
    final unit = inventoryUnitLabel(item.unit);
    final status = _status(item);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: status.$2.withOpacity(0.12),
          child: Icon(Icons.inventory_2_outlined, color: status.$2),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: status.$2.withOpacity(0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                status.$1,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: status.$2,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${_formatQty(item.quantity)} $unit'
            '  ·  ${inventoryCategoryLabel(item.category)}'
            '  ·  ${_money(item.stockValue)} $currency'
            '${item.expiresAt != null ? '  ·  تنتهي ${_date(item.expiresAt!)}' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
              case 'delete':
                onDelete();
              case 'stocktake':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StocktakeScreen()),
                );
              default:
                onMovement(value);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'purchase', child: Text('شراء')),
            PopupMenuItem(value: 'usage', child: Text('صرف')),
            PopupMenuItem(value: 'waste', child: Text('هدر')),
            PopupMenuItem(value: 'damage', child: Text('تلف')),
            PopupMenuItem(value: 'adjustment', child: Text('جرد')),
            PopupMenuItem(value: 'expiry', child: Text('إتلاف منتهي')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'edit', child: Text('تعديل')),
            PopupMenuItem(value: 'stocktake', child: Text('جرد شامل')),
            PopupMenuItem(value: 'delete', child: Text('حذف / تعطيل')),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.health, required this.currency});

  final InventoryHealth health;
  final String currency;

  @override
  Widget build(BuildContext context) {
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
                const Expanded(
                  child: Text(
                    'ملخص المخزون',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                Text(
                  '${health.activeItems} نشط',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                    child: _metric(
                        'أصناف', '${health.activeItems}', scheme.primary)),
                Expanded(
                    child: _metric(
                        'القيمة',
                        '${_money(health.totalValue)} $currency',
                        Colors.teal.shade700)),
                Expanded(
                    child: _metric('تحت الحد', '${health.lowStock}',
                        Colors.orange.shade800)),
                Expanded(
                    child: _metric(
                        'نافد', '${health.outOfStock}', Colors.red.shade700)),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _RestockBanner extends StatelessWidget {
  const _RestockBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.shopping_cart_outlined,
                  size: 20, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count مادة تحتاج شراءً — اعرض القائمة المقترحة',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
              Icon(Icons.chevron_left_rounded,
                  size: 18, color: Colors.orange.shade800),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentMovement extends StatelessWidget {
  const _RecentMovement({
    required this.movement,
    required this.itemName,
    required this.currency,
  });

  final InventoryMovement movement;
  final String itemName;
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
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(
          movement.type == 'purchase'
              ? Icons.add_circle_outline
              : movement.type == 'adjustment'
                  ? Icons.swap_vert_rounded
                  : Icons.remove_circle_outline,
          color: color,
        ),
        title: Text(
          '$itemName  $sign${_formatQty(movement.quantity)}'
          '${movement.quantity * movement.unitCost > 0 ? '  ·  ${_money(movement.quantity * movement.unitCost)} $currency' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${inventoryMovementLabel(movement.type)}'
          '${movement.reason.isEmpty ? '' : ' · ${movement.reason}'}'
          '${movement.balanceAfter != null ? '  →  ${_formatQty(movement.balanceAfter!)}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _EmptyInventory extends StatelessWidget {
  const _EmptyInventory({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              'أضف شامبو، صبغة، شفرات… ثم سجّل الشراء والصرف والجرد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('إضافة أول مادة'),
            ),
          ],
        ),
      ),
    );
  }
}

(String, Color) _status(InventoryItem item) {
  if (!item.active) return ('معطّل', Colors.grey);
  if (item.quantity <= 0) return ('نافد', Colors.red.shade700);
  if (item.isExpired) return ('منتهي', Colors.red.shade700);
  if (item.lowStock) return ('تحت الحد', Colors.orange.shade800);
  if (item.expiringSoon) return ('قريب الانتهاء', Colors.orange.shade700);
  return ('متوفر', Colors.green.shade700);
}

String _formatQty(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _money(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _date(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/'
    '${value.day.toString().padLeft(2, '0')}';
