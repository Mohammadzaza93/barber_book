import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/appointment.dart';
import '../models/booking_settings.dart';
import '../models/service.dart';

class CalendarService {
  CalendarService._();
  static final instance = CalendarService._();

  static String _esc(String s) => s.replaceAll(RegExp(r'[,;]'), ' ');

  static String _utc(DateTime d) {
    final u = d.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}T'
        '${two(u.hour)}${two(u.minute)}00Z';
  }

  String buildIcs(Appointment a, BookingSettings s, List<Service> services) {
    final title = '${s.shopName}: '
        '${services.map((x) => x.name).join(' + ')}';
    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//BarberBook//EN',
      'BEGIN:VEVENT',
      'UID:${a.id}@barberbook',
      'DTSTAMP:${_utc(DateTime.now())}',
      'DTSTART:${_utc(a.startTime)}',
      'DTEND:${_utc(a.endTime)}',
      'SUMMARY:${_esc(title)}',
      'DESCRIPTION:${_esc('Customer: ${a.customerName} - Ref: ${a.reference}')}',
      'LOCATION:${_esc(s.address)}',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
  }

  String googleCalendarUrl(Appointment a, BookingSettings s,
      List<Service> services) {
    final title = '${s.shopName}: '
        '${services.map((x) => x.name).join(' + ')}';
    final dates =
        '${_utc(a.startTime)}/${_utc(a.endTime)}'.replaceAll('T', 'T');
    return Uri.parse('https://calendar.google.com/calendar/render')
        .replace(queryParameters: {
      'action': 'TEMPLATE',
      'text': title,
      'dates': dates.replaceAll('T', 'T'),
      'details': 'Customer: ${a.customerName} - Ref: ${a.reference}',
      'location': s.address,
    }).toString();
  }

  Future<void> openGoogleCalendar(
      Appointment a, BookingSettings s, List<Service> services) async {
    final url = googleCalendarUrl(a, s, services);
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    }
  }

  Future<void> exportIcs(
      Appointment a, BookingSettings s, List<Service> services) async {
    final ics = buildIcs(a, s, services);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${a.reference}.ics');
    await file.writeAsString(ics);
    await Share.shareXFiles([XFile(file.path)],
        subject: '${s.shopName} appointment');
  }
}
