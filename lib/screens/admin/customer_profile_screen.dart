import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../models/customer_profile.dart';
import '../../models/enums.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/customer_insights.dart';
import '../../widgets/empty_state.dart';
import 'customer_editor.dart';

typedef CustomerHistoryLoader = Future<List<Appointment>> Function(
    String phone);

const _monthNames = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// صفحة الزبون: بياناته، ملخصه، تحليل السنة، وسجل الحضور الكامل.
class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    super.key,
    required this.customer,
    this.loader,
  });

  final CustomerProfile customer;

  /// يُستخدم في الاختبارات لتفادي Firestore.
  final CustomerHistoryLoader? loader;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  List<Appointment>? _history;
  bool _loading = false;
  bool _started = false;
  String? _error;
  int _selectedYear = DateTime.now().year;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    final tools = context.read<BusinessToolsProvider>();
    final loader = widget.loader;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = loader != null
          ? await loader(widget.customer.phone)
          : await tools.loadCustomerHistory(widget.customer.phone);
      if (!mounted) return;
      final insights = CustomerInsights.from(list);
      setState(() {
        _history = list;
        _loading = false;
        if (!insights.years.contains(_selectedYear)) {
          _selectedYear = insights.years.isEmpty
              ? DateTime.now().year
              : insights.years.first;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _edit(CustomerProfile customer) async {
    await showCustomerEditor(context, existing: customer);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final shop = context.watch<ShopProvider>();
    final currency = shop.settings?.currency ?? 'SAR';
    final customer =
        tools.customers.where((c) => c.id == widget.customer.id).firstOrNull ??
            widget.customer;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(customer.name.trim().isEmpty ? customer.phone : customer.name),
        actions: [
          IconButton(
            tooltip: 'تعديل البيانات',
            onPressed: () => _edit(customer),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            _CustomerHeader(customer: customer),
            const SizedBox(height: 12),
            if (_loading && _history == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else if (_history != null)
              ..._buildHistory(
                context,
                CustomerInsights.from(_history!),
                shop,
                currency,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHistory(
    BuildContext context,
    CustomerInsights insights,
    ShopProvider shop,
    String currency,
  ) {
    return [
      _SummarySection(insights: insights, currency: currency),
      const SizedBox(height: 12),
      _YearlySection(
        insights: insights,
        year: _selectedYear,
        currency: currency,
        onYearChanged: (year) => setState(() => _selectedYear = year),
      ),
      const SizedBox(height: 12),
      _AttendanceSection(
        insights: insights,
        shop: shop,
        currency: currency,
      ),
    ];
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({required this.customer});

  final CustomerProfile customer;

  @override
  Widget build(BuildContext context) {
    final initial = customer.name.trim().isEmpty
        ? '?'
        : customer.name.trim().characters.first;
    final status = customer.visitCount == 0
        ? 'زيارة أولى'
        : customer.isPermanent
            ? 'زبون دائم'
            : customer.isReturning
                ? 'زبون عائد'
                : 'زيارة واحدة';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  child: Text(
                    initial,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name.trim().isEmpty
                            ? customer.phone
                            : customer.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        customer.phone,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                _Badge(label: status, color: Colors.blueGrey),
              ],
            ),
            if (customer.area.isNotEmpty ||
                customer.email.isNotEmpty ||
                customer.birthDate != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  if (customer.area.isNotEmpty)
                    _Info(
                        icon: Icons.location_on_outlined, text: customer.area),
                  if (customer.email.isNotEmpty)
                    _Info(icon: Icons.email_outlined, text: customer.email),
                  if (customer.birthDate != null)
                    _Info(
                      icon: Icons.cake_outlined,
                      text:
                          DateFormat('yyyy/MM/dd').format(customer.birthDate!),
                    ),
                ],
              ),
            ],
            if (customer.allergies.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '⚠️ حساسية / موانع: ${customer.allergies}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (customer.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                customer.notes,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.insights, required this.currency});

  final CustomerInsights insights;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, String, IconData, Color?)>[
      (
        'الزيارات المكتملة',
        '${insights.visitCount}',
        Icons.event_available_outlined,
        null
      ),
      (
        'إجمالي الإنفاق',
        '${insights.totalSpent.toStringAsFixed(2)} $currency',
        Icons.payments_outlined,
        Colors.green.shade700
      ),
      (
        'متوسط الفاتورة',
        insights.visitCount == 0
            ? '—'
            : '${insights.averageTicket.toStringAsFixed(2)} $currency',
        Icons.receipt_long_outlined,
        null
      ),
      (
        'متوسط الفاصل',
        insights.averageIntervalDays <= 0
            ? '—'
            : '${insights.averageIntervalDays.toStringAsFixed(0)} يوم',
        Icons.repeat_rounded,
        null
      ),
      (
        'آخر زيارة',
        insights.lastVisitAt == null
            ? '—'
            : DateFormat('yyyy/MM/dd').format(insights.lastVisitAt!),
        Icons.history_rounded,
        null
      ),
      (
        'الزيارة القادمة',
        insights.nextAppointmentAt == null
            ? '—'
            : DateFormat('yyyy/MM/dd HH:mm')
                .format(insights.nextAppointmentAt!),
        Icons.upcoming_outlined,
        Colors.blue.shade700
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.insights_outlined,
              title: 'ملخص الزبون',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final metric in metrics)
                      SizedBox(
                        width: width,
                        child: _Metric(
                          label: metric.$1,
                          value: metric.$2,
                          icon: metric.$3,
                          color: metric.$4,
                        ),
                      ),
                  ],
                );
              },
            ),
            if (insights.cancellationCount > 0 || insights.noShowCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                'ملغي: ${insights.cancellationCount} · لم يحضر: '
                '${insights.noShowCount}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            if (insights.topServiceIds.isNotEmpty ||
                insights.topEmployeeIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (insights.topServiceIds.isNotEmpty)
                    _Chip(
                      icon: Icons.content_cut_rounded,
                      label:
                          'الخدمة المفضلة: ${_serviceName(context, insights.topServiceIds.first.id)}',
                    ),
                  if (insights.topEmployeeIds.isNotEmpty)
                    _Chip(
                      icon: Icons.person_outline,
                      label:
                          'الحلاق المفضّل: ${_employeeName(context, insights.topEmployeeIds.first.id)}',
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _serviceName(BuildContext context, String id) =>
      context.read<ShopProvider>().serviceById(id)?.name ?? id;

  String _employeeName(BuildContext context, String id) =>
      context.read<ShopProvider>().employeeById(id)?.name ?? id;
}

class _YearlySection extends StatelessWidget {
  const _YearlySection({
    required this.insights,
    required this.year,
    required this.currency,
    required this.onYearChanged,
  });

  final CustomerInsights insights;
  final int year;
  final String currency;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context) {
    final months = insights.monthsFor(year);
    final total = insights.totalFor(year);
    final maxVisits =
        months.fold<int>(0, (max, m) => m.visits > max ? m.visits : max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _SectionTitle(
                    icon: Icons.calendar_month_outlined,
                    title: 'تحليل السنة',
                  ),
                ),
                DropdownButton<int>(
                  value: insights.years.contains(year)
                      ? year
                      : (insights.years.isEmpty
                          ? DateTime.now().year
                          : insights.years.first),
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final value in insights.years)
                      DropdownMenuItem(value: value, child: Text('$value')),
                  ],
                  onChanged: (value) {
                    if (value != null) onYearChanged(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (total.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'لا يوجد نشاط مسجّل في $year.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              )
            else ...[
              for (final month in months)
                _MonthRow(
                  month: month,
                  maxVisits: maxVisits,
                  currency: currency,
                ),
              const Divider(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'إجمالي السنة',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${total.visits} زيارة',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: Text(
                      '${total.spent.toStringAsFixed(2)} $currency',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.month,
    required this.maxVisits,
    required this.currency,
  });

  final CustomerMonthStat month;
  final int maxVisits;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final fraction = maxVisits == 0 ? 0.0 : month.visits / maxVisits;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              _monthNames[month.month - 1],
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  month.visits > 0 ? Colors.teal : Colors.transparent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              '${month.visits}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    month.visits > 0 ? FontWeight.w700 : FontWeight.w400,
                color: month.visits > 0 ? null : Colors.grey,
              ),
            ),
          ),
          SizedBox(
            width: 86,
            child: Text(
              month.spent == 0 ? '—' : month.spent.toStringAsFixed(0),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                color: month.spent > 0 ? Colors.green.shade700 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({
    required this.insights,
    required this.shop,
    required this.currency,
  });

  final CustomerInsights insights;
  final ShopProvider shop;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final appointments = insights.appointments.reversed.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.fact_check_outlined,
              title: 'سجل الحضور (${appointments.length})',
            ),
            const SizedBox(height: 10),
            if (appointments.isEmpty)
              const EmptyState(
                icon: Icons.event_note_outlined,
                title: 'لا مواعيد مسجّلة بعد',
                subtitle:
                    'سيظهر هنا كل موعد وخدمة استفاد منها الزبون تلقائياً بعد '
                    'إتمام الحجز.',
              )
            else
              for (final appointment in appointments)
                _AppointmentTile(
                  appointment: appointment,
                  serviceNames: appointment.serviceIds
                      .map((id) => shop.serviceById(id)?.name ?? id)
                      .join(' · '),
                  employeeName:
                      shop.employeeById(appointment.employeeId)?.name ?? '',
                  currency: currency,
                ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.appointment,
    required this.serviceNames,
    required this.employeeName,
    required this.currency,
  });

  final Appointment appointment;
  final String serviceNames;
  final String employeeName;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final status = appointment.status;
    final statusColor = switch (status) {
      AppointmentStatus.completed => Colors.green.shade700,
      AppointmentStatus.confirmed => Colors.blue.shade700,
      AppointmentStatus.requested => Colors.orange.shade800,
      AppointmentStatus.cancelled => Colors.grey.shade700,
      AppointmentStatus.noShow => Colors.red.shade700,
    };
    final statusLabel = switch (status) {
      AppointmentStatus.completed => 'مكتمل',
      AppointmentStatus.confirmed => 'مؤكد',
      AppointmentStatus.requested => 'طلب',
      AppointmentStatus.cancelled => 'ملغي',
      AppointmentStatus.noShow => 'لم يحضر',
    };
    final paymentLabel = switch (appointment.paymentStatus) {
      PaymentStatus.paid => 'مدفوع',
      PaymentStatus.depositPaid => 'دفعة مقدمة',
      PaymentStatus.unpaid => 'غير مدفوع',
    };
    final amount = CustomerInsights.amountOf(appointment);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('yyyy/MM/dd · HH:mm')
                      .format(appointment.startTime),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _Badge(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            serviceNames.isEmpty ? 'بدون خدمات مسجّلة' : serviceNames,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (employeeName.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 3),
                          Text(
                            employeeName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 3),
                        Text(
                          '${amount.toStringAsFixed(2)} $currency · $paymentLabel',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: amount > 0
                                ? Colors.green.shade800
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (appointment.rating != null)
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 15, color: Colors.amber),
                    Text(
                      '${appointment.rating}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            const Text(
              'تعذّر تحميل سجل الزبون',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
