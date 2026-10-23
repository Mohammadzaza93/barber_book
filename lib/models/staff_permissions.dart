class StaffPermissions {
  final bool appointments;
  final bool services;
  final bool staff;
  final bool discounts;
  final bool expenses;
  final bool feedback;
  final bool reports;
  final bool settings;
  final bool businessTools;
  final bool outOfHours;
  final bool payments;
  final bool finance;

  const StaffPermissions({
    this.appointments = true,
    this.services = false,
    this.staff = false,
    this.discounts = false,
    this.expenses = false,
    this.feedback = false,
    this.reports = false,
    this.settings = false,
    this.businessTools = false,
    this.outOfHours = false,
    this.payments = true,
    this.finance = false,
  });

  static const StaffPermissions all = StaffPermissions(
    appointments: true,
    services: true,
    staff: true,
    discounts: true,
    expenses: true,
    feedback: true,
    reports: true,
    settings: true,
    businessTools: true,
    outOfHours: true,
    payments: true,
    finance: true,
  );

  static const StaffPermissions minimal = StaffPermissions(
    appointments: true,
    payments: true,
    finance: false,
  );

  Map<String, dynamic> toMap() => {
        'appointments': appointments,
        'services': services,
        'staff': staff,
        'discounts': discounts,
        'expenses': expenses,
        'feedback': feedback,
        'reports': reports,
        'settings': settings,
        'businessTools': businessTools,
        'outOfHours': outOfHours,
        'payments': payments,
        'finance': finance,
      };

  factory StaffPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return StaffPermissions.minimal;
    return StaffPermissions(
      appointments: map['appointments'] == true,
      services: map['services'] == true,
      staff: map['staff'] == true,
      discounts: map['discounts'] == true,
      expenses: map['expenses'] == true,
      feedback: map['feedback'] == true,
      reports: map['reports'] == true,
      settings: map['settings'] == true,
      businessTools: map['businessTools'] == true,
      outOfHours: map['outOfHours'] == true,
      payments: map['payments'] == true,
      finance: map['finance'] == true,
    );
  }

  StaffPermissions copyWith({
    bool? appointments,
    bool? services,
    bool? staff,
    bool? discounts,
    bool? expenses,
    bool? feedback,
    bool? reports,
    bool? settings,
    bool? businessTools,
    bool? outOfHours,
    bool? payments,
    bool? finance,
  }) {
    return StaffPermissions(
      appointments: appointments ?? this.appointments,
      services: services ?? this.services,
      staff: staff ?? this.staff,
      discounts: discounts ?? this.discounts,
      expenses: expenses ?? this.expenses,
      feedback: feedback ?? this.feedback,
      reports: reports ?? this.reports,
      settings: settings ?? this.settings,
      businessTools: businessTools ?? this.businessTools,
      outOfHours: outOfHours ?? this.outOfHours,
      payments: payments ?? this.payments,
      finance: finance ?? this.finance,
    );
  }
}