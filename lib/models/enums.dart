enum AppointmentStatus { requested, confirmed, completed, cancelled, noShow }

enum PaymentStatus { unpaid, depositPaid, paid }

extension AppointmentStatusExt on AppointmentStatus {
  bool canTransitionTo(AppointmentStatus next) {
    switch (this) {
      case AppointmentStatus.requested:
        return next == AppointmentStatus.confirmed ||
            next == AppointmentStatus.completed ||
            next == AppointmentStatus.cancelled ||
            next == AppointmentStatus.noShow;
      case AppointmentStatus.confirmed:
        return next == AppointmentStatus.completed ||
            next == AppointmentStatus.cancelled ||
            next == AppointmentStatus.noShow;
      case AppointmentStatus.completed:
        return false;
      case AppointmentStatus.cancelled:
        return false;
      case AppointmentStatus.noShow:
        return false;
    }
  }
}

extension AppointmentStatusX on AppointmentStatus {
  String get name => toString().split('.').last;
}

extension PaymentStatusX on PaymentStatus {
  String get name => toString().split('.').last;
}
