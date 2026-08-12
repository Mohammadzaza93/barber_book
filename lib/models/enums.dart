enum AppointmentStatus { requested, confirmed, completed, cancelled, noShow }

enum PaymentStatus { unpaid, depositPaid, paid }

extension AppointmentStatusX on AppointmentStatus {
  String get name => toString().split('.').last;
}

extension PaymentStatusX on PaymentStatus {
  String get name => toString().split('.').last;
}
