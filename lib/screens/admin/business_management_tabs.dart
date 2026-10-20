import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/business_features.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';

class CustomerManagementTab extends StatefulWidget {
  const CustomerManagementTab({super.key});

  @override
  State<CustomerManagementTab> createState() => _CustomerManagementTabState();
}

class _CustomerManagementTabState extends State<CustomerManagementTab> {
  final _search = TextEditingController();
  bool _inactiveOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _normalize(String value) =>
      value.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _showCustomerDialog(BuildContext context, {CustomerProfile? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final preferredTime = TextEditingController(text: existing?.preferredTime ?? '');
    var marketingOptIn = existing?.marketingOptIn ?? false;
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? t(context).addCustomer : t(context).editCustomerProfile),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: InputDecoration(labelText: t(context).customerNameField),
                    validator: (v) => v == null || v.trim().isEmpty ? t(context).customerNameRequired : null,
                  ),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: t(context).phoneNumberField),
                    validator: (v) => _normalize(v ?? '').isEmpty ? t(context).phoneRequired : null,
                  ),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: t(context).email),
                    validator: (v) => v != null && v.trim().isNotEmpty && !v.contains('@') ? t(context).required : null,
                  ),
                  TextFormField(
                    controller: preferredTime,
                    decoration: InputDecoration(labelText: t(context).preferredTimeField),
                  ),
                  TextFormField(
                    controller: notes,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: t(context).customerNotesField),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t(context).marketingOptIn),
                    value: marketingOptIn,
                    onChanged: (value) => setState(() => marketingOptIn = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(t(context).cancel)),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) Navigator.pop(context, true);
              },
              child: Text(t(context).save),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    final tools = context.read<BusinessToolsProvider>();
    final normalizedPhone = _normalize(phone.text);
    final now = DateTime.now();
    await tools.saveCustomer(CustomerProfile(
      id: existing?.id ?? normalizedPhone,
      name: name.text.trim(),
      phone: normalizedPhone,
      email: email.text.trim(),
      visitCount: existing?.visitCount ?? 0,
      totalSpent: existing?.totalSpent ?? 0,
      firstVisitAt: existing?.firstVisitAt,
      lastVisitAt: existing?.lastVisitAt,
      nextExpectedVisitAt: existing?.nextExpectedVisitAt,
      averageVisitIntervalDays: existing?.averageVisitIntervalDays ?? 0,
      preferredServiceIds: existing?.preferredServiceIds ?? const [],
      preferredEmployeeId: existing?.preferredEmployeeId,
      preferredTime: preferredTime.text.trim(),
      notes: notes.text.trim(),
      marketingOptIn: marketingOptIn,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final shop = context.watch<ShopProvider>();
    final threshold = tools.loyaltyRules.where((r) => r.enabled).firstOrNull?.inactiveAfterDays ?? 45;
    final query = _search.text.trim().toLowerCase();
    final customers = tools.customers.where((customer) {
      final matches = query.isEmpty ||
          customer.name.toLowerCase().contains(query) ||
          customer.phone.contains(query);
      return matches && (!_inactiveOnly || customer.isInactive(threshold));
    }).toList();
    final inactive = tools.customers.where((c) => c.isInactive(threshold)).length;
    final permanent = tools.customers.where((c) => c.isPermanent).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bt_customers_fab',
        onPressed: () => _showCustomerDialog(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(t(context).addCustomer),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(child: _MetricCard(label: t(context).metricTotalCustomers, value: '${tools.customers.length}', icon: Icons.people_alt_outlined)),
                const SizedBox(width: 8),
                Expanded(child: _MetricCard(label: t(context).metricLoyalCustomers, value: '$permanent', icon: Icons.verified_outlined)),
                const SizedBox(width: 8),
                Expanded(child: _MetricCard(label: t(context).metricNeedFollowUp, value: '$inactive', icon: Icons.notifications_active_outlined)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: t(context).searchCustomersHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _inactiveOnly,
                  label: Text(t(context).filterInactive),
                  avatar: const Icon(Icons.access_time, size: 18),
                  onSelected: (value) => setState(() => _inactiveOnly = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: customers.isEmpty
                ? Center(child: Text(t(context).customersEmpty))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      final inactiveCustomer = customer.isInactive(threshold);
                      final preferredServices = customer.preferredServiceIds
                          .map((id) => shop.serviceById(id)?.name ?? id)
                          .join(t(context).listSeparator);
                      final preferredBarber = customer.preferredEmployeeId == null
                          ? ''
                          : shop.employeeById(customer.preferredEmployeeId!)?.name ?? '';
                      final status = customer.visitCount == 0
                          ? t(context).customerStatusFirstVisit
                          : customer.isPermanent
                              ? t(context).customerStatusLoyal
                              : customer.isReturning
                                  ? t(context).customerStatusReturning
                                  : t(context).customerStatusSingleVisit;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(customer.name.isEmpty ? '?' : customer.name.characters.first)),
                          title: Row(
                            children: [
                              Expanded(child: Text(customer.name.isEmpty ? customer.phone : customer.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                              if (inactiveCustomer) const Icon(Icons.notifications_active_outlined, color: Colors.orange, size: 19),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              t(context).customerSummary(
                                customer.phone,
                                status,
                                '${customer.visitCount}',
                                customer.lastVisitAt == null
                                    ? t(context).noneValue
                                    : DateFormat('yyyy/MM/dd').format(customer.lastVisitAt!),
                                customer.averageVisitIntervalDays <= 0
                                    ? t(context).unknown
                                    : t(context).daysCount(customer.averageVisitIntervalDays.toStringAsFixed(0)),
                                customer.preferredTime.isEmpty ? t(context).notSet : customer.preferredTime,
                                preferredServices.isEmpty ? t(context).notSpecified : preferredServices,
                                preferredBarber.isEmpty ? t(context).notSet : preferredBarber,
                              ),
                            ),
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') await _showCustomerDialog(context, existing: customer);
                              if (value == 'delete') await tools.deleteCustomer(customer.id);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: Text(t(context).menuEditProfile)),
                              PopupMenuItem(value: 'delete', child: Text(t(context).menuDeleteProfile)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

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
    // Loyalty rules and gifts are owner-only collections; the loyalty ledger
    // itself stays manager-scoped, so managers keep earning/redeeming controls.
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

class ChairOperationsTab extends StatefulWidget {
  const ChairOperationsTab({super.key});

  @override
  State<ChairOperationsTab> createState() => _ChairOperationsTabState();
}

class _ChairOperationsTabState extends State<ChairOperationsTab> {
  DateTime _weekStart = _startOfWeek(DateTime.now());

  static DateTime _startOfWeek(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  String _weekId() => DateFormat('yyyyMMdd').format(_weekStart);

  Future<void> _showChairDialog(BuildContext context, {Chair? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final number = TextEditingController(text: existing?.number ?? '');
    final formKey = GlobalKey<FormState>();
    final shop = context.read<ShopProvider>();
    var employeeId = existing?.employeeId;
    var active = existing?.active ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? t(context).addChair : t(context).editChair),
          content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: number, decoration: InputDecoration(labelText: t(context).chairNumberField)),
              TextFormField(controller: name, decoration: InputDecoration(labelText: t(context).chairNameField), validator: (v) => v == null || v.trim().isEmpty ? t(context).required : null),
              DropdownButtonFormField<String>(
                value: employeeId,
                decoration: InputDecoration(labelText: t(context).assignedBarberField),
                items: shop.activeEmployees.map((employee) => DropdownMenuItem(value: employee.id, child: Text(employee.name))).toList(),
                onChanged: (value) => setState(() => employeeId = value),
              ),
              SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: Text(t(context).chairActive), value: active, onChanged: (value) => setState(() => active = value)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(t(context).cancel)),
            FilledButton(onPressed: () { if (formKey.currentState?.validate() ?? false) Navigator.pop(context, true); }, child: Text(t(context).save)),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    final tools = context.read<BusinessToolsProvider>();
    await tools.saveChair(Chair(id: existing?.id ?? tools.newId(), name: name.text.trim(), number: number.text.trim(), employeeId: employeeId, active: active));
  }

  Future<void> _showSupplyDialog(BuildContext context) async {
    final tools = context.read<BusinessToolsProvider>();
    if (tools.chairs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context).addChairFirst)));
      return;
    }
    var chairId = tools.chairs.first.id;
    final name = TextEditingController();
    final category = TextEditingController(text: t(context).catShave);
    final unit = TextEditingController(text: t(context).unitPiece);
    final quantity = TextEditingController(text: '0');
    final unitCost = TextEditingController(text: '0');
    final reorder = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(t(context).addSupply),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(value: chairId, decoration: InputDecoration(labelText: t(context).chairField), items: tools.chairs.map((chair) => DropdownMenuItem(value: chair.id, child: Text(_chairLabel(context, chair)))).toList(), onChanged: (value) => setState(() => chairId = value ?? chairId)),
              TextFormField(controller: name, decoration: InputDecoration(labelText: t(context).supplyNameField), validator: (v) => v == null || v.trim().isEmpty ? t(context).required : null),
              TextField(controller: category, decoration: InputDecoration(labelText: t(context).category)),
              TextField(controller: unit, decoration: InputDecoration(labelText: t(context).unitField)),
              TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t(context).quantityField)),
              TextField(controller: unitCost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t(context).unitCostField)),
              TextField(controller: reorder, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t(context).reorderLevelField)),
            ])),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t(context).cancel)), FilledButton(onPressed: () { if (formKey.currentState?.validate() ?? false) Navigator.pop(context, true); }, child: Text(t(context).save))],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    await tools.saveChairSupply(ChairSupply(
      id: tools.newId(),
      chairId: chairId,
      name: name.text.trim(),
      category: category.text.trim(),
      unit: unit.text.trim(),
      quantity: double.tryParse(quantity.text) ?? 0,
      unitCost: double.tryParse(unitCost.text) ?? 0,
      reorderLevel: double.tryParse(reorder.text) ?? 0,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _showProfitDialog(BuildContext context, Chair chair, ChairWeeklyProfit computed) async {
    final profit = TextEditingController(text: computed.manualProfit?.toStringAsFixed(2) ?? '');
    final notes = TextEditingController(text: computed.notes);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t(context).chairProfitTitle(_chairLabel(context, chair), DateFormat('yyyy/MM/dd').format(_weekStart))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t(context).chairProfitRevenue(fmtPrice(computed.revenue, context.read<ShopProvider>().settings?.currency ?? 'SAR'), fmtPrice(computed.supplyCost, context.read<ShopProvider>().settings?.currency ?? 'SAR'))),
          TextField(controller: profit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t(context).manualProfitField)),
          TextField(controller: notes, maxLines: 2, decoration: InputDecoration(labelText: t(context).weekNotesField)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t(context).cancel)), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t(context).saveReport))],
      ),
    );
    if (saved != true || !context.mounted) return;
    final tools = context.read<BusinessToolsProvider>();
    await tools.saveWeeklyProfit(ChairWeeklyProfit(
      id: '${_weekId()}_${chair.id}',
      chairId: chair.id,
      weekStart: _weekStart,
      weekEnd: _weekStart.add(const Duration(days: 6, hours: 23, minutes: 59)),
      revenue: computed.revenue,
      supplyCost: computed.supplyCost,
      manualProfit: double.tryParse(profit.text),
      completedVisits: computed.completedVisits,
      workingMinutes: computed.workingMinutes,
      notes: notes.text.trim(),
      updatedAt: DateTime.now(),
    ));
  }

  String _chairLabel(BuildContext context, Chair chair) => chair.number.trim().isEmpty ? chair.name : t(context).chairLabel(chair.number, chair.name);

  ChairWeeklyProfit _computedReport(BusinessToolsProvider tools, Chair chair) {
    final end = _weekStart.add(const Duration(days: 7));
    final appointments = tools.appointments.where((appointment) => appointment.chairId == chair.id && appointment.status == AppointmentStatus.completed && !appointment.startTime.isBefore(_weekStart) && appointment.startTime.isBefore(end)).toList();
    final payments = tools.payments.where((payment) => payment.chairId == chair.id && !payment.paidAt.isBefore(_weekStart) && payment.paidAt.isBefore(end)).toList();
    final stored = tools.weeklyProfits.where((report) => report.id == '${_weekId()}_${chair.id}').firstOrNull;
    final revenue = appointments.fold<double>(0, (sum, appointment) => sum + appointment.totalAmount);
    final supplyCost = payments.fold<double>(0, (sum, payment) => sum + payment.materialCost);
    final workingMinutes = appointments.fold<int>(0, (sum, appointment) => sum + appointment.endTime.difference(appointment.startTime).inMinutes);
    return ChairWeeklyProfit(
      id: stored?.id ?? '${_weekId()}_${chair.id}',
      chairId: chair.id,
      weekStart: _weekStart,
      weekEnd: end.subtract(const Duration(minutes: 1)),
      revenue: revenue,
      supplyCost: supplyCost,
      manualProfit: stored?.manualProfit,
      completedVisits: appointments.length,
      workingMinutes: workingMinutes,
      notes: stored?.notes ?? '',
      updatedAt: stored?.updatedAt ?? DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    // Chairs, their supplies and weekly profits are owner-only collections.
    final canManage = context.watch<AuthProvider>().canManageRules;
    final currency = context.watch<ShopProvider>().settings?.currency ?? 'SAR';
    final totalProfit = tools.chairs.fold<double>(0, (sum, chair) => sum + _computedReport(tools, chair).profit);
    final lowStock = tools.chairSupplies.where((supply) => supply.lowStock).length;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          Row(children: [
            Expanded(child: _MetricCard(label: t(context).metricActiveChairs, value: '${tools.chairs.where((c) => c.active).length}', icon: Icons.event_seat_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _MetricCard(label: t(context).metricWeekProfit, value: fmtPrice(totalProfit, currency), icon: Icons.trending_up_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _MetricCard(label: t(context).metricLowStock, value: '$lowStock', icon: Icons.inventory_2_outlined)),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(title: t(context).sectionChairsAndBarbers, actionLabel: t(context).addChairAction, onPressed: canManage ? () => _showChairDialog(context) : null),
          if (tools.chairs.isEmpty)
            Card(child: ListTile(title: Text(t(context).noChairsYet), subtitle: Text(t(context).noChairsSubtitle)))
          else
            ...tools.chairs.map((chair) {
              final employee = chair.employeeId == null ? null : context.read<ShopProvider>().activeEmployees.where((e) => e.id == chair.employeeId).firstOrNull;
              return Card(child: ListTile(
                leading: CircleAvatar(child: Text(chair.number.isEmpty ? '—' : chair.number)),
                title: Text(_chairLabel(context, chair)),
                subtitle: Text('${employee == null ? t(context).chairUnassigned : t(context).chairAssignedBarber(employee.name)}  •  ${chair.active ? t(context).active : t(context).chairInactiveState}'),
                trailing: canManage ? PopupMenuButton<String>(onSelected: (value) { if (value == 'edit') _showChairDialog(context, existing: chair); if (value == 'delete') tools.deleteChair(chair.id); }, itemBuilder: (_) => [PopupMenuItem(value: 'edit', child: Text(t(context).edit)), PopupMenuItem(value: 'delete', child: Text(t(context).delete))]) : null,
              ));
            }),
          const SizedBox(height: 16),
          _SectionHeader(title: t(context).sectionChairSupplies, actionLabel: t(context).addSupplyAction, onPressed: canManage ? () => _showSupplyDialog(context) : null),
          if (tools.chairSupplies.isEmpty)
            Card(child: ListTile(title: Text(t(context).noSuppliesYet), subtitle: Text(t(context).noSuppliesSubtitle)))
          else
            ...tools.chairSupplies.map((supply) {
              final chair = tools.chairs.where((c) => c.id == supply.chairId).firstOrNull;
              return Card(child: ListTile(
                leading: Icon(supply.lowStock ? Icons.warning_amber_rounded : Icons.inventory_2_outlined, color: supply.lowStock ? Colors.orange : null),
                title: Text(supply.name),
                subtitle: Text('${chair == null ? t(context).unknownChair : _chairLabel(context, chair)}  •  ${supply.quantity} ${supply.unit}  •  ${t(context).unitCostField} ${supply.unitCost}'),
                trailing: canManage ? PopupMenuButton<String>(onSelected: (value) { if (value == 'delete') tools.deleteChairSupply(supply.id); }, itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text(t(context).delete))]) : null,
              ));
            }),
          const SizedBox(height: 16),
          _SectionHeader(title: t(context).sectionChairProfit, actionLabel: '', onPressed: null),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(onPressed: () => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_right)),
                Text('${DateFormat('yyyy/MM/dd').format(_weekStart)} — ${DateFormat('yyyy/MM/dd').format(_weekStart.add(const Duration(days: 6)))}', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(onPressed: () => setState(() => _weekStart = _weekStart.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_left)),
              ]),
            ),
          ),
          ...tools.chairs.map((chair) {
            final report = _computedReport(tools, chair);
            return Card(child: ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: Text(_chairLabel(context, chair)),
              subtitle: Text(t(context).chairReportSummary('${report.completedVisits}', report.utilizationPercent.toStringAsFixed(1), fmtPrice(report.revenue, currency), fmtPrice(report.supplyCost, currency))),
              isThreeLine: true,
              trailing: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmtPrice(report.profit, currency), style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(report.manualProfit == null ? t(context).computedLabel : t(context).manualApprovedLabel, style: TextStyle(fontSize: 11, color: report.manualProfit == null ? Colors.grey : Colors.green)),
                  if (canManage)
                    TextButton(onPressed: () => _showProfitDialog(context, chair, report), child: Text(t(context).editProfit)),
                ]),
              ),
            ));
          }),
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
