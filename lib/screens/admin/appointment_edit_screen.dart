import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/appointment.dart';
import '../../models/enums.dart';
import '../../models/service.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/booking_calc.dart';
import '../../services/calendar_service.dart';
import '../../services/reminder_service.dart';
import '../../services/secure_api.dart';
import '../../services/secure_error_text.dart';
import '../../services/shop_manager.dart';
import '../../widgets/confirm.dart';
import '../../widgets/service_picker.dart';
import '../../widgets/slot_picker.dart';
import '../../widgets/slot_utils.dart';
import '../../widgets/status_chip.dart';

class AppointmentEditScreen extends StatefulWidget {
  final Appointment? appointment;
  const AppointmentEditScreen({super.key, this.appointment});

  @override
  State<AppointmentEditScreen> createState() => _AppointmentEditScreenState();
}

class _AppointmentEditScreenState extends State<AppointmentEditScreen> {
  Appointment? get _a => widget.appointment;
  bool get _isNew => _a == null;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  final _promo = TextEditingController();

  List<String> _serviceIds = [];
  String? _employeeId;
  String? _chairId;
  DateTime? _date;
  DateTime? _slot;
  bool _recurring = false;
  bool _busy = false;

  List<DateTime> _slots = [];

  @override
  void initState() {
    super.initState();
    final a = _a;
    if (a != null) {
      _name.text = a.customerName;
      _phone.text = a.customerPhone;
      _email.text = a.customerEmail;
      _notes.text = a.notes;
      _serviceIds = List.from(a.serviceIds);
      _employeeId = a.employeeId;
      _chairId = a.chairId;
      _date = a.startTime;
      _slot = a.startTime;
      _recurring = a.recurring;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    _promo.dispose();
    super.dispose();
  }

  int get _totalDuration {
    final shop = context.read<ShopProvider>();
    return _serviceIds.fold(
        0, (sum, id) => sum + (shop.serviceById(id)?.durationMinutes ?? 0));
  }

  void _recomputeSlots() {
    final shop = context.read<ShopProvider>();
    if (_employeeId == null || _date == null) return;
    final employee = shop.employeeById(_employeeId!);
    if (employee == null) return;
    final appointments = context.read<AppointmentProvider>().appointments;
    setState(() {
      _slots = generateSlots(
        employee: employee,
        appointments: appointments,
        day: _date!,
        durationMinutes: _totalDuration,
      );
      if (_slot != null &&
          (_slot!.year != _date!.year ||
              _slot!.month != _date!.month ||
              _slot!.day != _date!.day)) {
        _slot = null;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final settings = context.read<ShopProvider>().settings;
    final max = now.add(Duration(days: settings?.maxAdvanceDays ?? 60));
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: max,
    );
    if (picked != null) {
      setState(() => _date = picked);
      _recomputeSlots();
    }
  }

  Future<void> _submit() async {
    final shop = context.read<ShopProvider>();
    final settings = shop.settings!;
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      showSnack(context, t(context).fillRequiredFields);
      return;
    }
    if (_serviceIds.isEmpty) {
      showSnack(context, t(context).selectServicesFirst);
      return;
    }
    if (_employeeId == null) {
      showSnack(context, t(context).selectEmployee);
      return;
    }
    if (_slot == null) {
      showSnack(context, t(context).selectTime);
      return;
    }

    setState(() => _busy = true);
    final shopId = ShopManager.shopId!;

    // The server owns the reference, the duration, the discount, the deposit
    // and the resulting payment status, so the client only sends intent.
    List<Map<String, dynamic>> created;
    try {
      created = await SecureApi.instance.createAppointment(
        shopId: shopId,
        employeeId: _employeeId!,
        chairId: _chairId,
        serviceIds: _serviceIds,
        startTime: _slot!.toUtc().toIso8601String(),
        requestId: SecureApi.instance.newRequestId(),
        customerName: _name.text.trim(),
        customerPhone: _phone.text.trim(),
        customerEmail: _email.text.trim(),
        notes: _notes.text.trim(),
        discountCode: _promo.text.trim().isEmpty ? null : _promo.text.trim(),
        recurring: _recurring,
      );
    } on SecureApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, describeSecureError(context, error));
      return;
    }

    for (final item in created) {
      await ReminderService.instance.scheduleLocalReminders(
          settings, Appointment.fromMap(item['id'] as String, item));
    }

    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, t(context).settingsSaved);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final tools = context.watch<BusinessToolsProvider>();
    final settings = shop.settings!;
    final currency = settings.currency;

    return Scaffold(
      appBar: AppBar(
          title: Text(
              _isNew ? t(context).newAppointment : t(context).editAppointment)),
      body: _isNew
          ? _buildCreate(context, shop, tools, settings, currency)
          : _buildView(context, shop, tools, settings, currency),
    );
  }

  // ---------- Create mode ----------

  Widget _buildCreate(
      BuildContext context, ShopProvider shop, BusinessToolsProvider tools, settings, String currency) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section(context, t(context).customerDetails, [
          _field(t(context).name, _name,
              icon: Icons.person_outline_rounded),
          _field(t(context).phone, _phone,
              icon: Icons.phone_outlined, keyboard: TextInputType.phone),
          _field(t(context).email, _email,
              icon: Icons.mail_outline_rounded,
              keyboard: TextInputType.emailAddress,
              optional: true),
        ]),
        _section(context, t(context).chooseServices, [
          ServicePicker(
            services: shop.activeServices,
            selectedIds: _serviceIds,
            currency: currency,
            onChanged: (ids) {
              setState(() => _serviceIds = ids);
              _recomputeSlots();
            },
          ),
        ]),
        _section(context, t(context).chooseBarber, [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: shop.activeEmployees.map((e) {
              final selected = _employeeId == e.id;
              return ChoiceChip(
                avatar: const Icon(Icons.person_rounded, size: 16),
                label: Text(e.name),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _employeeId = e.id;
                    _chairId = null;
                  });
                  _recomputeSlots();
                },
              );
            }).toList(),
          ),
          if (_employeeId != null && tools.chairs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DropdownButtonFormField<String>(
                value: _chairId,
                decoration: const InputDecoration(
                  labelText: 'كرسي الحلاقة',
                  prefixIcon: Icon(Icons.event_seat_outlined),
                ),
                items: tools.chairs.where((chair) => chair.active && (chair.employeeId == null || chair.employeeId == _employeeId)).map(
                    (chair) => DropdownMenuItem(value: chair.id, child: Text(chair.number.isEmpty ? chair.name : 'كرسي ${chair.number} — ${chair.name}')),
                  ).toList(),
                onChanged: (value) => setState(() => _chairId = value),
              ),
            ),
        ]),
        _section(context, t(context).chooseDateTime, [
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_rounded),
            label: Text(_date == null
                ? t(context).selectDate
                : DateFormat('EEEE, d MMMM yyyy').format(_date!)),
          ),
          const SizedBox(height: 12),
          if (_employeeId != null && _date != null && _totalDuration > 0)
            SlotPicker(
              slots: _slots,
              selected: _slot,
              onSelect: (s) => setState(() => _slot = s),
              emptyMessage: t(context).noSlotsForDay,
            ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _recurring,
            onChanged: (v) => setState(() => _recurring = v),
            title: Text(t(context).toggleRecurring),
            subtitle: Text(t(context).recurring),
          ),
        ]),
        _section(context, t(context).customerNotes, [
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: InputDecoration(hintText: t(context).customerNotes),
          ),
        ]),
        _section(context, t(context).applyCode, [
          TextField(
            controller: _promo,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.local_offer_outlined),
              hintText: t(context).applyCode,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        _summaryCard(settings, currency),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t(context).confirmBooking),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _summaryCard(settings, String currency) {
    final shop = context.read<ShopProvider>();
    final selected = shop.services
        .where((s) => _serviceIds.contains(s.id))
        .toList();
    final total = selected.fold(0.0, (sum, s) => sum + s.price);
    final deposit = computeDeposit(settings, selected, total);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(t(context).totalPrice, fmtPrice(total, currency)),
            if (deposit > 0) ...[
              const SizedBox(height: 6),
              _row(t(context).deposit, fmtPrice(deposit, currency), bold: true),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- View mode ----------

  Widget _buildView(
      BuildContext context, ShopProvider shop, BusinessToolsProvider tools, settings, String currency) {
    final a = _a!;
    final services = a.serviceIds
        .map((id) => shop.serviceById(id))
        .whereType<Service>()
        .toList();
    final employeeName = shop.employeeById(a.employeeId)?.name ?? '-';
    final chair = a.chairId == null ? null : tools.chairs.where((item) => item.id == a.chairId).firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(a.customerName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    StatusChip(status: a.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${t(context).reference}: ${a.reference}',
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const Divider(height: 24),
                _infoRow(
                    Icons.schedule_rounded,
                    '${DateFormat('EEEE, d MMMM yyyy - HH:mm').format(a.startTime)}'
                    ' · ${a.endTime.difference(a.startTime).inMinutes} ${t(context).minutesShort}'),
                _infoRow(Icons.phone_outlined, a.customerPhone),
                if (a.customerEmail.isNotEmpty)
                  _infoRow(Icons.mail_outline_rounded, a.customerEmail),
                _infoRow(Icons.person_rounded, employeeName),
                if (chair != null) _infoRow(Icons.event_seat_outlined, chair.number.isEmpty ? chair.name : 'كرسي ${chair.number} — ${chair.name}'),
                _infoRow(Icons.content_cut_rounded,
                    services.map((s) => s.name).join(' + ')),
                if (a.notes.isNotEmpty)
                  _infoRow(Icons.notes_rounded, a.notes),
                const Divider(height: 24),
                _row(t(context).totalPrice, fmtPrice(a.totalAmount, currency)),
                if (a.depositAmount > 0)
                  _row(t(context).deposit,
                      fmtPrice(a.depositAmount, currency),
                      bold: true),
                if (a.discountAmount > 0)
                  _row('${t(context).discounts} (${a.discountCode})',
                      '-${fmtPrice(a.discountAmount, currency)}'),
                if (a.recurring)
                  _row(t(context).recurring, '✓', bold: true),
                if (a.outOfHours)
                  _row(t(context).outOfHours, '✓', bold: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _section(context, t(context).actions, [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionChip(context, Icons.check_rounded,
                  t(context).markConfirmed,
                  () => _changeStatus(AppointmentStatus.confirmed),
                  color: Colors.blue),
              _actionChip(context, Icons.done_all_rounded,
                  t(context).markCompleted,
                  () => _changeStatus(AppointmentStatus.completed),
                  color: Colors.green),
              _actionChip(context, Icons.event_busy_rounded,
                  t(context).markCancelled,
                  () => _changeStatus(AppointmentStatus.cancelled),
                  color: Colors.grey),
              _actionChip(context, Icons.person_off_rounded,
                  t(context).markNoShow,
                  () => _changeStatus(AppointmentStatus.noShow),
                  color: Colors.red),
            ],
          ),
        ]),
        _section(context, t(context).paymentStatus, [
          Row(
            children: [
              ChoiceChip(
                label: Text(_paymentLabel(context, a.paymentStatus)),
                selected: true,
                onSelected: (_) => _recordPayment(a),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t(context).paymentDerivedByServer,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ]),
        _section(context, t(context).reminderSettings, [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await ReminderService.instance
                      .sendViaWhatsApp(a, settings, services);
                  if (!context.mounted) return;
                  await context
                      .read<AppointmentProvider>()
                      .markReminderSent(a, ShopManager.shopId!);
                },
                icon: const Icon(Icons.chat_rounded),
                label: Text(t(context).shareViaWhatsapp),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await ReminderService.instance
                      .sendViaEmail(a, settings, services);
                  if (!context.mounted) return;
                  await context
                      .read<AppointmentProvider>()
                      .markReminderSent(a, ShopManager.shopId!);
                },
                icon: const Icon(Icons.email_outlined),
                label: Text(t(context).sendEmailReminder),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t(context).reminderChannelsNote,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ]),
        _section(context, t(context).calendarSync, [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => CalendarService.instance
                    .openGoogleCalendar(a, settings, services),
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(t(context).openGoogleCalendar),
              ),
              OutlinedButton.icon(
                onPressed: () => CalendarService.instance
                    .exportIcs(a, settings, services),
                icon: const Icon(Icons.download_rounded),
                label: Text(t(context).exportIcs),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => confirmDialog(
            context,
            title: t(context).cancelAppointment,
            message: t(context).cancelPolicyNote('${settings.cancelFreeHours}'),
            confirmText: t(context).markCancelled,
            destructive: true,
          ).then((ok) {
            if (ok == true) _changeStatus(AppointmentStatus.cancelled);
          }),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          child: Text(t(context).cancelAppointment),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  String _paymentLabel(BuildContext context, PaymentStatus p) => switch (p) {
        PaymentStatus.unpaid => t(context).unpaid,
        PaymentStatus.depositPaid => t(context).depositPaid,
        PaymentStatus.paid => t(context).paid,
      };

  Widget _actionChip(BuildContext context, IconData icon, String label,
      VoidCallback onTap,
      {required Color color}) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color)),
      onPressed: onTap,
    );
  }

  Future<void> _changeStatus(AppointmentStatus status) async {
    final a = _a!;
    final provider = context.read<AppointmentProvider>();
    try {
      if (a.recurring && a.seriesId != null) {
        final applyToSeries = await confirmDialog(
          context,
          title: t(context).applyToSeries,
          message: t(context).recurring,
        );
        if (!context.mounted) return;
        await provider.setStatus(a, status, ShopManager.shopId!,
            applyToSeries: applyToSeries);
      } else {
        await provider.setStatus(a, status, ShopManager.shopId!);
      }
    } on SecureApiException catch (error) {
      if (!mounted) return;
      showSnack(context, describeSecureError(context, error));
    }
  }

  /// Records a payment and lets the server derive the payment status from the
  /// amount collected so far, so the two can never be set independently.
  Future<void> _recordPayment(Appointment a) async {
    final remaining = (a.totalAmount - a.collectedAmount).clamp(0.0, double.infinity);
    final amount = TextEditingController(text: remaining.toStringAsFixed(2));
    var method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(t(context).recordPayment),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: t(context).amountCollected),
                ),
                DropdownButtonFormField<String>(
                  value: method,
                  items: [
                    DropdownMenuItem(value: 'cash', child: Text(t(context).payCash)),
                    DropdownMenuItem(value: 'card', child: Text(t(context).payCard)),
                    DropdownMenuItem(
                        value: 'transfer', child: Text(t(context).payTransfer)),
                  ],
                  onChanged: (value) => setState(() => method = value ?? 'cash'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(t(context).save),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final value = double.tryParse(amount.text.trim());
    if (value == null || value <= 0) {
      showSnack(context, t(context).enterValidAmount);
      return;
    }
    try {
      await context.read<AppointmentProvider>().recordPayment(
            a,
            ShopManager.shopId!,
            method: method,
            amount: value,
          );
    } on SecureApiException catch (error) {
      if (!mounted) return;
      showSnack(context, describeSecureError(context, error));
    }
  }

  // ---------- Helpers ----------

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _field(String label, TextEditingController controller, {IconData? icon, TextInputType? keyboard, bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: optional ? '$label ${t(context).optional}' : label,
          prefixIcon: icon == null ? null : Icon(icon),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}
