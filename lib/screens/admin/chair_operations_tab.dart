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

  QueueEntry? _activeOnChair(BusinessToolsProvider tools, String chairId) {
    for (final e in tools.queue) {
      if (e.chairId == chairId && e.status == QueueStatus.inService) return e;
    }
    return null;
  }

  ChairFloorKind _floorKind(Chair chair, QueueEntry? active) {
    if (!chair.active) return ChairFloorKind.idle;
    if (chair.onBreak) return ChairFloorKind.onBreak;
    if (active != null) return ChairFloorKind.busy;
    return ChairFloorKind.idle;
  }

  String _statusLabel(ChairFloorKind kind) {
    switch (kind) {
      case ChairFloorKind.idle:
        return 'فارغ';
      case ChairFloorKind.busy:
        return 'مشغول';
      case ChairFloorKind.onBreak:
        return 'استراحة';
    }
  }

  Color _statusColor(BuildContext context, ChairFloorKind kind) {
    switch (kind) {
      case ChairFloorKind.idle:
        return Colors.green.shade700;
      case ChairFloorKind.busy:
        return Theme.of(context).colorScheme.error;
      case ChairFloorKind.onBreak:
        return Colors.orange.shade800;
    }
  }

  String _durationLabel(DateTime? from) {
    if (from == null) return '';
    final m = DateTime.now().difference(from).inMinutes;
    if (m < 1) return 'الآن';
    if (m < 60) return '$m د';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '$h س' : '$h س $r د';
  }

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
    final nameText = name.text.trim();
    final numberText = number.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      number.dispose();
    });
    if (saved != true || !context.mounted) return;
    final tools = context.read<BusinessToolsProvider>();
    await tools.saveChair(Chair(
      id: existing?.id ?? tools.newId(),
      name: nameText,
      number: numberText,
      employeeId: employeeId,
      active: active,
      onBreak: existing?.onBreak ?? false,
      breakStartedAt: existing?.breakStartedAt,
    ));
  }

  Future<void> _toggleBreak(Chair chair) async {
    final tools = context.read<BusinessToolsProvider>();
    final next = !chair.onBreak;
    await tools.saveChair(chair.copyWith(
      onBreak: next,
      breakStartedAt: next ? DateTime.now() : null,
      clearBreakStartedAt: !next,
    ));
  }

  Future<void> _startServiceFromQueue(QueueEntry entry) async {
    final tools = context.read<BusinessToolsProvider>();
    final shop = context.read<ShopProvider>();
    final freeChairs = tools.chairs.where((c) {
      if (!c.active || c.onBreak) return false;
      return _activeOnChair(tools, c.id) == null;
    }).toList();
    if (freeChairs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد كرسي فارغ حالياً')),
      );
      return;
    }
    String? chairId = freeChairs.first.id;
    String? employeeId = entry.employeeId.isNotEmpty
        ? entry.employeeId
        : freeChairs.first.employeeId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('بدء الخدمة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(entry.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (entry.customerPhone.isNotEmpty) Text(entry.customerPhone),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: chairId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الكرسي', border: OutlineInputBorder()),
                items: freeChairs
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.number.trim().isEmpty ? c.name : '${c.number} — ${c.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setLocal(() {
                  chairId = v;
                  final ch = tools.chairs.where((c) => c.id == v).firstOrNull;
                  if (ch?.employeeId != null) employeeId = ch!.employeeId;
                }),
              ),
              const SizedBox(height: 10),
              if (shop.activeEmployees.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: shop.activeEmployees.any((e) => e.id == employeeId)
                      ? employeeId
                      : shop.activeEmployees.first.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: t(context).assignedBarberField,
                    border: const OutlineInputBorder(),
                  ),
                  items: shop.activeEmployees
                      .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setLocal(() => employeeId = v),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t(context).cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('بدء')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted || chairId == null) return;
    await tools.saveQueue(entry.copyWith(
      chairId: chairId,
      employeeId: employeeId ?? entry.employeeId,
      status: QueueStatus.inService,
      startedAt: DateTime.now(),
    ));
  }

  Future<void> _finishService(QueueEntry entry) async {
    await context.read<BusinessToolsProvider>().saveQueue(
          entry.copyWith(status: QueueStatus.completed, completedAt: DateTime.now()),
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
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: InputDecoration(labelText: t(context).customerNameField)),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: t(context).phoneNumberField),
            ),
            if (shop.activeEmployees.isNotEmpty)
              DropdownButtonFormField<String>(
                value: employeeId,
                isExpanded: true,
                decoration: InputDecoration(labelText: t(context).assignedBarberField),
                items: shop.activeEmployees
                    .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                    .toList(),
                onChanged: (v) => setState(() => employeeId = v),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t(context).cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t(context).save)),
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

  String _chairLabel(BuildContext context, Chair chair) =>
      chair.number.trim().isEmpty ? chair.name : t(context).chairLabel(chair.number, chair.name);

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
    final stored =
        tools.weeklyProfits.where((r) => r.id == '${_weekId()}_${chair.id}').firstOrNull;
    final revenue = appointments.fold<double>(0, (s, a) => s + a.totalAmount);
    final supplyCost = payments.fold<double>(0, (s, p) => s + p.materialCost);
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

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final canManage = context.watch<AuthProvider>().canManageRules;
    final shop = context.watch<ShopProvider>();
    final currency = shop.settings?.currency ?? 'SAR';
    final totalProfit =
        tools.chairs.fold<double>(0, (sum, chair) => sum + _computedReport(tools, chair).profit);
    final busyCount = tools.chairs.where((c) {
      if (!c.active || c.onBreak) return false;
      return _activeOnChair(tools, c.id) != null;
    }).length;
    final freeCount = tools.chairs.where((c) {
      if (!c.active || c.onBreak) return false;
      return _activeOnChair(tools, c.id) == null;
    }).length;
    final waiting = tools.queue.where((e) => e.status == QueueStatus.waiting).toList();
    final inService = tools.queue.where((e) => e.status == QueueStatus.inService).toList();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          Row(children: [
            Expanded(
              child: _Card(
                label: 'فارغ',
                value: '$freeCount',
                icon: Icons.event_seat_outlined,
                accent: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Card(
                label: 'مشغول',
                value: '$busyCount',
                icon: Icons.content_cut,
                accent: Theme.of(context).colorScheme.error,
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
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Text(
                t(context).sectionChairsAndBarbers,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            if (canManage)
              TextButton.icon(
                onPressed: () => _showChairDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(t(context).addChairAction),
              ),
          ]),
          if (tools.chairs.isEmpty)
            Card(
              child: ListTile(
                title: Text(t(context).noChairsYet),
                subtitle: Text(t(context).noChairsSubtitle),
              ),
            )
          else
            ...tools.chairs.map((chair) {
              final active = _activeOnChair(tools, chair.id);
              final kind = _floorKind(chair, active);
              final employee = chair.employeeId == null
                  ? null
                  : shop.activeEmployees.where((e) => e.id == chair.employeeId).firstOrNull;
              final barberOnService = active == null || active.employeeId.isEmpty
                  ? null
                  : shop.activeEmployees.where((e) => e.id == active.employeeId).firstOrNull;
              final statusColor = _statusColor(context, kind);
              final sessionFrom =
                  kind == ChairFloorKind.onBreak ? chair.breakStartedAt : active?.startedAt;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        CircleAvatar(
                          backgroundColor: statusColor.withValues(alpha: 0.15),
                          foregroundColor: statusColor,
                          child: Text(
                            chair.number.isEmpty ? '—' : chair.number,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_chairLabel(context, chair),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              Text(
                                employee == null
                                    ? t(context).chairUnassigned
                                    : t(context).chairAssignedBarber(employee.name),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(kind),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (canManage)
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _showChairDialog(context, existing: chair);
                              } else if (value == 'break') {
                                await _toggleBreak(chair);
                              } else if (value == 'delete') {
                                await tools.deleteChair(chair.id);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: Text(t(context).edit)),
                              PopupMenuItem(
                                value: 'break',
                                child: Text(chair.onBreak ? 'إنهاء الاستراحة' : 'استراحة'),
                              ),
                              PopupMenuItem(value: 'delete', child: Text(t(context).delete)),
                            ],
                          ),
                      ]),
                      if (kind == ChairFloorKind.busy && active != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(children: [
                            const Icon(Icons.person_outline, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                [
                                  active.customerName,
                                  if (barberOnService != null) barberOnService.name,
                                  if (sessionFrom != null) _durationLabel(sessionFrom),
                                ].join('  •  '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (canManage)
                              TextButton(
                                onPressed: () => _finishService(active),
                                child: const Text('إنهاء'),
                              ),
                          ]),
                        ),
                      ],
                      if (kind == ChairFloorKind.onBreak) ...[
                        const SizedBox(height: 6),
                        Text(
                          'استراحة منذ ${_durationLabel(chair.breakStartedAt)}',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          Text(t(context).sectionChairProfit,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => setState(
                        () => _weekStart = _weekStart.subtract(const Duration(days: 7))),
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
                trailing: Text(fmtPrice(report.profit, currency),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            );
          }),
          const SizedBox(height: 20),
          Row(children: [
            const Expanded(
              child: Text('الطابور', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            if (canManage)
              TextButton.icon(
                onPressed: () => _addQueue(context),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: Text(t(context).add),
              ),
          ]),
          if (waiting.isEmpty && inService.isEmpty)
            const Card(
              child: ListTile(
                title: Text('لا يوجد أحد في الطابور حالياً'),
                subtitle: Text('أضف زبوناً ينتظر، ثم ابدأ الخدمة على كرسي فارغ'),
              ),
            )
          else ...[
            if (waiting.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 6),
                child: Text('بانتظار الخدمة', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              ...waiting.map((entry) => Card(
                    child: ListTile(
                      title: Text(entry.customerName),
                      subtitle: Text(
                          '${entry.customerPhone}  •  ${DateFormat('HH:mm').format(entry.joinedAt)}'),
                      trailing: canManage
                          ? FilledButton.tonal(
                              onPressed: () => _startServiceFromQueue(entry),
                              child: const Text('بدء'),
                            )
                          : null,
                    ),
                  )),
            ],
            if (inService.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 6),
                child: Text('قيد الخدمة', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              ...inService.map((entry) {
                final chair =
                    tools.chairs.where((c) => c.id == entry.chairId).firstOrNull;
                return Card(
                  child: ListTile(
                    title: Text(entry.customerName),
                    subtitle: Text(
                      [
                        if (chair != null) _chairLabel(context, chair),
                        DateFormat('HH:mm').format(entry.startedAt ?? entry.joinedAt),
                        _durationLabel(entry.startedAt),
                      ].where((s) => s.isNotEmpty).join('  •  '),
                    ),
                    trailing: canManage
                        ? IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            tooltip: 'إنهاء',
                            onPressed: () => _finishService(entry),
                          )
                        : null,
                  ),
                );
              }),
            ],
          ],
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
    this.accent,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
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
