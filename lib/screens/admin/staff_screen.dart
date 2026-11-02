import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/strings.dart';
import '../../models/app_role.dart';
import '../../models/employee.dart';
import '../../models/staff_permissions.dart';
import '../../models/team/team_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/shop_manager.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/work_hours_editor.dart';
import 'team/team_hub_screen.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final auth = context.watch<AuthProvider>();
    final canManage = auth.canManageRules;
    // Only the immutable owner may write `members`, and deleting an employee
    // revokes the membership first — so deletion is owner-only even though a
    // manager can still edit the employee record.
    final canDelete = canManage && auth.isOwnerAccount;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeamHubScreen()),
              ),
              icon: const Icon(Icons.groups_2_outlined),
              label: const Text('إدارة الفريق: مهام · تقييم · حضور · إجازات'),
            ),
          ),
          Expanded(
            child: shop.employees.isEmpty
                ? EmptyState(
                    icon: Icons.content_cut_rounded,
                    title: t(context).noStaff,
                    action: canManage
                        ? FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const StaffEditScreen()),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(t(context).addStaff),
                          )
                        : null,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: shop.employees.length,
                    itemBuilder: (context, i) {
                      final e = shop.employees[i];
                      final role = TeamRolePreset.fromId(e.role).labelAr;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: canManage
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          StaffEditScreen(employee: e),
                                    ),
                                  )
                              : null,
                          leading: CircleAvatar(
                            backgroundColor:
                                Color(e.colorValue).withOpacity(0.15),
                            child: Text(
                              e.name.isEmpty ? '?' : e.name.characters.first,
                              style: TextStyle(
                                color: Color(e.colorValue),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(e.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ),
                              if (!e.active)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    t(context).inactive,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '$role · ${e.serviceIds.length} ${t(context).servicesSelected}',
                            style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 12),
                          ),
                          trailing: canDelete
                              ? IconButton(
                                  onPressed: () async {
                                    final ok = await confirmDialog(context,
                                        title: t(context).deleteStaffConfirm,
                                        confirmText: t(context).delete,
                                        destructive: true);
                                    if (ok && context.mounted) {
                                      try {
                                        await context
                                            .read<ShopProvider>()
                                            .deleteEmployee(
                                                e, ShopManager.shopId!);
                                      } catch (_) {
                                        if (context.mounted) {
                                          showSnack(context, t(context).error);
                                        }
                                      }
                                    }
                                  },
                                  icon:
                                      const Icon(Icons.delete_outline_rounded),
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
              heroTag: 'staff_fab',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffEditScreen()),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(t(context).addStaff),
            )
          : null,
    );
  }
}

class StaffEditScreen extends StatefulWidget {
  final Employee? employee;
  const StaffEditScreen({super.key, this.employee});

  @override
  State<StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends State<StaffEditScreen> {
  late final TextEditingController _name;
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _authUid = TextEditingController();
  late String _roleId;
  late Map<int, List<WorkSlot>> _hours;
  late List<String> _serviceIds;
  late bool _active;
  late StaffPermissions _perms;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _name = TextEditingController(text: e?.name ?? '');
    _roleId = TeamRolePreset.fromId(e?.role).id;
    _phone.text = e?.phone ?? '';
    _email.text = e?.email ?? '';
    _authUid.text = e?.authUid ?? '';
    _hours = Map.from(e?.workingHours ?? {});
    _serviceIds = List.from(e?.serviceIds ?? []);
    _active = e?.active ?? true;
    _perms = e?.permissions ?? StaffPermissions.forRole(_roleId);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _authUid.dispose();
    super.dispose();
  }

  void _applyRolePreset(String roleId) {
    setState(() {
      _roleId = roleId;
      _perms = StaffPermissions.forRole(roleId);
    });
  }

  /// الدوران في التطبيق: أدمن -> admin، ومحاسب -> staff (بصلاحيات محدودة).
  AppRole get _accountRole => AppRoleX.fromTeamRole(_roleId);

  Future<String?> _askTemporaryPassword() async {
    final pass = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كلمة مرور مؤقتة'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'يستخدمها الموظف للدخول أول مرة، ثم يمكنه تغييرها من التطبيق.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pass,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'كلمة المرور المؤقتة'),
                validator: (v) => (v == null || v.length < 6)
                    ? t(ctx).passwordTooShort
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirm,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                validator: (v) =>
                    v != pass.text ? t(ctx).passwordsDontMatch : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t(ctx).cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, pass.text);
              }
            },
            child: const Text('إنشاء الحساب'),
          ),
        ],
      ),
    );
    pass.dispose();
    confirm.dispose();
    return result;
  }

  Future<void> _createLogin() async {
    if (widget.employee == null) {
      showSnack(context, 'احفظ بيانات الموظف أولاً ثم أنشئ له حساب دخول');
      return;
    }
    final email = _email.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      showSnack(context, 'أدخل بريد الموظف أولاً');
      return;
    }
    final password = await _askTemporaryPassword();
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    try {
      final uid = await auth.addStaffAccount(
        email: email,
        name: _name.text.trim(),
        role: _accountRole,
        permissions: _perms,
        password: password,
      );
      await _attachUid(uid);
    } on StaffAccountAlreadyExists {
      if (mounted) await _linkExisting(email);
    } on MembershipWriteException catch (e) {
      if (mounted) {
        showSnack(
          context,
          'تم إنشاء حساب الدخول لكن فشل ربطه بالمحل. '
          'أعد المحاولة باستخدام UID: ${e.uid}',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showSnack(context, 'تعذّر إنشاء الحساب: ${e.message ?? e.code}');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'تعذّر إنشاء الحساب: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Handles `email-already-in-use`: the owner must supply the existing
  /// 28-character uid and confirm before only `members/{uid}` is written.
  Future<void> _linkExisting(String email) async {
    if (!mounted) return;
    final uidCtrl = TextEditingController();
    final uid = await showDialog<String>(
      context: context,
      builder: (ctx) {
        var confirmed = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('ربط بحساب موجود'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'البريد $email يملك حساب دخول بالفعل. '
                  'أدخل UID الحساب (28 حرفاً) ثم أكّد الربط.',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: uidCtrl,
                  decoration: const InputDecoration(labelText: 'UID الحساب'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: confirmed,
                  onChanged: (v) => setLocal(() => confirmed = v ?? false),
                  title: const Text(
                    'أؤكد ربط هذا الحساب بهذا المحل',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t(ctx).cancel),
              ),
              FilledButton(
                onPressed: confirmed
                    ? () {
                        final value = uidCtrl.text.trim();
                        if (!RegExp(r'^[A-Za-z0-9]{28}$').hasMatch(value)) {
                          showSnack(ctx, 'UID يجب أن يكون 28 حرفاً');
                          return;
                        }
                        Navigator.pop(ctx, value);
                      }
                    : null,
                child: const Text('ربط الحساب'),
              ),
            ],
          ),
        );
      },
    );
    uidCtrl.dispose();
    if (uid == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().linkStaffAccount(
            uid: uid,
            email: email,
            name: _name.text.trim(),
            role: _accountRole,
            permissions: _perms,
          );
      await _attachUid(uid);
    } on MembershipWriteException catch (e) {
      if (mounted) {
        showSnack(
          context,
          'فشل ربط الحساب بالمحل. أعد المحاولة باستخدام UID: ${e.uid}',
        );
      }
    } catch (e) {
      if (mounted) showSnack(context, 'تعذّر ربط الحساب: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attachUid(String uid) async {
    final employee = widget.employee;
    if (employee == null) return;
    await context.read<ShopProvider>().updateEmployee(
          employee.copyWith(
            authUid: uid,
            email: _email.text.trim(),
            permissions: _perms,
          ),
          ShopManager.shopId!,
        );
    if (!mounted) return;
    setState(() => _authUid.text = uid);
    showSnack(context, 'تم ربط حساب الدخول بالموظف');
  }

  Future<void> _resendPasswordReset() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      showSnack(context, 'لا يوجد بريد للموظف');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().sendPasswordReset(email);
      if (mounted) {
        showSnack(context, 'تم إرسال رابط إعادة تعيين كلمة المرور');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'تعذّر إرسال الرابط: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!context.read<AuthProvider>().canManageRules) return;
    final shop = context.read<ShopProvider>();
    final shopId = ShopManager.shopId!;
    if (_name.text.trim().isEmpty) {
      showSnack(context, t(context).fillRequiredFields);
      return;
    }
    setState(() => _busy = true);
    final e = Employee(
      id: widget.employee?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      role: _roleId,
      phone: _phone.text.trim(),
      email: _email.text.trim().isEmpty ? '' : _email.text.trim(),
      authUid: _authUid.text.trim().isEmpty ? null : _authUid.text.trim(),
      workingHours: _hours,
      serviceIds: _serviceIds,
      active: _active,
      colorValue: widget.employee?.colorValue ?? 0xFF26A69A,
      permissions: _perms,
    );
    try {
      if (widget.employee == null) {
        await shop.addEmployee(e, shopId);
      } else {
        await shop.updateEmployee(e, shopId);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      showSnack(context, t(context).error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final auth = context.watch<AuthProvider>();
    final canManage = auth.canManageRules;
    // Changing a role writes `members/{uid}.role`, which only the true owner may
    // do (an admin must not be able to promote themselves or anyone else).
    final canChangeRole = auth.isOwnerAccount;
    // Provisioning/linking a login writes `members/{uid}`, which is owner-only.
    final canProvisionLogin = auth.isOwnerAccount;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee == null
            ? t(context).addStaff
            : t(context).editStaff),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            decoration: InputDecoration(
              labelText: t(context).staffName,
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _roleId,
            items: TeamRolePreset.all
                .map(
                  (r) => DropdownMenuItem(
                    value: r.id,
                    child: Text(r.labelAr),
                  ),
                )
                .toList(),
            onChanged: canManage && canChangeRole
                ? (v) {
                    if (v != null) _applyRolePreset(v);
                  }
                : null,
            decoration: InputDecoration(
              labelText: t(context).role,
              helperText: _roleId == TeamRolePreset.admin.id
                  ? 'أدمن: يملك كل الصلاحيات تلقائياً'
                  : 'محاسب: صلاحيات محدودة — حدّدها بالأسفل',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: t(context).phone),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'بريد الموظف لربط الحساب',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          if (canProvisionLogin)
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.key_rounded),
                    title: Text(
                      _authUid.text.isEmpty
                          ? 'لا يوجد حساب دخول مرتبط'
                          : 'حساب الدخول مرتبط',
                    ),
                    subtitle: _authUid.text.isEmpty
                        ? const Text(
                            'أنشئ حساباً للدخول أو اربط حساباً موجوداً',
                            style: TextStyle(fontSize: 12),
                          )
                        : Text(
                            _authUid.text,
                            style: const TextStyle(fontSize: 11),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: widget.employee == null
                        ? const Text(
                            'احفظ بيانات الموظف أولاً، ثم افتحه مرة أخرى لإنشاء حساب الدخول.',
                            style: TextStyle(fontSize: 12),
                          )
                        : _authUid.text.isEmpty
                            ? FilledButton.tonalIcon(
                                onPressed: _busy ? null : _createLogin,
                                icon:
                                    const Icon(Icons.person_add_alt_1_rounded),
                                label: const Text('إنشاء حساب دخول للموظف'),
                              )
                            : OutlinedButton.icon(
                                onPressed: _busy ? null : _resendPasswordReset,
                                icon: const Icon(Icons.mail_outline_rounded),
                                label:
                                    const Text('إعادة إرسال رابط كلمة المرور'),
                              ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            t(context).workingHours,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'جدول عمل ديناميكي — أيام وساعات لكل موظف',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 8),
          WorkHoursEditor(
            value: _hours,
            onChanged: (m) => setState(() => _hours = m),
          ),
          const SizedBox(height: 16),
          Text(
            t(context).availableFor,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: shop.services.map((s) {
              final selected = _serviceIds.contains(s.id);
              return FilterChip(
                label: Text(s.name),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    _serviceIds.add(s.id);
                  } else {
                    _serviceIds.remove(s.id);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t(context).active),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          if (canManage) ...[
            const SizedBox(height: 16),
            const Text(
              'صلاحيات الموظف',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'حدد الأقسام — تتغير تلقائياً عند اختيار الدور ويمكن تخصيصها',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Card(
              child: _roleId == TeamRolePreset.admin.id
                  ? const ListTile(
                      leading: Icon(Icons.verified_user_outlined),
                      title: Text('الأدمن يملك كل الصلاحيات تلقائياً'),
                      subtitle: Text(
                        'لا حاجة لتحديدها يدوياً. اختر «محاسب» لتحديد صلاحيات محدودة.',
                      ),
                    )
                  : Column(
                      children: [
                        SwitchListTile(
                            title: const Text('المواعيد'),
                            value: _perms.appointments,
                            onChanged: (v) => setState(() =>
                                _perms = _perms.copyWith(appointments: v))),
                        SwitchListTile(
                            title: const Text('المدفوعات'),
                            value: _perms.payments,
                            onChanged: (v) => setState(
                                () => _perms = _perms.copyWith(payments: v))),
                        SwitchListTile(
                            title: const Text('الخدمات'),
                            value: _perms.services,
                            onChanged: (v) => setState(
                                () => _perms = _perms.copyWith(services: v))),
                        SwitchListTile(
                            title: const Text('الموظفين'),
                            value: _perms.staff,
                            onChanged: (v) => setState(
                                () => _perms = _perms.copyWith(staff: v))),
                        SwitchListTile(
                            title: const Text('الخصومات'),
                            value: _perms.discounts,
                            onChanged: (v) => setState(
                                () => _perms = _perms.copyWith(discounts: v))),
                        SwitchListTile(
                            title: const Text('المصروفات'),
                            value: _perms.expenses,
                            onChanged: (v) => setState(
                                () => _perms = _perms.copyWith(expenses: v))),
                        SwitchListTile(
                            title: const Text('آراء العملاء'),
                            value: _perms.feedback,
                            onChanged: (v) => setState(
                                () => _perms = _perms.copyWith(feedback: v))),
                        SwitchListTile(
                            title: const Text('طلبات خارج الدوام'),
                            value: _perms.outOfHours,
                            onChanged: (v) => setState(
                                () => _perms = _perms.copyWith(outOfHours: v))),
                        SwitchListTile(
                            title: const Text('التقارير'),
                            value: _perms.reports,
                            onChanged: (v) => setState(
                                () => _perms = _perms.copyWith(reports: v))),
                        SwitchListTile(
                            title: const Text('أدوات الأعمال'),
                            value: _perms.businessTools,
                            onChanged: (v) => setState(() =>
                                _perms = _perms.copyWith(businessTools: v))),
                        SwitchListTile(
                            title: const Text('المالية والمحاسبة'),
                            value: _perms.finance,
                            onChanged: (v) => setState(
                                () => _perms = _perms.copyWith(finance: v))),
                        SwitchListTile(
                            title: const Text('إعدادات المحل'),
                            value: _perms.settings,
                            onChanged: (v) => setState(
                                () => _perms = _perms.copyWith(settings: v))),
                      ],
                    ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(t(context).save),
          ),
        ],
      ),
    );
  }
}
