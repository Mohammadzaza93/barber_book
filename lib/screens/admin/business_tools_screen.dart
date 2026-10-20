import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/business_features.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/secure_api.dart';
import '../../services/secure_error_text.dart';
import '../../widgets/confirm.dart';
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
                Tab(text: t(context).tabPortfolio, icon: const Icon(Icons.photo_library_outlined)),
                Tab(text: t(context).tabCustomers, icon: const Icon(Icons.people_alt_outlined)),
                Tab(text: t(context).tabLoyalty, icon: const Icon(Icons.stars_outlined)),
                Tab(text: t(context).tabChairs, icon: const Icon(Icons.event_seat_outlined)),
                Tab(text: t(context).tabQueue, icon: const Icon(Icons.people_alt_outlined)),
                Tab(text: t(context).tabPayments, icon: const Icon(Icons.account_balance_wallet_outlined)),
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
        title: Text(t(context).portfolioAddTitle),
        content: SingleChildScrollView(
          child: Column(children: [
            TextField(controller: title, decoration: InputDecoration(labelText: t(context).portfolioItemTitle)),
            TextField(controller: url, decoration: InputDecoration(labelText: t(context).portfolioImageUrl)),
            TextField(controller: category, decoration: InputDecoration(labelText: t(context).category)),
            TextField(controller: description, decoration: InputDecoration(labelText: t(context).description)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t(context).cancel)),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty || url.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: Text(t(context).save),
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
    // The portfolio collection is owner-only; managers keep read-only access.
    final canManage = context.watch<AuthProvider>().canManageRules;
    return Scaffold(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'bt_portfolio_fab',
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(t(context).addPhoto),
            )
          : null,
      body: tools.portfolio.isEmpty
          ? Center(child: Text(t(context).portfolioEmpty))
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
                        if (canManage)
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
        title: Text(t(context).queueAddTitle),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: InputDecoration(labelText: t(context).customerNameField)),
          TextField(controller: phone, decoration: InputDecoration(labelText: t(context).phone)),
          DropdownButtonFormField<String>(
            value: employeeId,
            decoration: InputDecoration(labelText: t(context).employee),
            items: shop.activeEmployees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
            onChanged: (v) => setState(() => employeeId = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t(context).cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t(context).add)),
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
      floatingActionButton: FloatingActionButton.extended(heroTag: 'bt_queue_fab', onPressed: () => _addQueue(context), icon: const Icon(Icons.person_add), label: Text(t(context).queueAddFab('$waiting'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: tools.queue.map((entry) {
          final employee = staff.where((e) => e.id == entry.employeeId).firstOrNull;
          final next = entry.status == QueueStatus.waiting ? QueueStatus.inService : QueueStatus.completed;
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${tools.queue.indexOf(entry) + 1}')),
              title: Text(entry.customerName),
              subtitle: Text('${employee?.name ?? t(context).unassigned} · ${entry.status.name} · ${DateFormat('HH:mm').format(entry.joinedAt)}'),
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
        title: Text(t(context).paymentDialogTitle),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: customer, decoration: InputDecoration(labelText: t(context).customerNameField)),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: t(context).customerPhoneField)),
          TextField(controller: appointment, decoration: InputDecoration(labelText: t(context).appointmentRefField)),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t(context).amountCollected)),
          TextField(controller: materialCost, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t(context).materialCostField)),
          if (tools.chairs.isNotEmpty)
            DropdownButtonFormField<String>(value: chairId, decoration: InputDecoration(labelText: t(context).chairField), items: tools.chairs.where((chair) => chair.active).map((chair) => DropdownMenuItem(value: chair.id, child: Text(chair.number.isEmpty ? chair.name : t(context).chairLabel(chair.number, chair.name)))).toList(), onChanged: (value) => setState(() => chairId = value)),
          DropdownButtonFormField<String>(value: employeeId, decoration: InputDecoration(labelText: t(context).employee), items: shop.activeEmployees.map((employee) => DropdownMenuItem(value: employee.id, child: Text(employee.name))).toList(), onChanged: (value) => setState(() => employeeId = value)),
          DropdownButtonFormField<String>(value: method, items: [
            DropdownMenuItem(value: 'cash', child: Text(t(context).payCash)),
            DropdownMenuItem(value: 'card', child: Text(t(context).payCard)),
            DropdownMenuItem(value: 'transfer', child: Text(t(context).payTransfer)),
            ], onChanged: (v) => setState(() => method = v ?? 'cash')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t(context).cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t(context).save)),
        ],
      )),
    );
    if (ok != true || !context.mounted) return;
    final value = double.tryParse(amount.text);
    if (value == null || value <= 0) return;
    final cost = double.tryParse(materialCost.text) ?? 0;
    try {
      await tools.addPayment(Payment(id: tools.newId(), appointmentId: appointment.text.trim(), customerName: customer.text.trim(), customerPhone: phone.text.trim(), chairId: chairId, employeeId: employeeId, amount: value, materialCost: cost, method: method, paidAt: DateTime.now()));
    } on SecureApiException catch (error) {
      // The server owns the money path, so a rejection (e.g. the referenced
      // appointment does not exist) has to be surfaced instead of escaping as
      // an unhandled async exception.
      debugPrint('recordPayment rejected: code=${error.code} details=${error.details}');
      if (context.mounted) showSnack(context, describeSecureError(context, error));
    } catch (error) {
      debugPrint('recordPayment unexpected failure: $error');
      if (context.mounted) showSnack(context, t(context).error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final total = tools.payments.fold<double>(0, (sum, p) => sum + p.amount);
    final materialTotal = tools.payments.fold<double>(0, (sum, p) => sum + p.materialCost);
    final currency = context.watch<ShopProvider>().settings?.currency ?? 'SAR';
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(heroTag: 'bt_payments_fab', onPressed: () => _addPayment(context), icon: const Icon(Icons.add_card), label: Text(t(context).recordPayment)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            Expanded(child: Card(child: ListTile(leading: const Icon(Icons.account_balance_wallet), title: Text(t(context).salesCard), subtitle: Text(fmtPrice(total, currency)),))),
            Expanded(child: Card(child: ListTile(leading: const Icon(Icons.inventory_2_outlined), title: Text(t(context).materialsCard), subtitle: Text(fmtPrice(materialTotal, currency)),))),
            Expanded(child: Card(child: ListTile(leading: const Icon(Icons.trending_up), title: Text(t(context).netCard), subtitle: Text(fmtPrice(total - materialTotal, currency)),))),
          ]),
          Card(child: ListTile(leading: const Icon(Icons.local_offer_outlined), title: Text(t(context).promoServicesTitle), subtitle: Text(t(context).promoServicesSubtitle), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscountsScreen())))),
          const SizedBox(height: 8),
          ...tools.payments.map(
            (payment) => Card(
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text(
                  payment.customerName.isEmpty ? t(context).anonymousCustomer : payment.customerName,
                ),
                subtitle: Text(
                  '${payment.method} · ${DateFormat('yyyy/MM/dd HH:mm').format(payment.paidAt)} · ${t(context).netShort} ${fmtPrice(payment.profit, currency)}',
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
