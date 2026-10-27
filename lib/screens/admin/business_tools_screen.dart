import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/business_features.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import 'business_management_tabs.dart';
import 'inventory_tab.dart';

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
                    icon: const Icon(Icons.queue_outlined)),
                const Tab(
                    text: 'المخزون',
                    icon: Icon(Icons.inventory_2_outlined)),
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
                InventoryTab(),
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
                decoration:
                    InputDecoration(labelText: t(context).portfolioCategory)),
            TextField(
                controller: description,
                maxLines: 2,
                decoration:
                    InputDecoration(labelText: t(context).description)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t(context).cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t(context).save)),
        ],
      ),
    );
    final titleText = title.text.trim();
    final urlText = url.text.trim();
    final categoryText = category.text.trim();
    final descriptionText = description.text.trim();
    title.dispose();
    url.dispose();
    category.dispose();
    description.dispose();
    if (result != true || !context.mounted || titleText.isEmpty) return;
    await context.read<BusinessToolsProvider>().addPortfolio(PortfolioItem(
          id: context.read<BusinessToolsProvider>().newId(),
          title: titleText,
          imageUrl: urlText,
          category: categoryText.isEmpty ? 'general' : categoryText,
          description: descriptionText,
          createdAt: DateTime.now(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'portfolio_fab',
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(t(context).add),
      ),
      body: tools.portfolio.isEmpty
          ? Center(child: Text(t(context).portfolioEmpty))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: tools.portfolio.length,
              itemBuilder: (context, index) {
                final item = tools.portfolio[index];
                return Card(
                  child: ListTile(
                    leading: item.imageUrl.isEmpty
                        ? const Icon(Icons.image_not_supported_outlined)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.imageUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                    title: Text(item.title),
                    subtitle: Text(item.category),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => tools.deletePortfolio(item.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _QueueTab extends StatelessWidget {
  const _QueueTab();

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final shop = context.read<ShopProvider>();
    String? employeeId =
        shop.activeEmployees.isEmpty ? null : shop.activeEmployees.first.id;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(t(context).queueAddTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration:
                      InputDecoration(labelText: t(context).customerNameField)),
              TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      InputDecoration(labelText: t(context).phoneNumberField)),
              if (shop.activeEmployees.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: employeeId,
                  decoration:
                      InputDecoration(labelText: t(context).assignedBarberField),
                  items: shop.activeEmployees
                      .map((e) =>
                          DropdownMenuItem(value: e.id, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setState(() => employeeId = v),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t(context).cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(t(context).save)),
          ],
        ),
      ),
    );
    final nameText = name.text.trim();
    final phoneText = phone.text.trim();
    name.dispose();
    phone.dispose();
    if (result != true || !context.mounted || nameText.isEmpty) return;
    await context.read<BusinessToolsProvider>().addQueue(QueueEntry(
          id: context.read<BusinessToolsProvider>().newId(),
          customerName: nameText,
          customerPhone: phoneText,
          employeeId: employeeId ?? '',
          joinedAt: DateTime.now(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'queue_fab',
        onPressed: () => _add(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(t(context).add),
      ),
      body: tools.queue.isEmpty
          ? Center(child: Text(t(context).queueEmpty))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: tools.queue.length,
              itemBuilder: (context, index) {
                final entry = tools.queue[index];
                return Card(
                  child: ListTile(
                    title: Text(entry.customerName),
                    subtitle: Text(
                      '${entry.customerPhone}  •  ${DateFormat('HH:mm').format(entry.joinedAt)}  •  ${entry.status.name}',
                    ),
                    trailing: auth.canManageRules
                        ? IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () => tools.saveQueue(
                                  entry.copyWith(
                                    status: QueueStatus.completed,
                                    completedAt: DateTime.now(),
                                  ),
                                ),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
