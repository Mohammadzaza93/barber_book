import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/appointment.dart';
import '../../models/enums.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/shop_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
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

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<AppointmentProvider>().appointments;
    final shop = context.read<ShopProvider>();

    final filtered = appointments.where((a) {
      if (_onlyToday) {
        final now = DateTime.now();
        if (a.startTime.year != now.year ||
            a.startTime.month != now.month ||
            a.startTime.day != now.day) {
          return false;
        }
      }
      if (_onlyPending && a.status != AppointmentStatus.requested) {
        return false;
      }
      if (_filter != null && a.status != _filter) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: Text(t(context).today),
                    selected: _onlyToday,
                    onSelected: (v) => setState(() => _onlyToday = v),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(t(context).pending),
                    selected: _onlyPending,
                    onSelected: (v) => setState(() => _onlyPending = v),
                  ),
                  const SizedBox(width: 8),
                  for (final s in AppointmentStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(statusLabel(context, s)),
                        selected: _filter == s,
                        onSelected: (v) =>
                            setState(() => _filter = v ? s : null),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.event_note_rounded,
                    title: t(context).noAppointments,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final a = filtered[i];
                      return _AppointmentCard(
                        appointment: a,
                        employeeName:
                            shop.employeeById(a.employeeId)?.name ?? '-',
                        serviceNames: a.serviceIds
                            .map((id) => shop.serviceById(id)?.name ?? '')
                            .where((n) => n.isNotEmpty)
                            .join(' + '),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppointmentEditScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(t(context).newAppointment),
        backgroundColor: appBrandGoldDark,
        foregroundColor: Colors.white,
      ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              DateFormat('HH:mm').format(a.startTime),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            Text(
              DateFormat('d MMM').format(a.startTime),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
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
              Text(serviceNames,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              Text(
                '$employeeName · ${a.reference}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
