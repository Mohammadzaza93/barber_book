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
      length: 4,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabs: [
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
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
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
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: t(context).assignedBarberField),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      phone.dispose();
    });
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
          ? const Center(child: Text('لا يوجد أحد في الطابور حالياً'))
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
