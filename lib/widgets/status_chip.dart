import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/enums.dart';

Color statusColor(AppointmentStatus s) => switch (s) {
      AppointmentStatus.requested => Colors.orange,
      AppointmentStatus.confirmed => Colors.blue,
      AppointmentStatus.completed => Colors.green,
      AppointmentStatus.cancelled => Colors.grey,
      AppointmentStatus.noShow => Colors.red,
    };

String statusLabel(BuildContext context, AppointmentStatus s) => switch (s) {
      AppointmentStatus.requested => t(context).requested,
      AppointmentStatus.confirmed => t(context).confirmed,
      AppointmentStatus.completed => t(context).completed,
      AppointmentStatus.cancelled => t(context).cancelled,
      AppointmentStatus.noShow => t(context).noShow,
    };

class StatusChip extends StatelessWidget {
  final AppointmentStatus status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusLabel(context, status),
        style: TextStyle(
          color: c,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
