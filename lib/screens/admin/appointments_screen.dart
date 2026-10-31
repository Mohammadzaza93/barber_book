import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/appointment.dart';
import '../../models/enums.dart';
import '../../models/shop_time.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/shop_manager.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/live_badge.dart';
import '../../widgets/search_field.dart';
import '../../widgets/status_chip.dart';
import 'appointment_edit_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  AppointmentStatus? _filter;
  bool _onlyToday = false;
  bool _onlyPending = false;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: SearchField(
                    controller: _search,
                    hint: 'بحث: اسم، هاتف، مرجع، خدمة...',
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                const LiveBadge(compact: true),
              ],
            ),
          ),
          _FilterBar(
            onlyToday: _onlyToday,
            onlyPending: _onlyPending,
            filter: _filter,
            onToday: (v) => setState(() => _onlyToday = v),
            onPending: (v) => setState(() => _onlyPending = v),
            onStatus: (s) => setState(() => _filter = s),
          ),
          Expanded(
            child: _AppointmentsList(
              onlyToday: _onlyToday,
              onlyPending: _onlyPending,
              filter: _filter,
              query: _query,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'appointments_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppointmentEditScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(t(context).newAppointment),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.onlyToday,
    required this.onlyPending,
    required this.filter,
    required this.onToday,
    required this.onPending,
    required this.onStatus,
  });

  final bool onlyToday;
  final bool onlyPending;
  final AppointmentStatus? filter;
  final ValueChanged<bool> onToday;
  final ValueChanged<bool> onPending;
  final ValueChanged<AppointmentStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: Text(t(context).today),
              selected: onlyToday,
              onSelected: onToday,
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(t(context).pending),
              selected: onlyPending,
              onSelected: onPending,
            ),
            const SizedBox(width: 8),
            for (final s in AppointmentStatus.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(statusLabel(context, s)),
                  selected: filter == s,
                  onSelected: (v) => onStatus(v ? s : null),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentsList extends StatelessWidget {
  const _AppointmentsList({
    required this.onlyToday,
    required this.onlyPending,
    required this.filter,
    required this.query,
  });

  final bool onlyToday;
  final bool onlyPending;
  final AppointmentStatus? filter;
  final String query;

  @override
  Widget build(BuildContext context) {
    final appointments =
        context.select<AppointmentProvider, List<Appointment>>(
            (p) => p.appointments);
    final shop = context.watch<ShopProvider>();
    final q = query.toLowerCase();

    final filtered = appointments.where((a) {
      if (onlyToday) {
        if (!isSameShopDay(
            a.startTime, DateTime.now(), ShopManager.timezoneOffsetMinutes)) {
          return false;
        }
      }
      if (onlyPending && a.status != AppointmentStatus.requested) {
        return false;
      }
      if (filter != null && a.status != filter) return false;
      if (q.isNotEmpty) {
        final employee = shop.employeeById(a.employeeId)?.name ?? '';
        final services = a.serviceIds
            .map((id) => shop.serviceById(id)?.name ?? id)
            .join(' ');
        final hay = [
          a.customerName,
          a.customerPhone,
          a.reference,
          a.notes,
          employee,
          services,
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.event_note_rounded,
        title: t(context).noAppointments,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final a = filtered[i];
        return _AppointmentCard(
          appointment: a,
          employeeName: shop.employeeById(a.employeeId)?.name ?? '-',
          serviceNames: a.serviceIds
              .map((id) => shop.serviceById(id)?.name ?? '')
              .where((n) => n.isNotEmpty)
              .join(' + '),
        );
      },
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final String employeeName;
  final String serviceNames;
  const _AppointmentCard({
    required this.appointment,
    required this.employeeName,
    required this.serviceNames,
  });

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AppointmentEditScreen(appointment: a),
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('HH:mm').format(a.startTime),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            Text(
              DateFormat('d MMM').format(a.startTime),
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                a.customerName,
                style: const TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            StatusChip(status: a.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(serviceNames),
              Text(
                '$employeeName · ${a.reference}',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            final ap = context.read<AppointmentProvider>();
            final shopId = a.shopId;
            if (shopId.isEmpty) return;
            try {
              if (v == 'noshow') {
                await ap.setStatus(a, AppointmentStatus.noShow, shopId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل: لم يحضر')),
                  );
                }
              } else if (v == 'completed') {
                await ap.setStatus(a, AppointmentStatus.completed, shopId);
              } else if (v == 'cancelled') {
                await ap.setStatus(a, AppointmentStatus.cancelled, shopId);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تعذر التحديث: $e')),
                );
              }
            }
          },
          itemBuilder: (_) => [
            if (a.status != AppointmentStatus.noShow)
              const PopupMenuItem(
                value: 'noshow',
                child: Text('لم يحضر (No-show)'),
              ),
            if (a.status != AppointmentStatus.completed)
              const PopupMenuItem(
                value: 'completed',
                child: Text('تم الحضور'),
              ),
            if (a.status != AppointmentStatus.cancelled)
              const PopupMenuItem(
                value: 'cancelled',
                child: Text('إلغاء'),
              ),
          ],
        ),
      ),
    );
  }
}
