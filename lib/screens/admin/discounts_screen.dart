import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/strings.dart';
import '../../models/discount.dart';
import '../../providers/discount_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/shop_manager.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/labeled_field.dart';

class DiscountsScreen extends StatelessWidget {
  const DiscountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final discounts = context.watch<DiscountProvider>();
    return Scaffold(
      body: discounts.discounts.isEmpty
          ? EmptyState(
              icon: Icons.local_offer_outlined,
              title: t(context).discounts,
              action: FilledButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(t(context).addDiscount),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: discounts.discounts.length,
              itemBuilder: (context, i) {
                final d = discounts.discounts[i];
                final expired = !d.isUsable(0) || !d.active;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _edit(context, discount: d),
                    leading: CircleAvatar(
                      backgroundColor: Colors.pink.withOpacity(0.12),
                      child: Icon(Icons.local_offer_rounded,
                          color: Colors.pink.shade400),
                    ),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            d.code,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!expired)
                          const Icon(Icons.verified_rounded,
                              size: 18, color: Colors.green),
                      ],
                    ),
                    subtitle: Text(
                      '${d.type == 'percent' ? '${d.value.toStringAsFixed(0)}%' : fmtPrice(d.value, _currency(context))}'
                      ' · ${t(context).usedCount}: ${d.usageCount}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    trailing: IconButton(
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: t(context).deleteDiscountConfirm,
                            confirmText: t(context).delete,
                            destructive: true);
                        if (ok && context.mounted) {
                          await context
                              .read<DiscountProvider>()
                              .delete(d.id, ShopManager.shopId!);
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(t(context).addDiscount),
      ),
    );
  }

  String _currency(BuildContext context) =>
      context.read<ShopProvider>().settings?.currency ?? 'SAR';

  Future<void> _edit(BuildContext context, {Discount? discount}) async {
    final code = TextEditingController(text: discount?.code ?? '');
    final title = TextEditingController(text: discount?.title ?? '');
    final value = TextEditingController(
        text: discount?.value.toString() ?? '');
    final minValue = TextEditingController(
        text: discount?.minValue.toString() ?? '0');
    final maxDiscount = TextEditingController(
        text: discount?.maxDiscount.toString() ?? '0');
    final usageLimit = TextEditingController(
        text: discount?.usageLimit.toString() ?? '0');

    var type = discount?.type ?? 'percent';
    var active = discount?.active ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(discount == null
              ? t(ctx).addDiscount
              : t(ctx).editDiscount),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LabeledField(
                  label: t(ctx).promoCode,
                  child: TextField(controller: code),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: t(ctx).promoTitle,
                  child: TextField(controller: title),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'percent',
                        label: Text(t(ctx).percentOff)),
                    ButtonSegment(
                        value: 'fixed',
                        label: Text(t(ctx).fixedAmount)),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) =>
                      setState(() => type = s.first),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: type == 'percent'
                      ? t(ctx).percentOff
                      : t(ctx).fixedAmount,
                  child: TextField(
                    controller: value,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: t(ctx).minValue,
                        child: TextField(
                          controller: minValue,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LabeledField(
                        label: t(ctx).maxDiscount,
                        child: TextField(
                          controller: maxDiscount,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: t(ctx).usageLimit,
                  child: TextField(
                    controller: usageLimit,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t(ctx).promoActive),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
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
                if (code.text.trim().isEmpty) return;
                final data = Discount(
                  id: discount?.id ?? const Uuid().v4(),
                  code: code.text.trim().toUpperCase(),
                  title: title.text.trim(),
                  type: type,
                  value: double.tryParse(value.text) ?? 0,
                  minValue: double.tryParse(minValue.text) ?? 0,
                  maxDiscount: double.tryParse(maxDiscount.text) ?? 0,
                  usageLimit: int.tryParse(usageLimit.text) ?? 0,
                  usageCount: discount?.usageCount ?? 0,
                  active: active,
                );
                final provider = context.read<DiscountProvider>();
                final shopId = ShopManager.shopId!;
                if (discount == null) {
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
