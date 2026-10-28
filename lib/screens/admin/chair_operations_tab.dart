import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/business_features.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';

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
              TextFormField(
                controller: name,
                decoration: InputDecoration(labelText: t(context).chairNameField),
                validator: (v) => v == null || v.trim().isEmpty ? t(context).required : null,
              ),
              DropdownButtonFormField<String>(
                value: employeeId,
                isExpanded: true,
                decoration: InputDecoration(labelText: t(context).assignedBarberField),
                items: shop.activeEmployees
                    .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                    .toList(),
                onChanged: (value) => setState(() => employeeId = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(t(context).chairActive),
                value: active,
                onChanged: (value) => setState(() => active = value),
              ),
            ]),
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
    await tools.saveChair(Chair(
      id: existing?.id ?? tools.newId(),
      name: name.text.trim(),
      number: number.text.trim(),
      employeeId: employeeId,
      active: active,
    ));
  }

  String _chairLabel(BuildContext context, Chair chair) =>
      chair.number.trim().isEmpty
          ? chair.name
          : t(context).chairLabel(chair.number, chair.name);

  ChairWeeklyProfit _computedReport(BusinessToolsProvider tools, Chair chair) {
    final end = _weekStart.add(const Duration(days: 7));
    final appointments = tools.appointments
        .where((a) =>
            a.chairId == chair.id &&
            a.status == AppointmentStatus.completed &&
            !a.startTime.isBefore(_weekStart) &&
            a.startTime.isBefore(end))
        .toList();
    final payments = tools.payments
        .where((p) =>
            p.chairId == chair.id &&
            !p.paidAt.isBefore(_weekStart) &&
            p.paidAt.isBefore(end))
        .toList();
    final stored = tools.weeklyProfits
        .where((r) => r.id == '${_weekId()}_${chair.id}')
        .firstOrNull;
    final revenue =
        appointments.fold<double>(0, (s, a) => s + a.totalAmount);
    final supplyCost =
        payments.fold<double>(0, (s, p) => s + p.materialCost);
    final workingMinutes = appointments.fold<int>(
        0, (s, a) => s + a.endTime.difference(a.startTime).inMinutes);
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

  Future<void> _addQueue(BuildContext context) async {
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
                    InputDecoration(labelText: t(context).customerNameField),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration:
                    InputDecoration(labelText: t(context).phoneNumberField),
              ),
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
              child: Text(t(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t(context).save),
            ),
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
    await context.read<BusinessToolsProvider>().addQueue(
          QueueEntry(
            id: context.read<BusinessToolsProvider>().newId(),
            customerName: nameText,
            customerPhone: phoneText,
            employeeId: employeeId ?? '',
            joinedAt: DateTime.now(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final canManage = context.watch<AuthProvider>().canManageRules;
    final currency =
        context.watch<ShopProvider>().settings?.currency ?? 'SAR';
    final totalProfit = tools.chairs.fold<double>(
        0, (sum, chair) => sum + _computedReport(tools, chair).profit);
    final lowStock =
        tools.chairSupplies.where((s) => s.lowStock).length;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          Row(children: [
            Expanded(
              child: _Card(
                label: t(context).metricActiveChairs,
                value: '${tools.chairs.where((c) => c.active).length}',
                icon: Icons.event_seat_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Card(
                label: t(context).metricWeekProfit,
                value: fmtPrice(totalProfit, currency),
                icon: Icons.trending_up_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Card(
                label: t(context).metricLowStock,
                value: '$lowStock',
                icon: Icons.inventory_2_outlined,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  t(context).sectionChairsAndBarbers,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (canManage)
                TextButton.icon(
                  onPressed: () => _showChairDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(t(context).addChairAction),
                ),
            ],
          ),
          if (tools.chairs.isEmpty)
            Card(
              child: ListTile(
                title: Text(t(context).noChairsYet),
                subtitle: Text(t(context).noChairsSubtitle),
              ),
            )
          else
            ...tools.chairs.map((chair) {
              final employee = chair.employeeId == null
                  ? null
                  : context
                      .read<ShopProvider>()
                      .activeEmployees
                      .where((e) => e.id == chair.employeeId)
                      .firstOrNull;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(chair.number.isEmpty ? '—' : chair.number),
                  ),
                  title: Text(_chairLabel(context, chair)),
                  subtitle: Text(
                    '${employee == null ? t(context).chairUnassigned : t(context).chairAssignedBarber(employee.name)}  •  ${chair.active ? t(context).active : t(context).chairInactiveState}',
                  ),
                  trailing: canManage
                      ? PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showChairDialog(context, existing: chair);
                            }
                            if (value == 'delete') {
                              tools.deleteChair(chair.id);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                                value: 'edit', child: Text(t(context).edit)),
                            PopupMenuItem(
                                value: 'delete',
                                child: Text(t(context).delete)),
                          ],
                        )
                      : null,
                ),
              );
            }),
          const SizedBox(height: 16),
          Text(
            t(context).sectionChairProfit,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => setState(() =>
                        _weekStart = _weekStart.subtract(const Duration(days: 7))),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  Text(
                    '${DateFormat('yyyy/MM/dd').format(_weekStart)} — ${DateFormat('yyyy/MM/dd').format(_weekStart.add(const Duration(days: 6)))}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => setState(
                        () => _weekStart = _weekStart.add(const Duration(days: 7))),
                    icon: const Icon(Icons.chevron_left),
                  ),
                ],
              ),
            ),
          ),
          ...tools.chairs.map((chair) {
            final report = _computedReport(tools, chair);
            return Card(
              child: ListTile(
                leading: const Icon(Icons.bar_chart_outlined),
                title: Text(_chairLabel(context, chair)),
                subtitle: Text(
                  t(context).chairReportSummary(
                    '${report.completedVisits}',
                    report.utilizationPercent.toStringAsFixed(1),
                    fmtPrice(report.revenue, currency),
                    fmtPrice(report.supplyCost, currency),
                  ),
                ),
                isThreeLine: true,
                trailing: Text(
                  fmtPrice(report.profit, currency),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'الطابور',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (canManage)
                TextButton.icon(
                  onPressed: () => _addQueue(context),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(t(context).add),
                ),
            ],
          ),
          if (tools.queue.isEmpty)
            const Card(
              child: ListTile(
                title: Text('لا يوجد أحد في الطابور حالياً'),
                subtitle: Text('أضف زبوناً ينتظر عند فتح الكراسي'),
              ),
            )
          else
            ...tools.queue.map((entry) {
              return Card(
                child: ListTile(
                  title: Text(entry.customerName),
                  subtitle: Text(
                    '${entry.customerPhone}  •  ${DateFormat('HH:mm').format(entry.joinedAt)}  •  ${entry.status.name}',
                  ),
                  trailing: canManage
                      ? IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          tooltip: 'إنهاء',
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
            }),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
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
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 5),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
