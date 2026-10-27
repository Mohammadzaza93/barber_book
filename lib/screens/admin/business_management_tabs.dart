import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/business_features.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import '../../theme/app_theme.dart';

export 'customer_management_tab.dart';

class LoyaltyProgramTab extends StatelessWidget {
  const LoyaltyProgramTab({super.key});

  Future<void> _showRuleDialog(BuildContext context, {LoyaltyRule? existing}) async {
    final name = TextEditingController(text: existing?.name ?? t(context).defaultRuleName);
    final description = TextEditingController(text: existing?.description ?? '');
    final visit = TextEditingController(text: '${existing?.pointsPerVisit ?? 10}');
    final currency = TextEditingController(text: '${existing?.pointsPerCurrency ?? 1}');
    final minimum = TextEditingController(text: '${existing?.minimumSpend ?? 0}');
    final bonus = TextEditingController(text: '${existing?.bonusPoints ?? 0}');
    final inactive = TextEditingController(text: '${existing?.inactiveAfterDays ?? 45}');
    var enabled = existing?.enabled ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? t(context).addLoyaltyRule : t(context).editLoyaltyRule),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: InputDecoration(labelText: t(context).ruleNameField)),
                TextField(controller: description, decoration: InputDecoration(labelText: t(context).ruleDescriptionField)),
                TextField(controller: visit, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t(context).pointsPerVisitField)),
                TextField(controller: currency, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t(context).pointsPerCurrencyField)),
                TextField(controller: minimum, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t(context).minimumSpendField)),
                TextField(controller: bonus, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t(context).bonusPointsField)),
                TextField(controller: inactive, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t(context).inactiveDaysField)),
                SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: Text(t(context).ruleEnabled), value: enabled, onChanged: (v) => setState(() => enabled = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(t(context).cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t(context).save)),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    final tools = context.read<BusinessToolsProvider>();
    final rule = LoyaltyRule(
      id: existing?.id ?? tools.newId(),
      name: name.text.trim().isEmpty ? t(context).loyaltyRuleFallbackName : name.text.trim(),
      description: description.text.trim(),
      enabled: enabled,
      pointsPerVisit: int.tryParse(visit.text) ?? 0,
      pointsPerCurrency: double.tryParse(currency.text) ?? 1,
      minimumSpend: double.tryParse(minimum.text) ?? 0,
      bonusPoints: int.tryParse(bonus.text) ?? 0,
      inactiveAfterDays: int.tryParse(inactive.text) ?? 45,
      updatedAt: DateTime.now(),
    );
    await tools.saveLoyaltyRule(rule);
  }

  Future<void> _showGiftDialog(BuildContext context, {LoyaltyGift? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final description = TextEditingController(text: existing?.description ?? '');
    final points = TextEditingController(text: '${existing?.pointsCost ?? 100}');
    final stock = TextEditingController(text: '${existing?.stock ?? -1}');
    var tier = existing?.minimumTier ?? 'bronze';
    var active = existing?.active ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? t(context).addGift : t(context).editGift),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: InputDecoration(labelText: t(context).giftNameField)),
                TextField(controller: description, decoration: InputDecoration(labelText: t(context).description)),
                TextField(controller: points, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t(context).giftPointsCostField)),
                TextField(controller: stock, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t(context).giftStockField)),
                DropdownButtonFormField<String>(
                  value: tier,
                  decoration: InputDecoration(labelText: t(context).minimumTierField),
                  items: const [
                    DropdownMenuItem(value: 'bronze', child: Text('Bronze')),
                    DropdownMenuItem(value: 'silver', child: Text('Silver')),
                    DropdownMenuItem(value: 'gold', child: Text('Gold')),
                    DropdownMenuItem(value: 'platinum', child: Text('Platinum')),
                  ],
                  onChanged: (value) => setState(() => tier = value ?? 'bronze'),
                ),
                SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: Text(t(context).giftAvailable), value: active, onChanged: (v) => setState(() => active = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(t(context).cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t(context).save)),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    final tools = context.read<BusinessToolsProvider>();
    await tools.saveLoyaltyGift(LoyaltyGift(
      id: existing?.id ?? tools.newId(),
      name: name.text.trim(),
      description: description.text.trim(),
      pointsCost: int.tryParse(points.text) ?? 0,
      minimumTier: tier,
      stock: int.tryParse(stock.text) ?? -1,
      redeemedCount: existing?.redeemedCount ?? 0,
      active: active,
      expiresAt: existing?.expiresAt,
      createdAt: existing?.createdAt ?? DateTime.now(),
    ));
  }

  int _tierRank(String tier) => const {'bronze': 0, 'silver': 1, 'gold': 2, 'platinum': 3}[tier] ?? 0;

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final canManage = context.watch<AuthProvider>().canManageRules;
    final activeRules = tools.loyaltyRules.where((r) => r.enabled).length;
    final totalPoints = tools.loyalty.fold<int>(0, (sum, account) => sum + account.points);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          Row(
            children: [
              Expanded(child: _MetricCard(label: t(context).metricLoyaltyAccounts, value: '${tools.loyalty.length}', icon: Icons.stars_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _MetricCard(label: t(context).metricTotalPoints, value: '$totalPoints', icon: Icons.bolt_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _MetricCard(label: t(context).metricActiveRules, value: '$activeRules', icon: Icons.rule_folder_outlined)),
            ],
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: t(context).sectionEarningRules, actionLabel: t(context).addRuleAction, onPressed: canManage ? () => _showRuleDialog(context) : null),
          if (tools.loyaltyRules.isEmpty)
            Card(child: ListTile(title: Text(t(context).noRulesYet), subtitle: Text(t(context).noRulesSubtitle)))
          else
            ...tools.loyaltyRules.map((rule) => Card(
                  child: ListTile(
                    leading: Icon(rule.enabled ? Icons.rule : Icons.rule_outlined),
                    title: Text(rule.name),
                    subtitle: Text(t(context).ruleSummary('${rule.pointsPerVisit}', '${rule.pointsPerCurrency}', '${rule.inactiveAfterDays}')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(value: rule.enabled, onChanged: canManage ? (value) => tools.saveLoyaltyRule(rule.copyWith(enabled: value, updatedAt: DateTime.now())) : null),
                        if (canManage)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _showRuleDialog(context, existing: rule);
                              if (value == 'delete') tools.deleteLoyaltyRule(rule.id);
                            },
                            itemBuilder: (_) => [PopupMenuItem(value: 'edit', child: Text(t(context).edit)), PopupMenuItem(value: 'delete', child: Text(t(context).delete))],
                          ),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          _SectionHeader(title: t(context).sectionLoyaltyGifts, actionLabel: t(context).addGift, onPressed: canManage ? () => _showGiftDialog(context) : null),
          if (tools.loyaltyGifts.isEmpty)
            Card(child: ListTile(title: Text(t(context).noGiftsYet), subtitle: Text(t(context).noGiftsSubtitle)))
          else
            ...tools.loyaltyGifts.map((gift) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.card_giftcard_outlined),
                    title: Text(gift.name),
                    subtitle: Text(t(context).giftSummary('${gift.pointsCost}', gift.minimumTier, gift.stock < 0 ? t(context).unlimited : t(context).giftStockUsed('${gift.redeemedCount}', '${gift.stock}'))),
                    trailing: canManage
                        ? PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _showGiftDialog(context, existing: gift);
                              if (value == 'delete') tools.deleteLoyaltyGift(gift.id);
                            },
                            itemBuilder: (_) => [PopupMenuItem(value: 'edit', child: Text(t(context).edit)), PopupMenuItem(value: 'delete', child: Text(t(context).delete))],
                          )
                        : null,
                  ),
                )),
          const SizedBox(height: 16),
          _SectionHeader(title: t(context).sectionCustomerBalances, actionLabel: t(context).addAccountAction, onPressed: () => _showCustomerAccountDialog(context)),
          ...tools.loyalty.map((account) {
            final gifts = tools.loyaltyGifts.where((gift) => gift.isAvailable && _tierRank(account.tier) >= _tierRank(gift.minimumTier) && account.points >= gift.pointsCost).toList();
            return Card(
              child: ExpansionTile(
                leading: CircleAvatar(child: Text('${account.points}')),
                title: Text(account.customerName.isEmpty ? account.customerPhone : account.customerName),
                subtitle: Text(t(context).loyaltyAccountSubtitle(account.customerPhone, account.tier)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        OutlinedButton.icon(onPressed: () => tools.addPoints(account.id, 10), icon: const Icon(Icons.add), label: Text(t(context).addTenPoints)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(gifts.isEmpty ? t(context).noGiftDue : t(context).dueGifts(gifts.map((gift) => gift.name).join(t(context).listSeparator)))),
                      ],
                    ),
                  ),
                  if (gifts.isNotEmpty)
                    ...gifts.map((gift) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.redeem_outlined),
                          title: Text(t(context).redeemGiftTitle(gift.name)),
                          trailing: FilledButton.tonal(
                            onPressed: () async {
                              try {
                                await tools.redeemGift(account.id, gift);
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context).giftRedeemed)));
                              } catch (error) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
                              }
                            },
                            child: Text(t(context).pointsAmount('${gift.pointsCost}')),
                          ),
                        )),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showCustomerAccountDialog(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final points = TextEditingController(text: '0');
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t(context).addLoyaltyAccount),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: InputDecoration(labelText: t(context).customerNameField)),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: t(context).phone)),
          TextField(controller: points, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t(context).initialPointsField)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t(context).cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t(context).save)),
        ],
      ),
    );
    if (saved != true || !context.mounted || phone.text.trim().isEmpty) return;
    final tools = context.read<BusinessToolsProvider>();
    final account = LoyaltyAccount(
      id: phone.text.trim(),
      customerName: name.text.trim(),
      customerPhone: phone.text.trim(),
      points: int.tryParse(points.text) ?? 0,
      updatedAt: DateTime.now(),
    );
    await tools.saveLoyalty(account.copyWith(tier: account.calculatedTier));
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 5),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          ]),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onPressed;

  const _SectionHeader({required this.title, required this.actionLabel, required this.onPressed});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          if (onPressed != null && actionLabel.isNotEmpty) TextButton.icon(onPressed: onPressed, icon: const Icon(Icons.add, size: 18), label: Text(actionLabel)),
        ],
      );
}
