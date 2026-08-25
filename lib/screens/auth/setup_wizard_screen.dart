import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/strings.dart';
import '../../models/employee.dart';
import '../../models/service.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/seed_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/color_picker.dart';
import '../../widgets/confirm.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/work_hours_editor.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _step = 0;
  bool _busy = false;

  final _shopName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _currency = TextEditingController(text: 'SAR');

  String _primaryHex = '0xFF111827';
  String _accentHex = '0xFF2563EB';
  Map<int, List<WorkSlot>> _hours = {};
  final List<Service> _services = [];
  final List<Employee> _staff = [];

  @override
  void dispose() {
    _shopName.dispose();
    _phone.dispose();
    _address.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_shopName.text.trim().isEmpty) {
      showSnack(context, t(context).shopNameRequired);
      return;
    }
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final shopId = await auth.createShop(
      shopName: _shopName.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      currency: _currency.text.trim(),
      primaryColorHex: _primaryHex,
      accentColorHex: _accentHex,
    );
    for (final s in _services) {
      await FirestoreService.instance.addService(shopId, s);
    }
    for (final e in _staff) {
      await FirestoreService.instance.addEmployee(shopId, e);
    }
    await SeedService.instance.seedIfEmpty(shopId);
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, t(context).shopCreated);
  }

  void _addService() {
    final name = TextEditingController();
    final price = TextEditingController(text: '0');
    final dur = TextEditingController(text: '30');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(ctx).addService),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: t(ctx).serviceName),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t(ctx).price),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: dur,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: t(ctx).durationMinutes),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t(ctx).cancel),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              setState(() {
                _services.add(Service(
                  id: const Uuid().v4(),
                  name: name.text.trim(),
                  price: double.tryParse(price.text) ?? 0,
                  durationMinutes: int.tryParse(dur.text) ?? 30,
                  sortOrder: _services.length,
                ));
              });
              Navigator.pop(ctx);
            },
            child: Text(t(ctx).add),
          ),
        ],
      ),
    );
  }

  void _addStaff() {
    final name = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(ctx).addStaff),
        content: TextField(
          controller: name,
          decoration: InputDecoration(labelText: t(ctx).staffName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t(ctx).cancel),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              setState(() {
                _staff.add(Employee(
                  id: const Uuid().v4(),
                  name: name.text.trim(),
                  workingHours: Map.from(_hours),
                  serviceIds: _services.map((s) => s.id).toList(),
                ));
              });
              Navigator.pop(ctx);
            },
            child: Text(t(ctx).add),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t(context).setupTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: LinearProgressIndicator(
                value: (_step + 1) / 5,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: appBrandBackground,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Image.asset('assets/brand/app_icon.png'),
                  ),
                  const SizedBox(height: 18),
                  _buildStep(context),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: Text(t(context).previous),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () {
                            if (_step == 4) {
                              _finish();
                            } else {
                              setState(() => _step++);
                            }
                          },
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_step == 4 ? t(context).finish : t(context).next),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepTitle(context, t(context).setupShopInfo, t(context).setupShopInfoSubtitle),
            const SizedBox(height: 16),
            LabeledField(
              label: t(context).shopName,
              child: TextField(
                controller: _shopName,
                decoration: InputDecoration(hintText: t(context).shopName),
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: t(context).phone,
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '+966 5x xxx xxxx'),
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: t(context).address,
              child: TextField(
                controller: _address,
                decoration: InputDecoration(hintText: t(context).address),
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: t(context).currency,
              child: TextField(
                controller: _currency,
                decoration: const InputDecoration(hintText: 'SAR'),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepTitle(context, t(context).setupBranding, t(context).setupBrandingSubtitle),
            const SizedBox(height: 16),
            ColorPicker(
              label: t(context).primaryColor,
              selectedHex: _primaryHex,
              onChanged: (h) => setState(() => _primaryHex = h),
            ),
            const SizedBox(height: 20),
            ColorPicker(
              label: t(context).accentColor,
              selectedHex: _accentHex,
              onChanged: (h) => setState(() => _accentHex = h),
            ),
            const SizedBox(height: 20),
            _colorPreview(),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepTitle(context, t(context).setupHours, t(context).setupHoursSubtitle),
            const SizedBox(height: 8),
            WorkHoursEditor(value: _hours, onChanged: (m) => setState(() => _hours = m)),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepTitle(context, t(context).setupServices, t(context).setupServicesSubtitle),
            const SizedBox(height: 8),
            if (_services.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  t(context).noServices,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            for (final s in _services)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.content_cut_rounded),
                  title: Text(s.name),
                  subtitle: Text(
                    '${fmtPrice(s.price, _currency.text)} · ${s.durationMinutes} ${t(context).minutesShort}',
                  ),
                  trailing: IconButton(
                    onPressed: () => setState(() => _services.remove(s)),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addService,
              icon: const Icon(Icons.add_rounded),
              label: Text(t(context).addService),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepTitle(context, t(context).setupStaff, t(context).setupStaffSubtitle),
            const SizedBox(height: 8),
            if (_staff.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  t(context).noStaff,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            for (final e in _staff)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(e.name.characters.first)),
                  title: Text(e.name),
                  subtitle: Text(t(context).barber),
                  trailing: IconButton(
                    onPressed: () => setState(() => _staff.remove(e)),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addStaff,
              icon: const Icon(Icons.add_rounded),
              label: Text(t(context).addStaff),
            ),
          ],
        );
    }
  }

  Widget _stepTitle(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ],
    );
  }

  Widget _colorPreview() {
    final primary = parseHexColor(_primaryHex);
    final accent = parseHexColor(_accentHex);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BarberBook',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              t(context).bookNow,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
