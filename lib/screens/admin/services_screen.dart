import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/strings.dart';
import '../../models/service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/shop_manager.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/live_badge.dart';
import '../../widgets/search_field.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _categoryFilter; // null = الكل

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _categoryLabel(BuildContext context, String category) {
    switch (category) {
      case 'haircut':
        return t(context).catHaircut;
      case 'beard':
        return t(context).catBeard;
      case 'shave':
        return t(context).catShave;
      case 'styling':
        return t(context).catStyling;
      case 'color':
        return t(context).catColor;
      case 'treatment':
        return t(context).catTreatment;
      default:
        return t(context).catOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final canManage = context.watch<AuthProvider>().canManageRules;
    final q = _query.toLowerCase();

    final filtered = shop.services.where((s) {
      if (_categoryFilter != null && s.category != _categoryFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      final hay = '${s.name} ${s.description} ${s.category}'.toLowerCase();
      return hay.contains(q);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: SearchField(
                    controller: _search,
                    hint: 'بحث عن خدمة...',
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                const LiveBadge(compact: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('الكل'),
                    selected: _categoryFilter == null,
                    onSelected: (_) =>
                        setState(() => _categoryFilter = null),
                  ),
                  const SizedBox(width: 8),
                  for (final c in const [
                    'haircut',
                    'beard',
                    'shave',
                    'styling',
                    'color',
                    'treatment',
                    'other',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_categoryLabel(context, c)),
                        selected: _categoryFilter == c,
                        onSelected: (v) => setState(
                          () => _categoryFilter = v ? c : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.content_cut_rounded,
                    title: t(context).noServices,
                    action: canManage
                        ? FilledButton.icon(
                            onPressed: () => _editService(context),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(t(context).addService),
                          )
                        : null,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final s = filtered[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: canManage
                              ? () => _editService(context, service: s)
                              : null,
                          leading: CircleAvatar(
                            backgroundColor:
                                Color(s.colorValue).withOpacity(0.15),
                            child: Icon(Icons.content_cut_rounded,
                                color: Color(s.colorValue), size: 20),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (s.highDemand)
                                const Text('⚡', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          subtitle: Text(
                            '${fmtPrice(s.price, shop.settings?.currency ?? 'SAR')}'
                            ' · ${s.durationMinutes} ${t(context).minutesShort}'
                            ' · ${_categoryLabel(context, s.category)}',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 12,
                            ),
                          ),
                          trailing: canManage
                              ? IconButton(
                                  onPressed: () async {
                                    final ok = await confirmDialog(context,
                                        title: t(context).deleteServiceConfirm,
                                        confirmText: t(context).delete,
                                        destructive: true);
                                    if (ok && context.mounted) {
                                      await context
                                          .read<ShopProvider>()
                                          .deleteService(
                                              s.id, ShopManager.shopId!);
                                    }
                                  },
                                  icon: const Icon(
                                      Icons.delete_outline_rounded),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'services_fab',
              onPressed: () => _editService(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(t(context).addService),
            )
          : null,
    );
  }

  Future<void> _editService(BuildContext context, {Service? service}) async {
    final shop = context.read<ShopProvider>();
    final currency = shop.settings?.currency ?? 'SAR';
    final name = TextEditingController(text: service?.name ?? '');
    final desc = TextEditingController(text: service?.description ?? '');
    final price =
        TextEditingController(text: service?.price.toString() ?? '');
    final dur = TextEditingController(
        text: (service?.durationMinutes ?? 30).toString());
    final deposit = TextEditingController(
        text: (service?.depositAmount ?? 0).toString());

    var category = service?.category ?? 'haircut';
    var highDemand = service?.highDemand ?? false;
    var active = service?.active ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
              service == null ? t(ctx).addService : t(ctx).editService),
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
                        label:
                            '${t(ctx).durationMinutes} (${t(ctx).minutesShort})',
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
                  decoration:
                      InputDecoration(labelText: t(ctx).category),
                  items: [
                    'haircut',
                    'beard',
                    'shave',
                    'styling',
                    'color',
                    'treatment',
                    'other',
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
