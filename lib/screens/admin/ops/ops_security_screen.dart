import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/activity_log.dart';
import '../../../providers/appointment_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/ops_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../services/backup_service.dart';

/// النسخ الاحتياطي + سجل النشاطات.
class OpsSecurityScreen extends StatelessWidget {
  const OpsSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الأمان والنسخ الاحتياطي'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'النسخ الاحتياطي'),
              Tab(text: 'سجل النشاطات'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BackupsTab(),
            _ActivityTab(),
          ],
        ),
      ),
    );
  }
}

class _BackupsTab extends StatefulWidget {
  const _BackupsTab();

  @override
  State<_BackupsTab> createState() => _BackupsTabState();
}

class _BackupsTabState extends State<_BackupsTab> {
  bool _busy = false;

  Future<void> _runManual() async {
    if (_busy) return;
    final auth = context.read<AuthProvider>();
    final shopId = auth.shopId;
    if (shopId == null) return;
    setState(() => _busy = true);
    try {
      final meta = await BackupService.instance.createBackup(
        shopId: shopId,
        actorUid: auth.user?.uid ?? '',
        actorName: auth.user?.email ?? 'admin',
        trigger: 'manual',
        appointments: context.read<AppointmentProvider>().appointments,
        employees: context.read<ShopProvider>().employees,
        services: context.read<ShopProvider>().services,
        financeEntries: context.read<FinanceProvider>().entries,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم النسخ (${meta.payloadBytes} بايت)'
            '${meta.storagePath != null ? ' + رفع Storage' : ''}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل النسخ: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsProvider>();
    final canManage = context.watch<AuthProvider>().canManageRules;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'نسخة احتياطية يومية تلقائية عند فتح التطبيق (كل 24 ساعة)، '
                'بالإضافة لنسخ يدوي من هنا. الملخص يُحفظ في Firestore، '
                'والملف الكامل يُرفع إلى Storage عند الإمكان — بدون أدوات مدفوعة.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 12),
              if (canManage)
                FilledButton.icon(
                  onPressed: _busy ? null : _runManual,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.backup_rounded),
                  label: Text(_busy ? 'جارٍ النسخ...' : 'نسخ احتياطي الآن'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ops.backups.isEmpty
              ? const Center(child: Text('لا توجد نسخ بعد'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ops.backups.length,
                  itemBuilder: (_, i) {
                    final b = ops.backups[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          b.trigger == 'auto'
                              ? Icons.schedule_rounded
                              : Icons.backup_rounded,
                        ),
                        title: Text(
                          DateFormat('d/M/y HH:mm').format(b.createdAt),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${b.trigger == 'auto' ? 'تلقائي' : 'يدوي'} · '
                          'مواعيد ${b.appointmentsCount} · '
                          'موظفين ${b.employeesCount} · '
                          'خدمات ${b.servicesCount} · '
                          'مبيعات ${b.financeEntriesCount}\n'
                          '${b.note}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab();

  String _actionAr(String a) => switch (a) {
        'create' => 'إنشاء',
        'update' => 'تعديل',
        'delete' => 'حذف',
        'backup' => 'نسخ احتياطي',
        'login' => 'دخول',
        _ => a,
      };

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsProvider>();

    if (ops.loading && ops.logs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ops.logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا نشاطات مسجّلة بعد. ستظهر هنا العمليات المهمة '
            '(مالية، فريق، نسخ احتياطي...).',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ops.logs.length,
      itemBuilder: (_, i) {
        final e = ops.logs[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(
              '${_actionAr(e.action)} · ${e.entity}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${e.summary.isEmpty ? e.entityId : e.summary}\n'
              '${DateFormat('d/M/y HH:mm').format(e.at)}'
              '${e.actorName.isNotEmpty ? ' · ${e.actorName}' : ''}',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
