import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/business_features.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_tools_provider.dart';
import '../../services/ops_helpers.dart';
import '../../providers/shop_provider.dart';
import 'queue_finish_payment.dart';
import '../../widgets/confirm_dialogs.dart';

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

  Future<void> _bumpPriority(QueueEntry entry, int delta) async {
    final tools = context.read<BusinessToolsProvider>();
    final next = (entry.priority + delta).clamp(0, 99);
    if (next == entry.priority) return;
    await tools.saveQueue(entry.copyWith(priority: next));
  }

  Future<void> _returnToWait(QueueEntry entry) async {
    final tools = context.read<BusinessToolsProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إرجاع للانتظار؟'),
        content: Text(
          'سيُعاد «${entry.customerName}» إلى الطابور ويُحرَّر الكرسي.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إرجاع')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await tools.saveQueue(entry.copyWith(
      status: QueueStatus.waiting,
      clearChairId: true,
      clearStartedAt: true,
    ));
  }

  bool _isOvertime(QueueEntry entry, List<QueueEntry> queue) {
    if (entry.startedAt == null) return false;
    final avg = OpsHelpers.avgServiceMinutes(queue);
    final limit = (avg * 1.6).round().clamp(30, 90);
    return DateTime.now().difference(entry.startedAt!).inMinutes >= limit;
  }

  Future<void> _finishService(QueueEntry entry) async {
    await QueueFinishPayment.show(context, entry);
  }

  Future<void> _addQueue(BuildContext context) async {
    final tools = context.read<BusinessToolsProvider>();
    final shop = context.read<ShopProvider>();
    final customers = [...tools.customers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (customers.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد عملاء بعد. أضف عميلاً من تبويب العملاء أولاً'),
        ),
      );
      return;
    }

    String? selectedCustomerId = customers.first.id;
    String? employeeId = customers.first.preferredEmployeeId;
    if (employeeId == null ||
        !shop.activeEmployees.any((e) => e.id == employeeId)) {
      employeeId =
          shop.activeEmployees.isEmpty ? null : shop.activeEmployees.first.id;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          final selected =
              customers.where((c) => c.id == selectedCustomerId).firstOrNull;
          return AlertDialog(
            title: Text(t(context).queueAddTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCustomerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'اختر الزبون',
                      border: OutlineInputBorder(),
                    ),
                    items: customers
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.phone.trim().isEmpty
                                  ? c.name
                                  : '${c.name} — ${c.phone}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() {
                        selectedCustomerId = v;
                        final c = customers.where((x) => x.id == v).firstOrNull;
                        final pref = c?.preferredEmployeeId;
                        if (pref != null &&
                            shop.activeEmployees.any((e) => e.id == pref)) {
                          employeeId = pref;
                        }
                      });
                    },
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(selected.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (selected.phone.isNotEmpty) selected.phone,
                              if (selected.visitCount > 0)
                                '${selected.visitCount} زيارة',
                              if (selected.isReturning) 'عميل متكرر',
                            ].join('  •  '),
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (selected.notes.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('ملاحظة: ${selected.notes}',
                                style: const TextStyle(fontSize: 12)),
                          ],
                          if (selected.allergies.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('حساسية: ${selected.allergies}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade800)),
                          ],
                          Builder(builder: (ctx) {
                            final prefs = selected.preferredServiceIds;
                            if (prefs.isEmpty) return const SizedBox.shrink();
                            final names = prefs
                                .map((id) => shop.services
                                    .where((s) => s.id == id)
                                    .map((s) => s.name)
                                    .firstOrNull)
                                .whereType<String>()
                                .toList();
                            if (names.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'خدمات مفضلة: ${names.join('، ')}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                  if (shop.activeEmployees.isNotEmpty) ...[
                    const SizedBox(height: 8),
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
                          .map((e) =>
                              DropdownMenuItem(value: e.id, child: Text(e.name)))
                          .toList(),
                      onChanged: (v) => setLocal(() => employeeId = v),
                    ),
                  ],
                ],
              ),
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
          );
        },
      ),
    );

    if (result != true || !context.mounted || selectedCustomerId == null) {
      return;
    }
    final customer =
        customers.where((c) => c.id == selectedCustomerId).firstOrNull;
    if (customer == null || customer.name.trim().isEmpty) return;

    await tools.addQueue(
      QueueEntry(
        id: tools.newId(),
        customerName: customer.name.trim(),
        customerPhone: customer.phone.trim(),
        employeeId: employeeId ?? '',
        joinedAt: DateTime.now(),
      ),
    );
  }

  String _chairLabel(BuildContext context, Chair chair) =>
      chair.number.trim().isEmpty
          ? chair.name
          : t(context).chairLabel(chair.number, chair.name);

  // NOTE: remainder of file continues in next push if truncated
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('loading chairs…'));
  }
}
