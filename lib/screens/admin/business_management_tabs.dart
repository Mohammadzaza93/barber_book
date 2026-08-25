import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/business_features.dart';
import '../../models/enums.dart';
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
          title: Text(existing == null ? 'إضافة عميل' : 'تعديل ملف العميل'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'اسم العميل'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'اكتب اسم العميل' : null,
                  ),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                    validator: (v) => _normalize(v ?? '').isEmpty ? 'اكتب رقم الهاتف' : null,
                  ),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                  ),
                  TextFormField(
                    controller: preferredTime,
                    decoration: const InputDecoration(labelText: 'الوقت المفضل'),
                  ),
                  TextFormField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'ملاحظات وتفضيلات خاصة'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('السماح برسائل التذكير والعروض'),
                    value: marketingOptIn,
                    onChanged: (value) => setState(() => marketingOptIn = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) Navigator.pop(context, true);
              },
              child: const Text('حفظ'),
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
        onPressed: () => _showCustomerDialog(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة عميل'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(child: _MetricCard(label: 'إجمالي العملاء', value: '${tools.customers.length}', icon: Icons.people_alt_outlined)),
                const SizedBox(width: 8),
                Expanded(child: _MetricCard(label: 'عملاء دائمون', value: '$permanent', icon: Icons.verified_outlined)),
                const SizedBox(width: 8),
                Expanded(child: _MetricCard(label: 'يحتاجون متابعة', value: '$inactive', icon: Icons.notifications_active_outlined)),
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
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'ابحث بالاسم أو الهاتف',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _inactiveOnly,
                  label: const Text('الغائبون'),
                  avatar: const Icon(Icons.access_time, size: 18),
                  onSelected: (value) => setState(() => _inactiveOnly = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: customers.isEmpty
                ? const Center(child: Text('لا يوجد عملاء مطابقون. سجّل أول عميل أو انتظر اكتمال المواعيد.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      final inactiveCustomer = customer.isInactive(threshold);
                      final preferredServices = customer.preferredServiceIds
                          .map((id) => shop.serviceById(id)?.name ?? id)
                          .join('، ');
                      final preferredBarber = customer.preferredEmployeeId == null
                          ? ''
                          : shop.employeeById(customer.preferredEmployeeId!)?.name ?? '';
                      final status = customer.visitCount == 0
                          ? 'أول زيارة'
                          : customer.isPermanent
                              ? 'عميل دائم'
                              : customer.isReturning
                                  ? 'عميل متكرر'
                                  : 'زيارة واحدة';
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
                              '${customer.phone}  •  $status\n'
                              'الزيارات: ${customer.visitCount}  •  آخر زيارة: ${customer.lastVisitAt == null ? 'لا توجد' : DateFormat('yyyy/MM/dd').format(customer.lastVisitAt!)}\n'
                              'المعدل: ${customer.averageVisitIntervalDays <= 0 ? 'غير معروف' : '${customer.averageVisitIntervalDays.toStringAsFixed(0)} يوم'}  •  الوقت: ${customer.preferredTime.isEmpty ? 'غير محدد' : customer.preferredTime}\n'
                              'الخدمات المفضلة: ${preferredServices.isEmpty ? 'غير محددة' : preferredServices}  •  الحلاق المفضل: ${preferredBarber.isEmpty ? 'غير محدد' : preferredBarber}',
                            ),
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') await _showCustomerDialog(context, existing: customer);
                              if (value == 'delete') await tools.deleteCustomer(customer.id);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('تعديل الملف')),
                              PopupMenuItem(value: 'delete', child: Text('حذف الملف')),
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
    final name = TextEditingController(text: existing?.name ?? 'قاعدة النقاط الأساسية');
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
          title: Text(existing == null ? 'إضافة قاعدة ولاء' : 'تعديل قاعدة الولاء'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم القاعدة')),
                TextField(controller: description, decoration: const InputDecoration(labelText: 'وصف القاعدة')),
                TextField(controller: visit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'نقاط لكل زيارة')),
                TextField(controller: currency, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'نقاط لكل وحدة نقدية')),
                TextField(controller: minimum, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الحد الأدنى للفاتورة')),
                TextField(controller: bonus, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'نقاط إضافية عند تحقق الشرط')),
                TextField(controller: inactive, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أيام الغياب لإظهار تنبيه')),
                SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('القاعدة مفعّلة'), value: enabled, onChanged: (v) => setState(() => enabled = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    final tools = context.read<BusinessToolsProvider>();
    final rule = LoyaltyRule(
      id: existing?.id ?? tools.newId(),
      name: name.text.trim().isEmpty ? 'قاعدة ولاء' : name.text.trim(),
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
          title: Text(existing == null ? 'إضافة هدية' : 'تعديل الهدية'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الهدية')),
                TextField(controller: description, decoration: const InputDecoration(labelText: 'الوصف')),
                TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تكلفة الهدية بالنقاط')),
                TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المخزون (-1 = غير محدود)')),
                DropdownButtonFormField<String>(
                  value: tier,
                  decoration: const InputDecoration(labelText: 'أقل مستوى مسموح'),
                  items: const [
                    DropdownMenuItem(value: 'bronze', child: Text('Bronze')),
                    DropdownMenuItem(value: 'silver', child: Text('Silver')),
                    DropdownMenuItem(value: 'gold', child: Text('Gold')),
                    DropdownMenuItem(value: 'platinum', child: Text('Platinum')),
                  ],
                  onChanged: (value) => setState(() => tier = value ?? 'bronze'),
                ),
                SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('الهدية متاحة'), value: active, onChanged: (v) => setState(() => active = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
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
    final activeRules = tools.loyaltyRules.where((r) => r.enabled).length;
    final totalPoints = tools.loyalty.fold<int>(0, (sum, account) => sum + account.points);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          Row(
            children: [
              Expanded(child: _MetricCard(label: 'حسابات الولاء', value: '${tools.loyalty.length}', icon: Icons.stars_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _MetricCard(label: 'إجمالي النقاط', value: '$totalPoints', icon: Icons.bolt_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _MetricCard(label: 'قواعد فعالة', value: '$activeRules', icon: Icons.rule_folder_outlined)),
            ],
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: 'قواعد كسب النقاط', actionLabel: 'إضافة قاعدة', onPressed: () => _showRuleDialog(context)),
          if (tools.loyaltyRules.isEmpty)
            const Card(child: ListTile(title: Text('لا توجد قواعد بعد'), subtitle: Text('أضف قاعدة لتحديد نقاط الزيارة والفاتورة والتنبيه عن الغياب.')))
          else
            ...tools.loyaltyRules.map((rule) => Card(
                  child: ListTile(
                    leading: Icon(rule.enabled ? Icons.rule : Icons.rule_outlined),
                    title: Text(rule.name),
                    subtitle: Text('${rule.pointsPerVisit} نقطة/زيارة + ${rule.pointsPerCurrency} لكل وحدة نقدية  •  تنبيه بعد ${rule.inactiveAfterDays} يوم'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(value: rule.enabled, onChanged: (value) => tools.saveLoyaltyRule(rule.copyWith(enabled: value, updatedAt: DateTime.now()))),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _showRuleDialog(context, existing: rule);
                            if (value == 'delete') tools.deleteLoyaltyRule(rule.id);
                          },
                          itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))],
                        ),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          _SectionHeader(title: 'هدايا العملاء المميزين', actionLabel: 'إضافة هدية', onPressed: () => _showGiftDialog(context)),
          if (tools.loyaltyGifts.isEmpty)
            const Card(child: ListTile(title: Text('لا توجد هدايا بعد'), subtitle: Text('أضف مكافآت يمكن استبدالها بالنقاط مع تحديد المستوى والمخزون.')))
          else
            ...tools.loyaltyGifts.map((gift) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.card_giftcard_outlined),
                    title: Text(gift.name),
                    subtitle: Text('${gift.pointsCost} نقطة  •  من مستوى ${gift.minimumTier}  •  ${gift.stock < 0 ? 'غير محدود' : '${gift.redeemedCount}/${gift.stock} مستخدم'}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _showGiftDialog(context, existing: gift);
                        if (value == 'delete') tools.deleteLoyaltyGift(gift.id);
                      },
                      itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))],
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          _SectionHeader(title: 'أرصدة العملاء', actionLabel: 'إضافة حساب', onPressed: () => _showCustomerAccountDialog(context)),
          ...tools.loyalty.map((account) {
            final gifts = tools.loyaltyGifts.where((gift) => gift.isAvailable && _tierRank(account.tier) >= _tierRank(gift.minimumTier) && account.points >= gift.pointsCost).toList();
            return Card(
              child: ExpansionTile(
                leading: CircleAvatar(child: Text('${account.points}')),
                title: Text(account.customerName.isEmpty ? account.customerPhone : account.customerName),
                subtitle: Text('${account.customerPhone}  •  المستوى: ${account.tier}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        OutlinedButton.icon(onPressed: () => tools.addPoints(account.id, 10), icon: const Icon(Icons.add), label: const Text('+10 نقاط')),
                        const SizedBox(width: 8),
                        Expanded(child: Text(gifts.isEmpty ? 'لا توجد هدية مستحقة حاليًا' : 'الهدايا المستحقة: ${gifts.map((gift) => gift.name).join('، ')}')),
                      ],
                    ),
                  ),
                  if (gifts.isNotEmpty)
                    ...gifts.map((gift) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.redeem_outlined),
                          title: Text('استبدال: ${gift.name}'),
                          trailing: FilledButton.tonal(
                            onPressed: () async {
                              try {
                                await tools.redeemGift(account.id, gift);
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استبدال الهدية بنجاح')));
                              } catch (error) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
                              }
                            },
                            child: Text('${gift.pointsCost} نقطة'),
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
        title: const Text('إضافة حساب ولاء'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم العميل')),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الهاتف')),
          TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'النقاط الابتدائية')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
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
    final shop = context.read<ShopProvider>();
    var employeeId = existing?.employeeId;
    var active = existing?.active ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'إضافة كرسي حلاقة' : 'تعديل الكرسي'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: number, decoration: const InputDecoration(labelText: 'رقم الكرسي')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الكرسي')),
            DropdownButtonFormField<String>(
              value: employeeId,
              decoration: const InputDecoration(labelText: 'الحلاق المسؤول'),
              items: shop.activeEmployees.map((employee) => DropdownMenuItem(value: employee.id, child: Text(employee.name))).toList(),
              onChanged: (value) => setState(() => employeeId = value),
            ),
            SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('الكرسي يعمل حاليًا'), value: active, onChanged: (value) => setState(() => active = value)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted || name.text.trim().isEmpty) return;
    final tools = context.read<BusinessToolsProvider>();
    await tools.saveChair(Chair(id: existing?.id ?? tools.newId(), name: name.text.trim(), number: number.text.trim(), employeeId: employeeId, active: active));
  }

  Future<void> _showSupplyDialog(BuildContext context) async {
    final tools = context.read<BusinessToolsProvider>();
    if (tools.chairs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف كرسيًا أولًا قبل تسجيل مستلزماته')));
      return;
    }
    var chairId = tools.chairs.first.id;
    final name = TextEditingController();
    final category = TextEditingController(text: 'حلاقة');
    final unit = TextEditingController(text: 'قطعة');
    final quantity = TextEditingController(text: '0');
    final unitCost = TextEditingController(text: '0');
    final reorder = TextEditingController(text: '1');
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إضافة مستلزم للكرسي'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(value: chairId, decoration: const InputDecoration(labelText: 'الكرسي'), items: tools.chairs.map((chair) => DropdownMenuItem(value: chair.id, child: Text(_chairLabel(chair)))).toList(), onChanged: (value) => setState(() => chairId = value ?? chairId)),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المادة')),
            TextField(controller: category, decoration: const InputDecoration(labelText: 'الفئة')),
            TextField(controller: unit, decoration: const InputDecoration(labelText: 'الوحدة')),
            TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الكمية الحالية')),
            TextField(controller: unitCost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'تكلفة الوحدة')),
            TextField(controller: reorder, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'حد إعادة الطلب')),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ'))],
        ),
      ),
    );
    if (saved != true || !context.mounted || name.text.trim().isEmpty) return;
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
        title: Text('ربح ${_chairLabel(chair)} — ${DateFormat('yyyy/MM/dd').format(_weekStart)}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('الإيراد: ${fmtPrice(computed.revenue, context.read<ShopProvider>().settings?.currency ?? 'SAR')}  •  المواد: ${fmtPrice(computed.supplyCost, context.read<ShopProvider>().settings?.currency ?? 'SAR')}'),
          TextField(controller: profit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الربح المعتمد من قبلك (اختياري)')),
          TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات الأسبوع')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ التقرير'))],
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

  String _chairLabel(Chair chair) => chair.number.trim().isEmpty ? chair.name : 'كرسي ${chair.number} — ${chair.name}';

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
    final currency = context.watch<ShopProvider>().settings?.currency ?? 'SAR';
    final totalProfit = tools.chairs.fold<double>(0, (sum, chair) => sum + _computedReport(tools, chair).profit);
    final lowStock = tools.chairSupplies.where((supply) => supply.lowStock).length;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          Row(children: [
            Expanded(child: _MetricCard(label: 'الكراسي النشطة', value: '${tools.chairs.where((c) => c.active).length}', icon: Icons.event_seat_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _MetricCard(label: 'ربح الأسبوع', value: fmtPrice(totalProfit, currency), icon: Icons.trending_up_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _MetricCard(label: 'مواد منخفضة', value: '$lowStock', icon: Icons.inventory_2_outlined)),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(title: 'الكراسي والحلاقون', actionLabel: 'إضافة كرسي', onPressed: () => _showChairDialog(context)),
          if (tools.chairs.isEmpty)
            const Card(child: ListTile(title: Text('لم تتم إضافة كراسي بعد'), subtitle: Text('أضف رقم واسم كل كرسي واربطه بالحلاق المسؤول.')))
          else
            ...tools.chairs.map((chair) {
              final employee = chair.employeeId == null ? null : context.read<ShopProvider>().activeEmployees.where((e) => e.id == chair.employeeId).firstOrNull;
              return Card(child: ListTile(
                leading: CircleAvatar(child: Text(chair.number.isEmpty ? '—' : chair.number)),
                title: Text(_chairLabel(chair)),
                subtitle: Text('${employee == null ? 'غير مربوط بحلاق' : 'الحلاق: ${employee.name}'}  •  ${chair.active ? 'نشط' : 'متوقف'}'),
                trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'edit') _showChairDialog(context, existing: chair); if (value == 'delete') tools.deleteChair(chair.id); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))]),
              ));
            }),
          const SizedBox(height: 16),
          _SectionHeader(title: 'مستلزمات كل كرسي', actionLabel: 'إضافة مادة', onPressed: () => _showSupplyDialog(context)),
          if (tools.chairSupplies.isEmpty)
            const Card(child: ListTile(title: Text('لا توجد مواد مسجلة'), subtitle: Text('سجّل الشفرات والمناشف والمواد والمستلزمات مع تكلفة الوحدة.')))
          else
            ...tools.chairSupplies.map((supply) {
              final chair = tools.chairs.where((c) => c.id == supply.chairId).firstOrNull;
              return Card(child: ListTile(
                leading: Icon(supply.lowStock ? Icons.warning_amber_rounded : Icons.inventory_2_outlined, color: supply.lowStock ? Colors.orange : null),
                title: Text(supply.name),
                subtitle: Text('${chair == null ? 'كرسي غير معروف' : _chairLabel(chair)}  •  ${supply.quantity} ${supply.unit}  •  تكلفة الوحدة ${supply.unitCost}'),
                trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'delete') tools.deleteChairSupply(supply.id); }, itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف'))]),
              ));
            }),
          const SizedBox(height: 16),
          _SectionHeader(title: 'ربحية الكراسي — الأسبوع المحدد', actionLabel: '', onPressed: null),
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
              title: Text(_chairLabel(chair)),
              subtitle: Text('زيارات مكتملة: ${report.completedVisits}  •  إشغال تقريبي: ${report.utilizationPercent.toStringAsFixed(1)}%\nإيراد ${fmtPrice(report.revenue, currency)}  •  مواد ${fmtPrice(report.supplyCost, currency)}'),
              isThreeLine: true,
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmtPrice(report.profit, currency), style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(report.manualProfit == null ? 'محسوب' : 'معتمد يدويًا', style: TextStyle(fontSize: 11, color: report.manualProfit == null ? Colors.grey : Colors.green)),
                TextButton(onPressed: () => _showProfitDialog(context, chair, report), child: const Text('تعديل الربح')),
              ]),
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
