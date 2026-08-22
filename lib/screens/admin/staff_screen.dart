import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/strings.dart';
import '../../models/employee.dart';
import '../../providers/shop_provider.dart';
import '../../services/shop_manager.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/work_hours_editor.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    return Scaffold(
      body: shop.employees.isEmpty
          ? EmptyState(
              icon: Icons.people_rounded,
              title: t(context).noStaff,
              action: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffEditScreen()),
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(t(context).addStaff),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: shop.employees.length,
              itemBuilder: (context, i) {
                final e = shop.employees[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => StaffEditScreen(employee: e)),
                    ),
                    leading: e.avatarUrl != null && e.avatarUrl!.trim().isNotEmpty
                        ? CircleAvatar(backgroundImage: NetworkImage(e.avatarUrl!))
                        : CircleAvatar(
                      backgroundColor: Color(e.colorValue).withOpacity(0.15),
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
                      '${e.serviceIds.length} ${t(context).servicesSelected}'
                      '${e.bio.trim().isEmpty ? '' : '  •  سيرة ذاتية مضافة'}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    trailing: IconButton(
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: t(context).deleteStaffConfirm,
                            confirmText: t(context).delete,
                            destructive: true);
                        if (ok && context.mounted) {
                          await context
                              .read<ShopProvider>()
                              .deleteEmployee(e.id, ShopManager.shopId!);
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StaffEditScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(t(context).addStaff),
      ),
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
  final _role = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _avatarUrl = TextEditingController();
  final _bio = TextEditingController();
  final _specialties = TextEditingController();
  final _experienceYears = TextEditingController();
  late Map<int, List<WorkSlot>> _hours;
  late List<String> _serviceIds;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _name = TextEditingController(text: e?.name ?? '');
    _role.text = e?.role ?? 'barber';
    _phone.text = e?.phone ?? '';
    _email.text = e?.email ?? '';
    _avatarUrl.text = e?.avatarUrl ?? '';
    _bio.text = e?.bio ?? '';
    _specialties.text = e?.specialties ?? '';
    _experienceYears.text = '${e?.experienceYears ?? 0}';
    _hours = Map.from(e?.workingHours ?? {});
    _serviceIds = List.from(e?.serviceIds ?? []);
    _active = e?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _phone.dispose();
    _email.dispose();
    _avatarUrl.dispose();
    _bio.dispose();
    _specialties.dispose();
    _experienceYears.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final shop = context.read<ShopProvider>();
    final shopId = ShopManager.shopId!;
    if (_name.text.trim().isEmpty) {
      showSnack(context, t(context).fillRequiredFields);
      return;
    }
    final e = Employee(
      id: widget.employee?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      role: _role.text.trim().isEmpty ? 'barber' : _role.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      avatarUrl: _avatarUrl.text.trim().isEmpty ? null : _avatarUrl.text.trim(),
      bio: _bio.text.trim(),
      specialties: _specialties.text.trim(),
      experienceYears: int.tryParse(_experienceYears.text.trim()) ?? 0,
      showBio: true,
      workingHours: _hours,
      serviceIds: _serviceIds,
      active: _active,
      colorValue: widget.employee?.colorValue ?? 0xFF26A69A,
    );
    if (widget.employee == null) {
      await shop.addEmployee(e, shopId);
    } else {
      await shop.updateEmployee(e, shopId);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
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
            decoration:
                InputDecoration(labelText: t(context).staffName, prefixIcon: const Icon(Icons.person_outline_rounded)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _role,
                  decoration:
                      InputDecoration(labelText: t(context).role),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      InputDecoration(labelText: t(context).phone),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('السيرة الذاتية المهنية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          TextFormField(
            controller: _avatarUrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'رابط الصورة الشخصية', prefixIcon: Icon(Icons.image_outlined)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)))),
            const SizedBox(width: 10),
            SizedBox(width: 130, child: TextFormField(controller: _experienceYears, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سنوات الخبرة'))),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            controller: _specialties,
            decoration: const InputDecoration(labelText: 'التخصصات والمهارات', hintText: 'قصات رجالية، لحية، تدرج... ', prefixIcon: Icon(Icons.workspace_premium_outlined)),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _bio,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'نبذة عن الموظف', hintText: 'اكتب الخبرة المهنية والإنجازات وطريقة العمل...', prefixIcon: Icon(Icons.description_outlined)),
          ),
          const SizedBox(height: 16),
          Text(t(context).workingHours,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          WorkHoursEditor(
            value: _hours,
            onChanged: (m) => setState(() => _hours = m),
          ),
          const SizedBox(height: 16),
          Text(t(context).availableFor,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A))),
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
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(t(context).save)),
        ],
      ),
    );
  }
}
