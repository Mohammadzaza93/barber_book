import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/business_features.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_tools_provider.dart';

export 'customer_management_tab.dart';
export 'chair_operations_tab.dart';

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

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final canManage = context.watch<AuthProvider>().canManageRules;
    final activeRules = tools.loyaltyRules.where((r) => r.enabled).length;
    final totalPoints = tools.loyalty.fold<int>(0, (sum, a) => sum + a.points);
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
          Row(
            children: [
              Expanded(child: Text(t(context).sectionEarningRules, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              if (canManage)
                TextButton.icon(
                  onPressed: () => _showRuleDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(t(context).addRuleAction),
                ),
            ],
          ),
          if (tools.loyaltyRules.isEmpty)
            Card(child: ListTile(title: Text(t(context).noRulesYet), subtitle: Text(t(context).noRulesSubtitle)))
          else
            ...tools.loyaltyRules.map((rule) => Card(
                  child: ListTile(
                    leading: Icon(rule.enabled ? Icons.rule : Icons.rule_outlined),
                    title: Text(rule.name),
                    subtitle: Text(t(context).ruleSummary('${rule.pointsPerVisit}', '${rule.pointsPerCurrency}', '${rule.inactiveAfterDays}')),
                    trailing: canManage
                        ? PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _showRuleDialog(context, existing: rule);
                              if (value == 'delete') tools.deleteLoyaltyRule(rule.id);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: Text(t(context).edit)),
                              PopupMenuItem(value: 'delete', child: Text(t(context).delete)),
                            ],
                          )
                        : null,
                  ),
                )),
          const SizedBox(height: 16),
          Text(t(context).sectionCustomerBalances, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ...tools.loyalty.map((account) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${account.points}')),
                  title: Text(account.customerName.isEmpty ? account.customerPhone : account.customerName),
                  subtitle: Text(t(context).loyaltyAccountSubtitle(account.customerPhone, account.tier)),
                  trailing: OutlinedButton(
                    onPressed: () => tools.addPoints(account.id, 10),
                    child: Text(t(context).addTenPoints),
                  ),
                ),
              )),
        ],
      ),
    );
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
