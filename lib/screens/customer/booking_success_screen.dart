import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/strings.dart';
import '../../models/appointment.dart';
import '../../models/service.dart';
import '../../providers/shop_provider.dart';
import '../../services/calendar_service.dart';
import '../../services/shop_manager.dart';
import '../../theme/app_theme.dart';

class BookingSuccessScreen extends StatelessWidget {
  final String reference;
  final bool isRequest;
  final DateTime? startTime;
  final DateTime? endTime;
  final List<Service>? services;
  final double totalAmount;
  final double depositAmount;

  const BookingSuccessScreen({
    super.key,
    required this.reference,
    this.isRequest = false,
    this.startTime,
    this.endTime,
    this.services,
    this.totalAmount = 0,
    this.depositAmount = 0,
  });

  Appointment get _appt => Appointment(
        id: reference,
        shopId: ShopManager.shopId ?? '',
        reference: reference,
        customerName: 'Customer',
        customerPhone: '',
        employeeId: '',
        serviceIds: services?.map((s) => s.id).toList() ?? const [],
        startTime: startTime ?? DateTime.now(),
        endTime: endTime ?? (startTime ?? DateTime.now()),
        createdAt: DateTime.now(),
      );

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final settings = shop.settings;
    final accent = parseHexColor(settings?.accentColorHex ?? '0xFF2563EB');

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: isRequest
                        ? Colors.orange.withOpacity(0.12)
                        : Colors.green.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRequest
                        ? Icons.schedule_send_rounded
                        : Icons.check_rounded,
                    size: 48,
                    color: isRequest ? Colors.orange : Colors.green,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isRequest
                      ? t(context).requestSubmitted
                      : t(context).bookingSuccess,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  isRequest
                      ? t(context).requestSubmittedHint
                      : t(context).bookingSuccessSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          t(context).bookingReference,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reference,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2),
                        ),
                        if (startTime != null) ...[
                          const Divider(height: 28),
                          Text(
                            '${startTime!.day}/${startTime!.month}/${startTime!.year}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_hhmm(startTime!)} - ${_hhmm(endTime ?? startTime!)}',
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 15),
                          ),
                        ],
                        if (totalAmount > 0) ...[
                          const Divider(height: 28),
                          Text(
                            '${t(context).totalDue}: ${fmtPrice(totalAmount, settings?.currency ?? 'SAR')}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ],
                        if (depositAmount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${t(context).deposit}: ${fmtPrice(depositAmount, settings?.currency ?? 'SAR')}',
                              style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (!isRequest && startTime != null && services != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final s = settings!;
                            await CalendarService.instance.openGoogleCalendar(
                                _appt, s, services!);
                          },
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(t(context).addToCalendar),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final s = settings!;
                            await CalendarService.instance
                                .exportIcs(_appt, s, services!);
                          },
                          icon: const Icon(Icons.download_rounded),
                          label: Text(t(context).exportIcs),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if (settings?.phone.isNotEmpty ?? false)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Share.share(
                        t(context).shareTextDefault(
                            '${startTime?.day}/${startTime?.month}',
                            _bookingLink(settings),
                            settings!.shopName),
                      );
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: Text(t(context).shareBooking),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  child: Text(t(context).done),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _bookingLink(settings) => 'https://barberbook.app/'
      '${settings.slug.isEmpty ? 'book' : settings.slug}';
}
