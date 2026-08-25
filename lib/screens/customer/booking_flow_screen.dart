import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/strings.dart';
import '../../models/appointment.dart';
import '../../models/enums.dart';
import '../../models/service.dart';
import '../../models/unavailability_request.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/discount_provider.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/booking_calc.dart';
import '../../services/firestore_service.dart';
import '../../services/reminder_service.dart';
import '../../services/notification_service.dart';
import '../../services/shop_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirm.dart';
import '../../widgets/feature_labels.dart';
import '../../widgets/slot_picker.dart';
import '../../widgets/slot_utils.dart';
import 'booking_success_screen.dart';
import 'portfolio_gallery_screen.dart';
import 'track_booking_screen.dart';

class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({super.key});

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  int _step = 0;
  bool _busy = false;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  final _promo = TextEditingController();

  List<String> _serviceIds = [];
  String? _primaryServiceId;
  final List<String> _extraServiceIds = [];
  String? _employeeId;
  String? _chairId;
  String? _favoriteEmployeeId;
  bool _saveAsFavorite = false;
  DateTime? _date;
  DateTime? _slot;
  bool _outOfHours = false;
  bool _recurring = false;

  String? _appliedCode;
  double _appliedDiscount = 0;

  List<DateTime> _slots = [];

  @override
  void initState() {
    super.initState();
    _loadFavoriteBarber();
  }

  Future<void> _loadFavoriteBarber() async {
    final shopId = ShopManager.shopId;
    if (shopId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final favorite = prefs.getString('favorite_barber_$shopId');
    if (!mounted || favorite == null) return;
    final exists = context.read<ShopProvider>().activeEmployees.any((e) => e.id == favorite);
    if (exists) {
      setState(() {
        _favoriteEmployeeId = favorite;
        _employeeId = favorite;
      });
      _recomputeSlots();
    }
  }

  Future<void> _saveFavoriteBarber() async {
    if (!_saveAsFavorite || _employeeId == null) return;
    final shopId = ShopManager.shopId;
    if (shopId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favorite_barber_$shopId', _employeeId!);
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

  List<Appointment> _busyAppointments() =>
      context.read<AppointmentProvider>().appointments;

  void _recomputeSlots() {
    final shop = context.read<ShopProvider>();
    if (_employeeId == null || _date == null) return;
    final employee = shop.employeeById(_employeeId!);
    if (employee == null) return;
    setState(() {
      _slots = generateSlots(
        employee: employee,
        appointments: _busyAppointments(),
        day: _date!,
        durationMinutes: _totalDuration,
      );
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final settings = context.read<ShopProvider>().settings!;
    final max = now.add(Duration(days: settings.maxAdvanceDays));
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

  Future<void> _pickOutOfHoursTime() async {
    final now = DateTime.now();
    final settings = context.read<ShopProvider>().settings!;
    final max = now.add(Duration(days: settings.maxAdvanceDays));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: max,
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 11, minute: 0),
    );
    if (pickedTime == null) return;
    setState(() {
      _date = DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
          pickedTime.hour, pickedTime.minute);
      _slot = _date;
    });
  }

  void _applyPromo() {
    final discounts = context.read<DiscountProvider>();
    final total = _totalAmount;
    final d = discounts.findActiveByCode(_promo.text);
    if (d != null && d.isUsable(total)) {
      final amount = computeDiscount(d, total);
      setState(() {
        _appliedCode = d.code;
        _appliedDiscount = amount;
      });
      showSnack(context, t(context).promoApplied);
    } else {
      showSnack(context, t(context).invalidCode);
    }
  }

  String _normalizePhone(String value) => value.replaceAll(RegExp(r'[^0-9+]'), '');

  double get _totalAmount {
    final shop = context.read<ShopProvider>();
    return shop.services
        .where((s) => _serviceIds.contains(s.id))
        .fold(0.0, (sum, s) => sum + s.price);
  }

  Future<void> _submit() async {
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
    if (_primaryServiceId == null) {
      showSnack(context, t(context).selectServicesFirst);
      return;
    }
    if (_slot == null) {
      showSnack(context, t(context).selectTime);
      return;
    }

    setState(() => _busy = true);
    final shop = context.read<ShopProvider>();
    final settings = shop.settings!;
    final provider = context.read<AppointmentProvider>();
    final navigator = Navigator.of(context);
    await _saveFavoriteBarber();
    final shopId = ShopManager.shopId!;

    final selected = shop.services
        .where((s) => _serviceIds.contains(s.id))
        .toList();
    final total = selected.fold(0.0, (sum, s) => sum + s.price);
    final deposit = computeDeposit(settings, selected, total);
    final payable = total - _appliedDiscount;

    final reference = FirestoreService.genReference();

    if (_outOfHours) {
      final request = UnavailabilityRequest(
        id: newAppointmentId(),
        customerName: _name.text.trim(),
        customerPhone: _phone.text.trim(),
        serviceIds: _serviceIds,
        requestedStart: _slot!,
        requestedEnd: _slot!.add(Duration(minutes: _totalDuration)),
        reason: _notes.text.trim(),
        createdAt: DateTime.now(),
      );
      await provider.addRequest(request, shopId);
      if (!mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            reference: reference,
            isRequest: true,
          ),
        ),
      );
      return;
    }

    final status = settings.autoConfirm
        ? AppointmentStatus.confirmed
        : AppointmentStatus.requested;
    final occurrences = _recurring
        ? expandWeeklySeries(first: _slot!, count: 4)
        : <DateTime>[_slot!];
    if (occurrences.any((occ) => provider.hasConflict(
          employeeId: _employeeId!,
          chairId: _chairId,
          start: occ,
          end: occ.add(Duration(minutes: _totalDuration)),
        ))) {
      setState(() => _busy = false);
      if (mounted) {
        showSnack(context, FeatureLabels.text(context,
            'هذا الحلاق أو الكرسي محجوز في الوقت المختار.',
            'This barber or chair is already booked at that time.'));
      }
      return;
    }

    if (_recurring) {
      final seriesId = newAppointmentId();
      for (final occ in occurrences) {
        final appt = Appointment(
          id: newAppointmentId(),
          shopId: shopId,
          reference: reference,
          customerId: _normalizePhone(_phone.text),
          customerName: _name.text.trim(),
          customerPhone: _phone.text.trim(),
          customerEmail: _email.text.trim(),
          employeeId: _employeeId!,
          chairId: _chairId,
          serviceIds: _serviceIds,
          startTime: occ,
          endTime: occ.add(Duration(minutes: _totalDuration)),
          status: status,
          paymentStatus:
              deposit > 0 ? PaymentStatus.depositPaid : PaymentStatus.unpaid,
          totalAmount: payable,
          depositAmount: deposit,
          discountCode: _appliedCode,
          discountAmount: _appliedDiscount,
          notes: _notes.text.trim(),
          recurring: true,
          seriesId: seriesId,
          createdById: FirebaseAuth.instance.currentUser?.uid,
          createdAt: DateTime.now(),
        );
        await provider.add(appt, shopId);
        await ReminderService.instance.scheduleLocalReminders(settings, appt);
      }
    } else {
      final appt = Appointment(
        id: newAppointmentId(),
        shopId: shopId,
        reference: reference,
        customerId: _normalizePhone(_phone.text),
        customerName: _name.text.trim(),
        customerPhone: _phone.text.trim(),
        customerEmail: _email.text.trim(),
            employeeId: _employeeId!,
            chairId: _chairId,
            serviceIds: _serviceIds,
        startTime: _slot!,
        endTime: _slot!.add(Duration(minutes: _totalDuration)),
        status: status,
        paymentStatus:
            deposit > 0 ? PaymentStatus.depositPaid : PaymentStatus.unpaid,
        totalAmount: payable,
        depositAmount: deposit,
        discountCode: _appliedCode,
        discountAmount: _appliedDiscount,
        notes: _notes.text.trim(),
        recurring: false,
        createdById: FirebaseAuth.instance.currentUser?.uid,
        createdAt: DateTime.now(),
      );
      await provider.add(appt, shopId);
      await ReminderService.instance.scheduleLocalReminders(settings, appt);
    }

    await NotificationService.instance.show(
      'تم إنشاء الحجز',
      'المرجع: $reference',
    );

    if (_appliedCode != null) {
      if (!mounted) return;
      final discounts = context.read<DiscountProvider>();
      final d = discounts.findActiveByCode(_appliedCode!);
      if (d != null) {
        await discounts.recordUsage(d.id, shopId);
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BookingSuccessScreen(
          reference: reference,
          startTime: _slot,
          endTime: _slot!.add(Duration(minutes: _totalDuration)),
          services: selected,
          totalAmount: payable,
          depositAmount: deposit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final settings = shop.settings;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final primary = parseHexColor(settings.primaryColorHex);
    final accent = parseHexColor(settings.accentColorHex);

    return Scaffold(
      body: Theme(
        data: buildAppTheme(primary: primary, accent: accent),
        child: SafeArea(
          child: Column(
            children: [
              _header(settings),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _stepIndicator(context),
                    const SizedBox(height: 12),
                    _buildStep(context, settings, accent),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
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
                              if (_step == 3) {
                                _submit();
                              } else {
                                setState(() => _step++);
                              }
                            },
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_step == 3
                              ? t(context).confirmBooking
                              : t(context).next),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(settings) {
    final feedback = context.watch<FeedbackProvider>();
    final avg = feedback.averageRating;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: parseHexColor(settings.primaryColorHex),
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (settings.logoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    settings.logoUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _headerIcon(),
                  ),
                )
              else
                _headerIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.shopName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                    if (settings.about.isNotEmpty)
                      Text(
                        settings.about,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: FeatureLabels.text(context, 'استعراض الأعمال', 'Our work'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PortfolioGalleryScreen()),
                ),
                icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
              ),
              IconButton(
                tooltip: t(context).trackBooking,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TrackBookingScreen()),
                ),
                icon: const Icon(Icons.receipt_long_rounded,
                    color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (settings.showRatings)
                _ratingChip(context, avg),
              const SizedBox(width: 8),
              _statusChip(settings),
            ],
          ),
          if (settings.policies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  builder: (_) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t(context).policies,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        for (final p in settings.policies)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    size: 18, color: Color(0xFF059669)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(p)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                icon: const Icon(Icons.article_outlined,
                    color: Colors.white, size: 16),
                label: Text(
                  t(context).policies,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9), fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerIcon() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.content_cut_rounded,
            color: Colors.white, size: 26),
      );

  Widget _ratingChip(BuildContext context, double avg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 4),
          Text(
            avg > 0 ? avg.toStringAsFixed(1) : '0.0',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(settings) {
    final day = DateTime.now().weekday;
    final slots = settings.workingHours[day] ?? const [];
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    final open = slots.any((s) =>
        minutes >= s.startMinutes && minutes < s.endMinutes);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (open ? Colors.greenAccent : Colors.redAccent)
            .withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        open ? t(context).storeOpen : t(context).storeClosed,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _stepIndicator(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        return Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: i <= _step
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _chairSelector(BuildContext context) {
    final chairs = context.watch<BusinessToolsProvider>().chairs.where((c) => c.active).toList();
    if (chairs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(FeatureLabels.text(context, 'الكرسي', 'Chair'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: chairs.map((chair) => ChoiceChip(
            label: Text(chair.name),
            selected: _chairId == chair.id,
            onSelected: (_) => setState(() => _chairId = chair.id),
          )).toList(),
        ),
      ],
    );
  }

  Widget _primaryServiceSelector(
      BuildContext context, List<Service> services, String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(FeatureLabels.text(context, 'الخدمة الأساسية', 'Primary service'),
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: services.map<Widget>((service) {
            final selected = _primaryServiceId == service.id;
            return ChoiceChip(
              avatar: Icon(Icons.content_cut_rounded,
                  size: 16, color: selected ? Colors.white : null),
              label: Text('${service.name} · ${fmtPrice(service.price, currency)}'),
              selected: selected,
              onSelected: (_) => setState(() {
                _extraServiceIds.remove(service.id);
                _primaryServiceId = service.id;
                _serviceIds = [service.id, ..._extraServiceIds];
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _extraServicesSelector(List<Service> services, String currency) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: services.where((s) => s.id != _primaryServiceId).map<Widget>((service) {
        final selected = _extraServiceIds.contains(service.id);
        return FilterChip(
          avatar: const Icon(Icons.add_rounded, size: 16),
          label: Text('${service.name} · ${fmtPrice(service.price, currency)}'),
          selected: selected,
          onSelected: (value) => setState(() {
            if (value) {
              _extraServiceIds.add(service.id);
            } else {
              _extraServiceIds.remove(service.id);
            }
            _serviceIds = [
              if (_primaryServiceId != null) _primaryServiceId!,
              ..._extraServiceIds,
            ];
          }),
        );
      }).toList(),
    );
  }

  Widget _buildStep(BuildContext context, settings, Color accent) {
    final shop = context.watch<ShopProvider>();
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(t(context).chooseServices),
            const SizedBox(height: 10),
              _primaryServiceSelector(context, shop.activeServices, settings.currency),
              if (_primaryServiceId != null) ...[
                const SizedBox(height: 18),
                _title(FeatureLabels.text(context, 'الخدمات الإضافية', 'Additional services')),
                const SizedBox(height: 6),
                Text(
                  FeatureLabels.text(context, 'أضف خدمات أخرى إلى نفس الموعد لزيادة قيمة الحجز.', 'Add more services to the same appointment.'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                _extraServicesSelector(shop.activeServices, settings.currency),
              ],
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(t(context).chooseBarber),
            const SizedBox(height: 10),
            if (_favoriteEmployeeId != null && shop.employeeById(_favoriteEmployeeId!) != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ActionChip(
                  avatar: const Icon(Icons.star_rounded, color: Colors.amber),
                  label: Text('${FeatureLabels.text(context, 'الحلاق المفضل', 'Favorite barber')}: ${shop.employeeById(_favoriteEmployeeId!)!.name}'),
                  onPressed: () {
                    setState(() => _employeeId = _favoriteEmployeeId);
                    _recomputeSlots();
                  },
                ),
              ),
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
                    setState(() => _employeeId = e.id);
                    _recomputeSlots();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            _chairSelector(context),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.star_outline_rounded),
              title: Text(FeatureLabels.text(context, 'حفظ هذا الحلاق كمفضل', 'Save this barber as favorite')),
              subtitle: Text(FeatureLabels.text(context, 'سيتم اختياره تلقائيًا في الحجز القادم', 'He will be selected automatically next time')),
              value: _saveAsFavorite,
              onChanged: (v) => setState(() => _saveAsFavorite = v),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(t(context).chooseDateTime),
            const SizedBox(height: 10),
            if (settings.allowOutOfHours)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t(context).outOfHours),
                subtitle: Text(t(context).outOfHoursHint),
                value: _outOfHours,
                onChanged: (v) => setState(() {
                  _outOfHours = v;
                  _slot = null;
                }),
              ),
            const SizedBox(height: 6),
            if (_outOfHours) ...[
              OutlinedButton.icon(
                onPressed: _pickOutOfHoursTime,
                icon: const Icon(Icons.schedule_rounded),
                label: Text(_slot == null
                    ? t(context).selectTime
                    : DateFormat('EEEE, d MMMM yyyy - HH:mm')
                        .format(_slot!)),
              ),
            ] else ...[
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
                contentPadding: EdgeInsets.zero,
                title: Text(t(context).toggleRecurring),
                value: _recurring,
                onChanged: (v) => setState(() => _recurring = v),
              ),
            ],
          ],
        );
      default:
        final selected = shop.services
            .where((s) => _serviceIds.contains(s.id))
            .toList();
        final total = selected.fold(0.0, (sum, s) => sum + s.price);
        final deposit = computeDeposit(settings, selected, total);
        final payable = total - _appliedDiscount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(t(context).yourDetails),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: t(context).name,
                  prefixIcon: const Icon(Icons.person_outline_rounded)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: t(context).phone,
                  prefixIcon: const Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                  labelText: '${t(context).email} ${t(context).optional}',
                  prefixIcon: const Icon(Icons.mail_outline_rounded)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: t(context).customerNotes,
                  prefixIcon: const Icon(Icons.notes_rounded)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promo,
                    decoration: InputDecoration(
                        labelText: t(context).applyCode,
                        prefixIcon: const Icon(Icons.local_offer_outlined)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _applyPromo,
                  child: Text(t(context).applyCode),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final s in selected)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(s.name,
                                    style: const TextStyle(fontSize: 14))),
                            Text(fmtPrice(s.price, settings.currency)),
                          ],
                        ),
                      ),
                    const Divider(height: 16),
                    if (_appliedDiscount > 0)
                      _sumRow(
                          t(context).discounts, '-${fmtPrice(_appliedDiscount, settings.currency)}'),
                    _sumRow(t(context).totalDue, fmtPrice(payable, settings.currency)),
                    if (deposit > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          t(context).depositNote(fmtPrice(deposit, settings.currency)),
                          style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (settings.cancelFreeHours > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          t(context).cancelPolicyNote('${settings.cancelFreeHours}'),
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _sumRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _title(String text) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
    );
  }
}
