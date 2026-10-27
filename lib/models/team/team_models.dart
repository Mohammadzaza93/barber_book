/// نماذج إدارة الفريق — مهام، تقييم، حضور، إجازات.

enum TeamTaskStatus { pending, inProgress, done, cancelled }

enum TimeOffType { leave, sick, absence, other }

enum TimeOffStatus { pending, approved, rejected }

class TeamTask {
  final String id;
  final String title;
  final String description;
  final String assigneeId;
  final String assigneeName;
  final String createdById;
  final DateTime createdAt;
  final DateTime? dueDate;
  final TeamTaskStatus status;

  const TeamTask({
    required this.id,
    required this.title,
    this.description = '',
    required this.assigneeId,
    this.assigneeName = '',
    this.createdById = '',
    required this.createdAt,
    this.dueDate,
    this.status = TeamTaskStatus.pending,
  });

  TeamTask copyWith({TeamTaskStatus? status, DateTime? dueDate}) => TeamTask(
        id: id,
        title: title,
        description: description,
        assigneeId: assigneeId,
        assigneeName: assigneeName,
        createdById: createdById,
        createdAt: createdAt,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'assigneeId': assigneeId,
        'assigneeName': assigneeName,
        'createdById': createdById,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'status': status.name,
      };

  factory TeamTask.fromMap(String id, Map<String, dynamic> m) => TeamTask(
        id: id,
        title: (m['title'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        assigneeId: (m['assigneeId'] as String?) ?? '',
        assigneeName: (m['assigneeName'] as String?) ?? '',
        createdById: (m['createdById'] as String?) ?? '',
        createdAt: DateTime.tryParse('${m['createdAt']}') ?? DateTime.now(),
        dueDate: m['dueDate'] != null
            ? DateTime.tryParse('${m['dueDate']}')
            : null,
        status: TeamTaskStatus.values.firstWhere(
          (e) => e.name == m['status'],
          orElse: () => TeamTaskStatus.pending,
        ),
      );
}

class TeamEvaluation {
  final String id;
  final String employeeId;
  final String employeeName;
  final int year;
  final int month; // 0 = سنوي
  final int score; // 1..5
  final String notes;
  final String evaluatorId;
  final DateTime createdAt;

  const TeamEvaluation({
    required this.id,
    required this.employeeId,
    this.employeeName = '',
    required this.year,
    this.month = 0,
    required this.score,
    this.notes = '',
    this.evaluatorId = '',
    required this.createdAt,
  });

  bool get isAnnual => month == 0;

  Map<String, dynamic> toMap() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'year': year,
        'month': month,
        'score': score,
        'notes': notes,
        'evaluatorId': evaluatorId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TeamEvaluation.fromMap(String id, Map<String, dynamic> m) =>
      TeamEvaluation(
        id: id,
        employeeId: (m['employeeId'] as String?) ?? '',
        employeeName: (m['employeeName'] as String?) ?? '',
        year: (m['year'] as num?)?.toInt() ?? DateTime.now().year,
        month: (m['month'] as num?)?.toInt() ?? 0,
        score: ((m['score'] as num?)?.toInt() ?? 3).clamp(1, 5),
        notes: (m['notes'] as String?) ?? '',
        evaluatorId: (m['evaluatorId'] as String?) ?? '',
        createdAt: DateTime.tryParse('${m['createdAt']}') ?? DateTime.now(),
      );
}

class TeamAttendance {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final bool present;
  final double hours;
  final double dayPay; // راتب/أجرة ذلك اليوم إن وُجدت
  final String notes;

  const TeamAttendance({
    required this.id,
    required this.employeeId,
    this.employeeName = '',
    required this.date,
    this.present = true,
    this.hours = 8,
    this.dayPay = 0,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'date': date.toIso8601String(),
        'present': present,
        'hours': hours,
        'dayPay': dayPay,
        'notes': notes,
      };

  factory TeamAttendance.fromMap(String id, Map<String, dynamic> m) =>
      TeamAttendance(
        id: id,
        employeeId: (m['employeeId'] as String?) ?? '',
        employeeName: (m['employeeName'] as String?) ?? '',
        date: DateTime.tryParse('${m['date']}') ?? DateTime.now(),
        present: (m['present'] as bool?) ?? true,
        hours: ((m['hours'] as num?) ?? 8).toDouble(),
        dayPay: ((m['dayPay'] as num?) ?? 0).toDouble(),
        notes: (m['notes'] as String?) ?? '',
      );
}

class TeamTimeOff {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime from;
  final DateTime to;
  final TimeOffType type;
  final TimeOffStatus status;
  final String reason;

  const TeamTimeOff({
    required this.id,
    required this.employeeId,
    this.employeeName = '',
    required this.from,
    required this.to,
    this.type = TimeOffType.leave,
    this.status = TimeOffStatus.pending,
    this.reason = '',
  });

  TeamTimeOff copyWith({TimeOffStatus? status}) => TeamTimeOff(
        id: id,
        employeeId: employeeId,
        employeeName: employeeName,
        from: from,
        to: to,
        type: type,
        status: status ?? this.status,
        reason: reason,
      );

  Map<String, dynamic> toMap() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        'type': type.name,
        'status': status.name,
        'reason': reason,
      };

  factory TeamTimeOff.fromMap(String id, Map<String, dynamic> m) => TeamTimeOff(
        id: id,
        employeeId: (m['employeeId'] as String?) ?? '',
        employeeName: (m['employeeName'] as String?) ?? '',
        from: DateTime.tryParse('${m['from']}') ?? DateTime.now(),
        to: DateTime.tryParse('${m['to']}') ?? DateTime.now(),
        type: TimeOffType.values.firstWhere(
          (e) => e.name == m['type'],
          orElse: () => TimeOffType.leave,
        ),
        status: TimeOffStatus.values.firstWhere(
          (e) => e.name == m['status'],
          orElse: () => TimeOffStatus.pending,
        ),
        reason: (m['reason'] as String?) ?? '',
      );
}

/// قوالب أدوار جاهزة تطبق صلاحيات StaffPermissions.
class TeamRolePreset {
  final String id;
  final String labelAr;
  final String labelEn;

  const TeamRolePreset(this.id, this.labelAr, this.labelEn);

  static const owner = TeamRolePreset('owner', 'مالك', 'Owner');
  static const manager = TeamRolePreset('manager', 'مدير', 'Manager');
  static const barber = TeamRolePreset('barber', 'حلاق', 'Barber');
  static const adminStaff =
      TeamRolePreset('admin_staff', 'موظف إداري', 'Admin staff');

  static const all = [owner, manager, barber, adminStaff];

  static TeamRolePreset fromId(String? id) {
    return all.firstWhere((e) => e.id == id, orElse: () => barber);
  }
}
