import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/appointment.dart';
import '../models/booking_settings.dart';
import '../models/service.dart';
import 'notification_service.dart';

class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();

  int _idFor(Appointment a, int hoursBefore) =>
      (a.id.hashCode * 31 + hoursBefore).abs() % 1000000;

  /// Schedules every configured local reminder for one appointment.
  Future<void> scheduleLocalReminders(
      BookingSettings settings, Appointment a) async {
    await cancelLocalReminders(a, settings.reminderTimings);
    if (!settings.remindersEnabled) return;
    for (final hoursBefore in settings.reminderTimings) {
      if (hoursBefore <= 0) continue;
      final when = a.startTime.subtract(Duration(hours: hoursBefore));
      await NotificationService.instance.scheduleReminder(
        _idFor(a, hoursBefore),
        when,
        '${settings.shopName} - ${a.customerName}',
        'Appointment in $hoursBefore hours (${a.reference})',
      );
    }
  }

  Future<void> cancelLocalReminders(Appointment a, [List<int>? timings]) async {
    final ids = timings ?? List<int>.generate(72, (i) => i + 1);
    for (final hoursBefore in ids) {
      await NotificationService.instance.cancel(_idFor(a, hoursBefore));
    }
  }

  String _formatDateTime(DateTime d) {
    final locale = Intl.getCurrentLocale();
    return DateFormat('EEEE, d MMMM yyyy - HH:mm', locale).format(d);
  }

  Uri whatsappUri(
      Appointment a, BookingSettings s, List<Service> services) {
    final text = [
      'مرحباً ${a.customerName}،',
      'تذكير بموعدك في ${s.shopName}',
      'الخدمة: ${services.map((x) => x.name).join(' + ')}',
      'الموعد: ${_formatDateTime(a.startTime)}',
      'الرقم المرجعي: ${a.reference}',
      '',
      'Hello ${a.customerName},',
      'Reminder for your appointment at ${s.shopName}',
      'Service: ${services.map((x) => x.name).join(' + ')}',
      'Time: ${_formatDateTime(a.startTime)}',
      'Reference: ${a.reference}',
    ].join('\n');
    return Uri.parse('https://wa.me/')
        .replace(queryParameters: {
      'phone': a.customerPhone.replaceAll(RegExp(r'[^0-9]'), ''),
      'text': text,
    });
  }

  Uri emailUri(Appointment a, BookingSettings s, List<Service> services) {
    final subject = 'Reminder: Your appointment at ${s.shopName}';
    final body = [
      'Hello ${a.customerName},',
      'This is a reminder for your appointment:',
      'Service: ${services.map((x) => x.name).join(' + ')}',
      'Time: ${_formatDateTime(a.startTime)}',
      'Reference: ${a.reference}',
      '',
      'Regards,',
      s.shopName,
    ].join('\n');
    return Uri(
      scheme: 'mailto',
      path: a.customerEmail.isEmpty ? '' : a.customerEmail,
      queryParameters: {'subject': subject, 'body': body},
    );
  }

  Future<void> sendViaWhatsApp(
      Appointment a, BookingSettings s, List<Service> services) async {
    final uri = whatsappUri(a, s, services);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> sendViaEmail(
      Appointment a, BookingSettings s, List<Service> services) async {
    final uri = emailUri(a, s, services);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
