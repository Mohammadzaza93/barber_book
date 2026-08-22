import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/business_features.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import '../../widgets/feature_labels.dart';
import 'discounts_screen.dart';
import 'business_management_tabs.dart';

class BusinessToolsScreen extends StatelessWidget {
  const BusinessToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: FeatureLabels.text(context, 'الأعمال', 'Portfolio'), icon: const Icon(Icons.photo_library_outlined)),
                Tab(text: 'العملاء', icon: const Icon(Icons.people_alt_outlined)),
                Tab(text: FeatureLabels.text(context, 'الولاء', 'Loyalty'), icon: const Icon(Icons.stars_outlined)),
                Tab(text: FeatureLabels.text(context, 'الكراسي', 'Chairs'), icon: const Icon(Icons.event_seat_outlined)),
                Tab(text: FeatureLabels.text(context, 'الطابور', 'Queue'), icon: const Icon(Icons.people_alt_outlined)),
                Tab(text: FeatureLabels.text(context, 'المدفوعات', 'Payments'), icon: const Icon(Icons.account_balance_wallet_outlined)),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _PortfolioTab(),
                CustomerManagementTab(),
                LoyaltyProgramTab(),
                ChairOperationsTab(),
                _QueueTab(),
                _PaymentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioTab extends StatelessWidget {
  const _PortfolioTab();

  Future<void> _add(BuildContext context) async {
    final title = TextEditingController();
    final url = TextEditingController();
    final category = TextEditingController(text: 'haircut');
    final description = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة عمل إلى المعرض'),
        content: SingleChildScrollView(
          child: Column(children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
            TextField(controller: url, decoration: const InputDecoration(labelText: 'رابط الصورة')),
            TextField(controller: category, decoration: const InputDecoration(labelText: 'الفئة')),
            TextField(controller: description, decoration: const InputDecoration(labelText: 'الوصف')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty || url.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result != true || !context.mounted) return;
    final tools = context.read<BusinessToolsProvider>();
    await tools.addPortfolio(PortfolioItem(
      id: tools.newId(),
      title: title.text.trim(),
      imageUrl: url.text.trim(),
      category: category.text.trim(),
      description: description.text.trim(),
      createdAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('إضافة صورة'),
      ),
      body: tools.portfolio.isEmpty
          ? const Center(child: Text('أضف صور قصات الشعر وتسريحات اللحية لعرض مستوى الصالون.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .78),
              itemCount: tools.portfolio.length,
              itemBuilder: (_, index) {
                final item = tools.portfolio[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Image.network(item.imageUrl, width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 40))),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                      child: Row(children: [
                        Expanded(child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => tools.deletePortfolio(item.id)),
                      ]),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}

class _LoyaltyTab extends StatelessWidget {
  const _LoyaltyTab();

  Future<void> _addAccount(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final points = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة عميل إلى برنامج الولاء'),
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
    if (ok != true || !context.mounted) return;
    final tools = context.read<BusinessToolsProvider>();
    final account = LoyaltyAccount(
      id: phone.text.trim().isEmpty ? tools.newId() : phone.text.trim(),
      customerName: name.text.trim(),
      customerPhone: phone.text.trim(),
      points: int.tryParse(points.text) ?? 0,
      updatedAt: DateTime.now(),
    );
    await tools.saveLoyalty(account.copyWith(tier: account.calculatedTier));
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _addAccount(context), icon: const Icon(Icons.person_add_alt_1), label: const Text('إضافة عميل')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: tools.loyalty.length,
        itemBuilder: (_, index) {
          final account = tools.loyalty[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${account.points}')),
              title: Text(account.customerName.isEmpty ? account.customerPhone : account.customerName),
              subtitle: Text('${account.customerPhone} · ${account.tier}'),
              trailing: IconButton(
                tooltip: 'إضافة نقاط',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => tools.addPoints(account.id, 10),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChairsTab extends StatelessWidget {
  const _ChairsTab();

  Future<void> _addChair(BuildContext context) async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة كرسي'),
        content: TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الكرسي')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true || !context.mounted || name.text.trim().isEmpty) return;
    final tools = context.read<BusinessToolsProvider>();
    await tools.saveChair(Chair(id: tools.newId(), name: name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final staff = context.watch<ShopProvider>().activeEmployees;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _addChair(context), icon: const Icon(Icons.add), label: const Text('إضافة كرسي')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: tools.chairs.map((chair) {
          final employee = chair.employeeId == null ? null : staff.where((e) => e.id == chair.employeeId).firstOrNull;
          return Card(
            child: ListTile(
              leading: const Icon(Icons.event_seat_rounded),
              title: Text(chair.name),
              subtitle: Text(employee == null ? 'غير مربوط بحلاق' : 'الحلاق: ${employee.name}'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => tools.deleteChair(chair.id)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QueueTab extends StatelessWidget {
  const _QueueTab();

  Future<void> _addQueue(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final shop = context.read<ShopProvider>();
    String? employeeId = shop.activeEmployees.firstOrNull?.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: const Text('إضافة عميل إلى الطابور'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم العميل')),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف')),
          DropdownButtonFormField<String>(
            value: employeeId,
            decoration: const InputDecoration(labelText: 'الحلاق'),
            items: shop.activeEmployees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
            onChanged: (v) => setState(() => employeeId = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة')),
        ],
      )),
    );
    if (ok != true || !context.mounted || employeeId == null) return;
    final tools = context.read<BusinessToolsProvider>();
    await tools.addQueue(QueueEntry(
      id: tools.newId(),
      customerName: name.text.trim(),
      customerPhone: phone.text.trim(),
      employeeId: employeeId!,
      joinedAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final staff = context.watch<ShopProvider>().activeEmployees;
    final waiting = tools.queue.where((e) => e.status == QueueStatus.waiting).length;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _addQueue(context), icon: const Icon(Icons.person_add), label: Text('إضافة إلى الطابور ($waiting)')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: tools.queue.map((entry) {
          final employee = staff.where((e) => e.id == entry.employeeId).firstOrNull;
          final next = entry.status == QueueStatus.waiting ? QueueStatus.inService : QueueStatus.completed;
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${tools.queue.indexOf(entry) + 1}')),
              title: Text(entry.customerName),
              subtitle: Text('${employee?.name ?? 'غير محدد'} · ${entry.status.name} · ${DateFormat('HH:mm').format(entry.joinedAt)}'),
              trailing: IconButton(icon: Icon(next == QueueStatus.inService ? Icons.play_arrow : Icons.check), onPressed: () => tools.saveQueue(entry.copyWith(status: next, startedAt: next == QueueStatus.inService ? DateTime.now() : entry.startedAt, completedAt: next == QueueStatus.completed ? DateTime.now() : entry.completedAt))),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab();

  Future<void> _addPayment(BuildContext context) async {
    final customer = TextEditingController();
    final phone = TextEditingController();
    final amount = TextEditingController();
    final materialCost = TextEditingController(text: '0');
    final appointment = TextEditingController();
    final tools = context.read<BusinessToolsProvider>();
    final shop = context.read<ShopProvider>();
    String? chairId = tools.chairs.where((chair) => chair.active).firstOrNull?.id;
    String? employeeId;
    String method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: const Text('تسجيل دفعة ومبيعات الكرسي'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: customer, decoration: const InputDecoration(labelText: 'اسم العميل')),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'هاتف العميل')),
          TextField(controller: appointment, decoration: const InputDecoration(labelText: 'رقم الموعد')),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المحصل')),
          TextField(controller: materialCost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تكلفة المواد المستخدمة')),
          if (tools.chairs.isNotEmpty)
            DropdownButtonFormField<String>(value: chairId, decoration: const InputDecoration(labelText: 'كرسي الحلاقة'), items: tools.chairs.where((chair) => chair.active).map((chair) => DropdownMenuItem(value: chair.id, child: Text(chair.number.isEmpty ? chair.name : 'كرسي ${chair.number} — ${chair.name}'))).toList(), onChanged: (value) => setState(() => chairId = value)),
          DropdownButtonFormField<String>(value: employeeId, decoration: const InputDecoration(labelText: 'الحلاق'), items: shop.activeEmployees.map((employee) => DropdownMenuItem(value: employee.id, child: Text(employee.name))).toList(), onChanged: (value) => setState(() => employeeId = value)),
          DropdownButtonFormField<String>(value: method, items: const [
            DropdownMenuItem(value: 'cash', child: Text('نقدي')),
            DropdownMenuItem(value: 'card', child: Text('بطاقة')),
            DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
            ], onChanged: (v) => setState(() => method = v ?? 'cash')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      )),
    );
    if (ok != true || !context.mounted) return;
    final value = double.tryParse(amount.text);
    if (value == null || value <= 0) return;
    final cost = double.tryParse(materialCost.text) ?? 0;
    await tools.addPayment(Payment(id: tools.newId(), appointmentId: appointment.text.trim(), customerName: customer.text.trim(), customerPhone: phone.text.trim(), chairId: chairId, employeeId: employeeId, amount: value, materialCost: cost, method: method, paidAt: DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final total = tools.payments.fold<double>(0, (sum, p) => sum + p.amount);
    final materialTotal = tools.payments.fold<double>(0, (sum, p) => sum + p.materialCost);
    final currency = context.watch<ShopProvider>().settings?.currency ?? 'SAR';
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _addPayment(context), icon: const Icon(Icons.add_card), label: const Text('تسجيل دفعة')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            Expanded(child: Card(child: ListTile(leading: const Icon(Icons.account_balance_wallet), title: const Text('المبيعات'), subtitle: Text(fmtPrice(total, currency)),))),
            Expanded(child: Card(child: ListTile(leading: const Icon(Icons.inventory_2_outlined), title: const Text('المواد'), subtitle: Text(fmtPrice(materialTotal, currency)),))),
            Expanded(child: Card(child: ListTile(leading: const Icon(Icons.trending_up), title: const Text('الصافي'), subtitle: Text(fmtPrice(total - materialTotal, currency)),))),
          ]),
          Card(child: ListTile(leading: const Icon(Icons.local_offer_outlined), title: const Text('الترويج للخدمات'), subtitle: const Text('أنشئ عروضًا وأكواد خصم وشاركها مع العملاء.'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscountsScreen())))),
          const SizedBox(height: 8),
          ...tools.payments.map(
            (payment) => Card(
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text(
                  payment.customerName.isEmpty ? 'عميل' : payment.customerName,
                ),
                subtitle: Text(
                  '${payment.method} · ${DateFormat('yyyy/MM/dd HH:mm').format(payment.paidAt)} · صافي ${fmtPrice(payment.profit, currency)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fmtPrice(payment.amount, currency),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => tools.deletePayment(payment.id),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
