import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/strings.dart';
import '../../models/service.dart';
import '../../providers/shop_provider.dart';
import '../../providers/business_tools_provider.dart';
import '../../services/shop_manager.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/labeled_field.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    return Scaffold(
      body: shop.services.isEmpty
          ? EmptyState(
              icon: Icons.content_cut_rounded,
              title: t(context).noServices,
              action: FilledButton.icon(
                onPressed: () => _editService(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(t(context).addService),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: shop.services.length,
              itemBuilder: (context, i) {
                final s = shop.services[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _editService(context, service: s),
                    leading: CircleAvatar(
                      backgroundColor: Color(s.colorValue).withOpacity(0.15),
                      child: Icon(Icons.content_cut_rounded,
                          color: Color(s.colorValue), size: 20),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(s.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (s.highDemand)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '⚡',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${fmtPrice(s.price, shop.settings?.currency ?? 'SAR')}'
                      ' · ${s.durationMinutes} ${t(context).minutesShort}'
                      ' · ${_categoryLabel(context, s.category)}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    trailing: IconButton(
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: t(context).deleteServiceConfirm,
                            confirmText: t(context).delete,
                            destructive: true);
                        if (ok && context.mounted) {
                          await context
                              .read<ShopProvider>()
                              .deleteService(s.id, ShopManager.shopId!);
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editService(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(t(context).addService),
      ),
    );
  }

  String _categoryLabel(BuildContext context, String category) {
    switch (category) {
      case 'haircut': return t(context).catHaircut;
      case 'beard': return t(context).catBeard;
      case 'shave': return t(context).catShave;
      case 'styling': return t(context).catStyling;
      case 'color': return t(context).catColor;
      case 'treatment': return t(context).catTreatment;
      default: return t(context).catOther;
    }
  }

  Future<void> _editService(BuildContext context, {Service? service}) async {
    final shop = context.read<ShopProvider>();
    final currency = shop.settings?.currency ?? 'SAR';
    final name = TextEditingController(text: service?.name ?? '');
    final desc = TextEditingController(text: service?.description ?? '');
    final price = TextEditingController(
        text: service?.price.toString() ?? '');
    final dur = TextEditingController(
        text: (service?.durationMinutes ?? 30).toString());
    final deposit = TextEditingController(
        text: (service?.depositAmount ?? 0).toString());

    var category = service?.category ?? 'haircut';
    var highDemand = service?.highDemand ?? false;
    var active = service?.active ?? true;
    final inventory = context.read<BusinessToolsProvider>().inventory;
    final materialRequirements = <String, double>{
      ...?service?.materialRequirements,
    };

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(service == null
              ? t(ctx).addService
              : t(ctx).editService),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LabeledField(
                  label: t(ctx).serviceName,
                  child: TextField(controller: name),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: t(ctx).description,
                  child: TextField(controller: desc),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: currency,
                        child: TextField(
                          controller: price,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LabeledField(
                        label: '${t(ctx).durationMinutes} (${t(ctx).minutesShort})',
                        child: TextField(
                          controller: dur,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(
                      labelText: t(ctx).category),
                  items: [
                    'haircut', 'beard', 'shave', 'styling', 'color', 'treatment', 'other',
                  ].map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(_categoryLabel(ctx, c)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => category = v ?? 'other'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t(ctx).highDemand),
                  value: highDemand,
                  onChanged: (v) => setState(() => highDemand = v),
                ),
                if (inventory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Align(alignment: AlignmentDirectional.centerStart, child: Text('المواد المستهلكة في هذه الخدمة', style: TextStyle(fontWeight: FontWeight.w700))),
                  const SizedBox(height: 6),
                  ...inventory.where((item) => item.active).map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: '${item.name} (${item.unit})', hintText: 'اتركه فارغًا إذا لم تُستهلك المادة'),
                        controller: TextEditingController(text: materialRequirements[item.id]?.toString() ?? ''),
                        onChanged: (value) {
                          final quantity = double.tryParse(value.replaceAll(',', '.'));
                          if (quantity == null || quantity <= 0) {
                            materialRequirements.remove(item.id);
                          } else {
                            materialRequirements[item.id] = quantity;
                          }
                        },
                      ),
                    );
                  }),
                ],
                if (highDemand)
                  LabeledField(
                    label: t(ctx).depositAmount,
                    child: TextField(
                      controller: deposit,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t(ctx).active),
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
                if (name.text.trim().isEmpty) return;
                final data = Service(
                  id: service?.id ?? const Uuid().v4(),
                  name: name.text.trim(),
                  description: desc.text.trim(),
                  price: double.tryParse(price.text) ?? 0,
                  durationMinutes: int.tryParse(dur.text) ?? 30,
                  category: category,
                  highDemand: highDemand,
                  depositAmount: double.tryParse(deposit.text) ?? 0,
                  active: active,
                  sortOrder: service?.sortOrder ?? 999,
                  materialRequirements: materialRequirements,

                );
                final shopProvider = context.read<ShopProvider>();
                final shopId = ShopManager.shopId!;
                if (service == null) {
                  await shopProvider.addService(data, shopId);
                } else {
                  await shopProvider.updateService(data, shopId);
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
