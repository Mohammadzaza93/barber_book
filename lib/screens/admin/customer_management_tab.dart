import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/business_features.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import 'customer_editor.dart';

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

  Future<void> _openEditor({CustomerProfile? existing}) async {
    await showCustomerEditor(context, existing: existing);
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final shop = context.watch<ShopProvider>();
    final threshold =
        tools.loyaltyRules.where((r) => r.enabled).firstOrNull?.inactiveAfterDays ??
            45;
    final query = _search.text.trim().toLowerCase();
    final customers = tools.customers.where((customer) {
      final matches = query.isEmpty ||
          customer.name.toLowerCase().contains(query) ||
          customer.phone.contains(query);
      return matches && (!_inactiveOnly || customer.isInactive(threshold));
    }).toList();
    final inactive =
        tools.customers.where((c) => c.isInactive(threshold)).length;
    final permanent = tools.customers.where((c) => c.isPermanent).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bt_customers_fab',
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(t(context).addCustomer),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: t(context).metricTotalCustomers,
                    value: '${tools.customers.length}',
                    icon: Icons.people_alt_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: t(context).metricLoyalCustomers,
                    value: '$permanent',
                    icon: Icons.verified_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: t(context).metricNeedFollowUp,
                    value: '$inactive',
                    icon: Icons.notifications_active_outlined,
                  ),
                ),
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
                          : shop.employeeById(customer.preferredEmployeeId!)?.name ??
                              '';
                      final status = customer.visitCount == 0
                          ? t(context).customerStatusFirstVisit
                          : customer.isPermanent
                              ? t(context).customerStatusLoyal
                              : customer.isReturning
                                  ? t(context).customerStatusReturning
                                  : t(context).customerStatusSingleVisit;
                      final extra = [
                        if (customer.area.isNotEmpty) 'المنطقة: ${customer.area}',
                        if (customer.allergies.isNotEmpty)
                          '⚠️ ${customer.allergies}',
                      ].join(' · ');
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(customer.name.isEmpty
                                ? '?'
                                : customer.name.characters.first),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  customer.name.isEmpty
                                      ? customer.phone
                                      : customer.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (inactiveCustomer)
                                const Icon(
                                  Icons.notifications_active_outlined,
                                  color: Colors.orange,
                                  size: 19,
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              [
                                t(context).customerSummary(
                                  customer.phone,
                                  status,
                                  '${customer.visitCount}',
                                  customer.lastVisitAt == null
                                      ? t(context).noneValue
                                      : DateFormat('yyyy/MM/dd')
                                          .format(customer.lastVisitAt!),
                                  customer.averageVisitIntervalDays <= 0
                                      ? t(context).unknown
                                      : t(context).daysCount(customer
                                          .averageVisitIntervalDays
                                          .toStringAsFixed(0)),
                                  customer.preferredTime.isEmpty
                                      ? t(context).notSet
                                      : customer.preferredTime,
                                  preferredServices.isEmpty
                                      ? t(context).notSpecified
                                      : preferredServices,
                                  preferredBarber.isEmpty
                                      ? t(context).notSet
                                      : preferredBarber,
                                ),
                                if (extra.isNotEmpty) extra,
                              ].join('\n'),
                            ),
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _openEditor(existing: customer);
                              }
                              if (value == 'delete') {
                                await tools.deleteCustomer(customer.id);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                  value: 'edit',
                                  child: Text(t(context).menuEditProfile)),
                              PopupMenuItem(
                                  value: 'delete',
                                  child: Text(t(context).menuDeleteProfile)),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
