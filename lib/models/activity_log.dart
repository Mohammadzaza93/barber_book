class ActivityLogEntry {
  final String id;
  final String action;
  final String entity;
  final String entityId;
  final String summary;
  final String actorUid;
  final String actorName;
  final DateTime at;
  final Map<String, dynamic> meta;

  const ActivityLogEntry({
    required this.id,
    required this.action,
    required this.entity,
    this.entityId = '',
    this.summary = '',
    this.actorUid = '',
    this.actorName = '',
    required this.at,
    this.meta = const {},
  });

  Map<String, dynamic> toMap() => {
        'action': action,
        'entity': entity,
        'entityId': entityId,
        'summary': summary,
        'actorUid': actorUid,
        'actorName': actorName,
        'at': at.toIso8601String(),
        'meta': meta,
      };

  factory ActivityLogEntry.fromMap(String id, Map<String, dynamic> m) =>
      ActivityLogEntry(
        id: id,
        action: (m['action'] as String?) ?? '',
        entity: (m['entity'] as String?) ?? '',
        entityId: (m['entityId'] as String?) ?? '',
        summary: (m['summary'] as String?) ?? '',
        actorUid: (m['actorUid'] as String?) ?? '',
        actorName: (m['actorName'] as String?) ?? '',
        at: DateTime.tryParse('${m['at']}') ?? DateTime.now(),
        meta: (m['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

class BackupMeta {
  final String id;
  final DateTime createdAt;
  final String createdByUid;
  final String createdByName;
  final String trigger; // auto | manual
  final int appointmentsCount;
  final int employeesCount;
  final int servicesCount;
  final int financeEntriesCount;
  final String? storagePath;
  final int payloadBytes;
  final String note;

  const BackupMeta({
    required this.id,
    required this.createdAt,
    this.createdByUid = '',
    this.createdByName = '',
    this.trigger = 'manual',
    this.appointmentsCount = 0,
    this.employeesCount = 0,
    this.servicesCount = 0,
    this.financeEntriesCount = 0,
    this.storagePath,
    this.payloadBytes = 0,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'createdAt': createdAt.toIso8601String(),
        'createdByUid': createdByUid,
        'createdByName': createdByName,
        'trigger': trigger,
        'appointmentsCount': appointmentsCount,
        'employeesCount': employeesCount,
        'servicesCount': servicesCount,
        'financeEntriesCount': financeEntriesCount,
        'storagePath': storagePath,
        'payloadBytes': payloadBytes,
        'note': note,
      };

  factory BackupMeta.fromMap(String id, Map<String, dynamic> m) => BackupMeta(
        id: id,
        createdAt: DateTime.tryParse('${m['createdAt']}') ?? DateTime.now(),
        createdByUid: (m['createdByUid'] as String?) ?? '',
        createdByName: (m['createdByName'] as String?) ?? '',
        trigger: (m['trigger'] as String?) ?? 'manual',
        appointmentsCount: (m['appointmentsCount'] as num?)?.toInt() ?? 0,
        employeesCount: (m['employeesCount'] as num?)?.toInt() ?? 0,
        servicesCount: (m['servicesCount'] as num?)?.toInt() ?? 0,
        financeEntriesCount: (m['financeEntriesCount'] as num?)?.toInt() ?? 0,
        storagePath: m['storagePath'] as String?,
        payloadBytes: (m['payloadBytes'] as num?)?.toInt() ?? 0,
        note: (m['note'] as String?) ?? '',
      );
}
