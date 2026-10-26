import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/business_features.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import 'business_management_tabs.dart';

class BusinessToolsScreen extends StatelessWidget {
  const BusinessToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(
                    text: t(context).tabPortfolio,
                    icon: const Icon(Icons.photo_library_outlined)),
                Tab(
                    text: t(context).tabCustomers,
                    icon: const Icon(Icons.people_alt_outlined)),
                Tab(
                    text: t(context).tabLoyalty,
                    icon: const Icon(Icons.stars_outlined)),
                Tab(
                    text: t(context).tabChairs,
                    icon: const Icon(Icons.event_seat_outlined)),
                Tab(
                    text: t(context).tabQueue,
                    icon: const Icon(Icons.people_alt_outlined)),
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
            TextField(
                controller: title,
                decoration:
                    InputDecoration(labelText: t(context).portfolioItemTitle)),
            TextField(
                controller: url,
                decoration:
                    InputDecoration(labelText: t(context).portfolioImageUrl)),
            TextField(
                controller: category,
                decoration: InputDecoration(labelText: t(context).category)),
            TextField(
                controller: description,
                decoration:
                    InputDecoration(labelText: t(context).description)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t(context).cancel)),
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
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: .78),
              itemCount: tools.portfolio.length,
              itemBuilder: (_, index) {
                final item = tools.portfolio[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Image.network(item.imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      size: 40))),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                          child: Row(children: [
                            Expanded(
                                child: Text(item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700))),
                            if (canManage)
                              IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      tools.deletePortfolio(item.id)),
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
      builder: (_) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
                title: Text(t(context).queueAddTitle),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      decoration: InputDecoration(
                          labelText: t(context).customerNameField)),
                  TextField(
                      controller: phone,
                      decoration:
                          InputDecoration(labelText: t(context).phone)),
                  DropdownButtonFormField<String>(
                    value: employeeId,
                    decoration:
                        InputDecoration(labelText: t(context).employee),
                    items: shop.activeEmployees
                        .map((e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.name)))
                        .toList(),
                    onChanged: (v) => setState(() => employeeId = v),
                  ),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t(context).cancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(t(context).add)),
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
    final waiting =
        tools.queue.where((e) => e.status == QueueStatus.waiting).length;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
          heroTag: 'bt_queue_fab',
          onPressed: () => _addQueue(context),
          icon: const Icon(Icons.person_add),
          label: Text(t(context).queueAddFab('$waiting'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: tools.queue.map((entry) {
          final employee =
              staff.where((e) => e.id == entry.employeeId).firstOrNull;
          final next = entry.status == QueueStatus.waiting
              ? QueueStatus.inService
              : QueueStatus.completed;
          return Card(
            child: ListTile(
              leading:
                  CircleAvatar(child: Text('${tools.queue.indexOf(entry) + 1}')),
              title: Text(entry.customerName),
              subtitle: Text(
                  '${employee?.name ?? t(context).unassigned} · ${entry.status.name} · ${DateFormat('HH:mm').format(entry.joinedAt)}'),
              trailing: IconButton(
                  icon: Icon(next == QueueStatus.inService
                      ? Icons.play_arrow
                      : Icons.check),
                  onPressed: () => tools.saveQueue(entry.copyWith(
                        status: next,
                        startedAt: next == QueueStatus.inService
                            ? DateTime.now()
                            : entry.startedAt,
                        completedAt: next == QueueStatus.completed
                            ? DateTime.now()
                            : entry.completedAt,
                      ))),
            ),
          );
        }).toList(),
      ),
    );
  }
}
