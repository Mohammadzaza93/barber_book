import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/employee.dart';
import '../../../models/team/team_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/team_provider.dart';

/// مركز إدارة الفريق: مهام · تقييم · حضور · إجازات.
class TeamHubScreen extends StatelessWidget {
  const TeamHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة الفريق'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'المهام'),
              Tab(text: 'التقييم'),
              Tab(text: 'الحضور'),
              Tab(text: 'الإجازات'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TasksTab(),
            _EvaluationsTab(),
            _AttendanceTab(),
            _TimeOffTab(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════ المهام ═══════════════════════

class _TasksTab extends StatelessWidget {
  const _TasksTab();

  @override
  Widget build(BuildContext context) {
    final team = context.watch<TeamProvider>();
    final canManage = context.watch<AuthProvider>().canManageRules;

    return Scaffold(
      body: team.tasks.isEmpty
          ? const Center(child: Text('لا توجد مهام بعد'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: team.tasks.length,
              itemBuilder: (_, i) {
                final t = team.tasks[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(t.title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${t.assigneeName.isEmpty ? t.assigneeId : t.assigneeName}'
                      '${t.dueDate != null ? ' · استحقاق ${DateFormat('d/M').format(t.dueDate!)}' : ''}'
                      '\n${t.description}',
                    ),
                    isThreeLine: t.description.isNotEmpty,
                    trailing: DropdownButton<TeamTaskStatus>(
                      value: t.status,
                      underline: const SizedBox.shrink(),
                      items: TeamTaskStatus.values
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(_taskStatusAr(s)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        context
                            .read<TeamProvider>()
                            .saveTask(t.copyWith(status: v));
                      },
                    ),
                    onLongPress: canManage
                        ? () => context.read<TeamProvider>().deleteTask(t.id)
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'team_tasks_fab',
              onPressed: () => _addTask(context),
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('مهمة'),
            )
          : null,
    );
  }

  String _taskStatusAr(TeamTaskStatus s) => switch (s) {
        TeamTaskStatus.pending => 'معلّقة',
        TeamTaskStatus.inProgress => 'قيد التنفيذ',
        TeamTaskStatus.done => 'منجزة',
        TeamTaskStatus.cancelled => 'ملغاة',
      };

  Future<void> _addTask(BuildContext context) async {
    final shop = context.read<ShopProvider>();
    final title = TextEditingController();
    final desc = TextEditingController();
    String? assigneeId =
        shop.activeEmployees.isEmpty ? null : shop.activeEmployees.first.id;
    DateTime? due;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('مهمة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'عنوان المهمة *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: desc,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'التفاصيل',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: assigneeId,
                  items: shop.activeEmployees
                      .map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.name),
                          ))
                      .toList(),
                  onChanged: (v) => setSt(() => assigneeId = v),
                  decoration: const InputDecoration(
                    labelText: 'المكلّف',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    due == null
                        ? 'بدون تاريخ استحقاق'
                        : 'استحقاق: ${DateFormat('d/M/y').format(due!)}',
                  ),
                  trailing: const Icon(Icons.event),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: DateTime.now(),
                    );
                    if (d != null) setSt(() => due = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    if (title.text.trim().isEmpty || assigneeId == null) return;
    final emp = shop.employeeById(assigneeId!);
    final auth = context.read<AuthProvider>();
    await context.read<TeamProvider>().saveTask(TeamTask(
          id: const Uuid().v4(),
          title: title.text.trim(),
          description: desc.text.trim(),
          assigneeId: assigneeId!,
          assigneeName: emp?.name ?? '',
          createdById: auth.user?.uid ?? '',
          createdAt: DateTime.now(),
          dueDate: due,
        ));
  }
}

// ═══════════════════════ التقييم ═══════════════════════

class _EvaluationsTab extends StatelessWidget {
  const _EvaluationsTab();

  @override
  Widget build(BuildContext context) {
    final team = context.watch<TeamProvider>();
    final canManage = context.watch<AuthProvider>().canManageRules;

    return Scaffold(
      body: team.evaluations.isEmpty
          ? const Center(child: Text('لا توجد تقييمات بعد'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: team.evaluations.length,
              itemBuilder: (_, i) {
                final e = team.evaluations[i];
                final period = e.isAnnual
                    ? 'سنوي ${e.year}'
                    : '${e.month}/${e.year}';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(e.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('$period · ${e.notes}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${e.score}/5',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (canManage)
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => context
                                .read<TeamProvider>()
                                .deleteEvaluation(e.id),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'team_eval_fab',
              onPressed: () => _addEval(context),
              icon: const Icon(Icons.star_rate_rounded),
              label: const Text('تقييم'),
            )
          : null,
    );
  }

  Future<void> _addEval(BuildContext context) async {
    final shop = context.read<ShopProvider>();
    String? empId =
        shop.activeEmployees.isEmpty ? null : shop.activeEmployees.first.id;
    var year = DateTime.now().year;
    var month = DateTime.now().month; // 0 = سنوي
    var annual = false;
    var score = 3;
    final notes = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('تقييم أداء'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: empId,
                  items: shop.activeEmployees
                      .map((e) => DropdownMenuItem(
                          value: e.id, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setSt(() => empId = v),
                  decoration: const InputDecoration(
                    labelText: 'الموظف',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تقييم سنوي'),
                  value: annual,
                  onChanged: (v) => setSt(() => annual = v),
                ),
                if (!annual)
                  DropdownButtonFormField<int>(
                    value: month,
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('شهر ${i + 1}'),
                      ),
                    ),
                    onChanged: (v) => setSt(() => month = v ?? month),
                    decoration: const InputDecoration(
                      labelText: 'الشهر',
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 10),
                Text('الدرجة: $score / 5'),
                Slider(
                  value: score.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$score',
                  onChanged: (v) => setSt(() => score = v.round()),
                ),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted || empId == null) return;
    final emp = shop.employeeById(empId!);
    final auth = context.read<AuthProvider>();
    await context.read<TeamProvider>().saveEvaluation(TeamEvaluation(
          id: const Uuid().v4(),
          employeeId: empId!,
          employeeName: emp?.name ?? '',
          year: year,
          month: annual ? 0 : month,
          score: score,
          notes: notes.text.trim(),
          evaluatorId: auth.user?.uid ?? '',
          createdAt: DateTime.now(),
        ));
  }
}

// ═══════════════════════ الحضور / شهادة العمل ═══════════════════════

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab();

  @override
  Widget build(BuildContext context) {
    final team = context.watch<TeamProvider>();
    final canManage = context.watch<AuthProvider>().canManageRules;

    return Scaffold(
      body: Column(
        children: [
          if (canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OutlinedButton.icon(
                onPressed: () => _showCertificate(context),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('شهادة عمل / ملخص راتب شهري'),
              ),
            ),
          Expanded(
            child: team.attendance.isEmpty
                ? const Center(child: Text('لا سجلات حضور بعد'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: team.attendance.length,
                    itemBuilder: (_, i) {
                      final a = team.attendance[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            a.present
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            color: a.present ? Colors.green : Colors.red,
                          ),
                          title: Text(a.employeeName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${DateFormat('d/M/y').format(a.date)} · '
                            '${a.hours} ساعة'
                            '${a.dayPay > 0 ? ' · ${a.dayPay.toStringAsFixed(0)} ل.س' : ''}',
                          ),
                          trailing: canManage
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => context
                                      .read<TeamProvider>()
                                      .deleteAttendance(a.id),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'team_att_fab',
              onPressed: () => _addAttendance(context),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('حضور'),
            )
          : null,
    );
  }

  Future<void> _addAttendance(BuildContext context) async {
    final shop = context.read<ShopProvider>();
    String? empId =
        shop.activeEmployees.isEmpty ? null : shop.activeEmployees.first.id;
    var date = DateTime.now();
    var present = true;
    final hours = TextEditingController(text: '8');
    final pay = TextEditingController(text: '0');
    final notes = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('تسجيل حضور'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: empId,
                  items: shop.activeEmployees
                      .map((e) => DropdownMenuItem(
                          value: e.id, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setSt(() => empId = v),
                  decoration: const InputDecoration(
                    labelText: 'الموظف',
                    border: OutlineInputBorder(),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DateFormat('d/M/y').format(date)),
                  trailing: const Icon(Icons.event),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      initialDate: date,
                    );
                    if (d != null) setSt(() => date = d);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('حاضر'),
                  value: present,
                  onChanged: (v) => setSt(() => present = v),
                ),
                TextField(
                  controller: hours,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ساعات العمل',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pay,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'أجرة اليوم (ل.س) — اختياري',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted || empId == null) return;
    final emp = shop.employeeById(empId!);
    await context.read<TeamProvider>().saveAttendance(TeamAttendance(
          id: const Uuid().v4(),
          employeeId: empId!,
          employeeName: emp?.name ?? '',
          date: date,
          present: present,
          hours: double.tryParse(hours.text) ?? 8,
          dayPay: double.tryParse(pay.text) ?? 0,
          notes: notes.text.trim(),
        ));
  }

  Future<void> _showCertificate(BuildContext context) async {
    final shop = context.read<ShopProvider>();
    final team = context.read<TeamProvider>();
    String? empId =
        shop.activeEmployees.isEmpty ? null : shop.activeEmployees.first.id;
    var year = DateTime.now().year;
    var month = DateTime.now().month;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('شهادة عمل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: empId,
                items: shop.activeEmployees
                    .map((e) =>
                        DropdownMenuItem(value: e.id, child: Text(e.name)))
                    .toList(),
                onChanged: (v) => setSt(() => empId = v),
                decoration: const InputDecoration(labelText: 'الموظف'),
              ),
              DropdownButtonFormField<int>(
                value: month,
                items: List.generate(
                  12,
                  (i) => DropdownMenuItem(
                      value: i + 1, child: Text('شهر ${i + 1}')),
                ),
                onChanged: (v) => setSt(() => month = v ?? month),
                decoration: const InputDecoration(labelText: 'الشهر'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('عرض')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted || empId == null) return;
    final emp = shop.employeeById(empId!);
    final cert = team.buildCertificate(
      employeeId: empId!,
      employeeName: emp?.name ?? '',
      year: year,
      month: month,
    );
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('شهادة عمل / ملخص'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الموظف: ${cert.employeeName}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('الفترة: ${cert.month}/${cert.year}'),
            const Divider(),
            Text('أيام العمل: ${cert.workDays}'),
            Text('إجمالي الساعات: ${cert.totalHours.toStringAsFixed(1)}'),
            Text('إجمالي الأجر المسجّل: ${cert.totalPay.toStringAsFixed(0)} ل.س'),
            const SizedBox(height: 8),
            Text(
              'مبنية على سجلات الحضور المدخلة يدوياً.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}

// ═══════════════════════ الإجازات / التغييب ═══════════════════════

class _TimeOffTab extends StatelessWidget {
  const _TimeOffTab();

  @override
  Widget build(BuildContext context) {
    final team = context.watch<TeamProvider>();
    final canManage = context.watch<AuthProvider>().canManageRules;

    return Scaffold(
      body: team.timeOff.isEmpty
          ? const Center(child: Text('لا طلبات إجازة/تغييب'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: team.timeOff.length,
              itemBuilder: (_, i) {
                final t = team.timeOff[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(t.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${_typeAr(t.type)} · '
                      '${DateFormat('d/M').format(t.from)} → ${DateFormat('d/M').format(t.to)}\n'
                      '${t.reason}',
                    ),
                    isThreeLine: true,
                    trailing: canManage
                        ? PopupMenuButton<String>(
                            onSelected: (v) {
                              final teamP = context.read<TeamProvider>();
                              if (v == 'del') {
                                teamP.deleteTimeOff(t.id);
                              } else {
                                teamP.saveTimeOff(t.copyWith(
                                  status: TimeOffStatus.values
                                      .firstWhere((e) => e.name == v),
                                ));
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'approved', child: Text('موافقة')),
                              PopupMenuItem(
                                  value: 'rejected', child: Text('رفض')),
                              PopupMenuItem(
                                  value: 'pending', child: Text('معلّق')),
                              PopupMenuItem(
                                  value: 'del', child: Text('حذف')),
                            ],
                            child: Chip(label: Text(_statusAr(t.status))),
                          )
                        : Chip(label: Text(_statusAr(t.status))),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'team_timeoff_fab',
        onPressed: () => _addTimeOff(context),
        icon: const Icon(Icons.event_busy_outlined),
        label: const Text('إجازة'),
      ),
    );
  }

  String _typeAr(TimeOffType t) => switch (t) {
        TimeOffType.leave => 'إجازة',
        TimeOffType.sick => 'مرضية',
        TimeOffType.absence => 'تغييب',
        TimeOffType.other => 'أخرى',
      };

  String _statusAr(TimeOffStatus s) => switch (s) {
        TimeOffStatus.pending => 'معلّق',
        TimeOffStatus.approved => 'مقبول',
        TimeOffStatus.rejected => 'مرفوض',
      };

  Future<void> _addTimeOff(BuildContext context) async {
    final shop = context.read<ShopProvider>();
    String? empId =
        shop.activeEmployees.isEmpty ? null : shop.activeEmployees.first.id;
    var from = DateTime.now();
    var to = DateTime.now();
    var type = TimeOffType.leave;
    final reason = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('طلب إجازة / تغييب'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: empId,
                  items: shop.activeEmployees
                      .map((e) => DropdownMenuItem(
                          value: e.id, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setSt(() => empId = v),
                  decoration: const InputDecoration(
                    labelText: 'الموظف',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<TimeOffType>(
                  value: type,
                  items: TimeOffType.values
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(_typeAr(e)),
                          ))
                      .toList(),
                  onChanged: (v) => setSt(() => type = v ?? type),
                  decoration: const InputDecoration(
                    labelText: 'النوع',
                    border: OutlineInputBorder(),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('من: ${DateFormat('d/M/y').format(from)}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: from,
                    );
                    if (d != null) setSt(() => from = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('إلى: ${DateFormat('d/M/y').format(to)}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: from,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: to.isBefore(from) ? from : to,
                    );
                    if (d != null) setSt(() => to = d);
                  },
                ),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                    labelText: 'السبب',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted || empId == null) return;
    final emp = shop.employeeById(empId!);
    await context.read<TeamProvider>().saveTimeOff(TeamTimeOff(
          id: const Uuid().v4(),
          employeeId: empId!,
          employeeName: emp?.name ?? '',
          from: from,
          to: to,
          type: type,
          reason: reason.text.trim(),
        ));
  }
}

// ignore: unused_element — available for roster helpers
String roleLabel(Employee e) => TeamRolePreset.fromId(e.role).labelAr;
