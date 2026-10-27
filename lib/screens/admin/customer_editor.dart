import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/customer_profile.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';

String normalizeCustomerPhone(String value) =>
    value.replaceAll(RegExp(r'[^0-9+]'), '');

/// حوار إضافة/تعديل عميل بالحقول الموسّعة.
Future<void> showCustomerEditor(
  BuildContext context, {
  CustomerProfile? existing,
}) async {
  final shop = context.read<ShopProvider>();
  final name = TextEditingController(text: existing?.name ?? '');
  final phone = TextEditingController(text: existing?.phone ?? '');
  final email = TextEditingController(text: existing?.email ?? '');
  final area = TextEditingController(text: existing?.area ?? '');
  final alternatePhone =
      TextEditingController(text: existing?.alternatePhone ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  final allergies = TextEditingController(text: existing?.allergies ?? '');
  final preferredTime =
      TextEditingController(text: existing?.preferredTime ?? '');
  var marketingOptIn = existing?.marketingOptIn ?? false;
  var whatsappSame = existing?.whatsappSameAsPhone ?? true;
  var gender = existing?.gender ?? '';
  var acquisitionSource = existing?.acquisitionSource ?? '';
  DateTime? birthDate = existing?.birthDate;
  String? preferredEmployeeId = existing?.preferredEmployeeId;
  final selectedServices =
      List<String>.from(existing?.preferredServiceIds ?? const []);
  final formKey = GlobalKey<FormState>();

  const genderOptions = [
    ('', '—'),
    ('male', 'ذكر'),
    ('female', 'أنثى'),
    ('other', 'أخرى'),
  ];
  const sourceOptions = [
    ('', '—'),
    ('whatsapp', 'واتساب'),
    ('friend', 'صديق / توصية'),
    ('ad', 'إعلان'),
    ('walkin', 'مرور / زيارة مباشرة'),
    ('other', 'أخرى'),
  ];

  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null
            ? t(context).addCustomer
            : t(context).editCustomerProfile),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: name,
                  decoration:
                      InputDecoration(labelText: t(context).customerNameField),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? t(context).customerNameRequired
                      : null,
                ),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      InputDecoration(labelText: t(context).phoneNumberField),
                  validator: (v) => normalizeCustomerPhone(v ?? '').isEmpty
                      ? t(context).phoneRequired
                      : null,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('واتساب نفس رقم الهاتف'),
                  value: whatsappSame,
                  onChanged: (v) => setState(() => whatsappSame = v),
                ),
                TextFormField(
                  controller: alternatePhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم بديل'),
                ),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: t(context).email),
                  validator: (v) =>
                      v != null && v.trim().isNotEmpty && !v.contains('@')
                          ? t(context).required
                          : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: genderOptions.any((e) => e.$1 == gender) ? gender : '',
                  decoration: const InputDecoration(labelText: 'الجنس'),
                  items: [
                    for (final o in genderOptions)
                      DropdownMenuItem(value: o.$1, child: Text(o.$2)),
                  ],
                  onChanged: (v) => setState(() => gender = v ?? ''),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    birthDate == null
                        ? 'تاريخ الميلاد: غير محدد'
                        : 'تاريخ الميلاد: ${birthDate!.year}/${birthDate!.month.toString().padLeft(2, '0')}/${birthDate!.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_month_rounded),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: birthDate ?? DateTime(1995, 1, 1),
                        firstDate: DateTime(1940),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => birthDate = picked);
                    },
                  ),
                ),
                TextFormField(
                  controller: area,
                  decoration:
                      const InputDecoration(labelText: 'المنطقة / العنوان'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: sourceOptions.any((e) => e.$1 == acquisitionSource)
                      ? acquisitionSource
                      : '',
                  decoration:
                      const InputDecoration(labelText: 'مصدر التعرف علينا'),
                  items: [
                    for (final o in sourceOptions)
                      DropdownMenuItem(value: o.$1, child: Text(o.$2)),
                  ],
                  onChanged: (v) =>
                      setState(() => acquisitionSource = v ?? ''),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: preferredEmployeeId != null &&
                          shop.employees
                              .any((e) => e.id == preferredEmployeeId)
                      ? preferredEmployeeId
                      : null,
                  decoration: const InputDecoration(labelText: 'الحلاق المفضّل'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('—')),
                    for (final e in shop.activeEmployees)
                      DropdownMenuItem<String?>(
                          value: e.id, child: Text(e.name)),
                  ],
                  onChanged: (v) => setState(() => preferredEmployeeId = v),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'الخدمات المفضّلة',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final s in shop.activeServices)
                      FilterChip(
                        label: Text(s.name),
                        selected: selectedServices.contains(s.id),
                        onSelected: (on) {
                          setState(() {
                            if (on) {
                              selectedServices.add(s.id);
                            } else {
                              selectedServices.remove(s.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
                TextFormField(
                  controller: preferredTime,
                  decoration:
                      InputDecoration(labelText: t(context).preferredTimeField),
                ),
                TextFormField(
                  controller: allergies,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'حساسية / موانع',
                    hintText: 'مثل: حساسية من الصبغة',
                  ),
                ),
                TextFormField(
                  controller: notes,
                  maxLines: 3,
                  decoration:
                      InputDecoration(labelText: t(context).customerNotesField),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t(context).marketingOptIn),
                  value: marketingOptIn,
                  onChanged: (value) => setState(() => marketingOptIn = value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t(context).cancel)),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: Text(t(context).save),
          ),
        ],
      ),
    ),
  );
  if (saved != true || !context.mounted) return;
  final tools = context.read<BusinessToolsProvider>();
  final normalizedPhone = normalizeCustomerPhone(phone.text);
  final now = DateTime.now();
  await tools.saveCustomer(CustomerProfile(
    id: existing?.id ?? normalizedPhone,
    name: name.text.trim(),
    phone: normalizedPhone,
    email: email.text.trim(),
    gender: gender,
    birthDate: birthDate,
    area: area.text.trim(),
    alternatePhone: normalizeCustomerPhone(alternatePhone.text),
    whatsappSameAsPhone: whatsappSame,
    acquisitionSource: acquisitionSource,
    allergies: allergies.text.trim(),
    visitCount: existing?.visitCount ?? 0,
    totalSpent: existing?.totalSpent ?? 0,
    firstVisitAt: existing?.firstVisitAt,
    lastVisitAt: existing?.lastVisitAt,
    nextExpectedVisitAt: existing?.nextExpectedVisitAt,
    averageVisitIntervalDays: existing?.averageVisitIntervalDays ?? 0,
    preferredServiceIds: List<String>.from(selectedServices),
    preferredEmployeeId: preferredEmployeeId,
    preferredTime: preferredTime.text.trim(),
    notes: notes.text.trim(),
    marketingOptIn: marketingOptIn,
    createdAt: existing?.createdAt ?? now,
    updatedAt: now,
  ));
}
