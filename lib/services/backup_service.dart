import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_log.dart';
import '../models/appointment.dart';
import '../models/employee.dart';
import '../models/finance/finance_models.dart';
import '../models/service.dart';
import 'activity_log_service.dart';

/// نسخ احتياطي لبيانات الصالون — مجاني ضمن حصص Firebase.
///
/// - يكتب **ملخصاً** في Firestore (`backups`)
/// - يحاول رفع JSON كامل إلى Storage إن أمكن
/// - يذكّر تلقائياً كل 24 ساعة عند فتح التطبيق
class BackupService {
  BackupService._();
  static final instance = BackupService._();

  static const _prefsKeyPrefix = 'last_backup_at_';

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String shopId) =>
      _db.collection('shops').doc(shopId).collection('backups');

  Future<DateTime?> lastBackupAt(String shopId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefsKeyPrefix$shopId');
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _markLocal(String shopId, DateTime at) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefsKeyPrefix$shopId', at.toIso8601String());
    } catch (_) {}
  }

  /// إن مرّ أكثر من [interval] منذ آخر نسخة → ينفّذ نسخة تلقائية.
  Future<BackupMeta?> maybeAutoBackup({
    required String shopId,
    required String actorUid,
    required String actorName,
    required List<Appointment> appointments,
    required List<Employee> employees,
    required List<Service> services,
    required List<DailyFinanceEntry> financeEntries,
    Duration interval = const Duration(hours: 24),
  }) async {
    final last = await lastBackupAt(shopId);
    if (last != null && DateTime.now().difference(last) < interval) {
      return null;
    }
    return createBackup(
      shopId: shopId,
      actorUid: actorUid,
      actorName: actorName,
      trigger: 'auto',
      appointments: appointments,
      employees: employees,
      services: services,
      financeEntries: financeEntries,
    );
  }

  Future<BackupMeta> createBackup({
    required String shopId,
    required String actorUid,
    required String actorName,
    String trigger = 'manual',
    required List<Appointment> appointments,
    required List<Employee> employees,
    required List<Service> services,
    required List<DailyFinanceEntry> financeEntries,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    final payload = <String, dynamic>{
      'version': 1,
      'shopId': shopId,
      'exportedAt': now.toIso8601String(),
      'trigger': trigger,
      'appointments': appointments.map((a) => a.toMap()..['id'] = a.id).toList(),
      'employees': employees.map((e) => e.toMap()..['id'] = e.id).toList(),
      'services': services.map((s) => s.toMap()..['id'] = s.id).toList(),
      'financeEntries':
          financeEntries.map((e) => e.toMap()..['id'] = e.id).toList(),
    };

    final jsonStr = jsonEncode(payload);
    final bytes = utf8.encode(jsonStr);
    String? storagePath;

    try {
      storagePath = 'shops/$shopId/backups/$id.json';
      await FirebaseStorage.instance
          .ref(storagePath)
          .putString(jsonStr, format: PutStringFormat.raw);
    } catch (_) {
      storagePath = null; // نكتفي بالملخص في Firestore
    }

    final meta = BackupMeta(
      id: id,
      createdAt: now,
      createdByUid: actorUid,
      createdByName: actorName,
      trigger: trigger,
      appointmentsCount: appointments.length,
      employeesCount: employees.length,
      servicesCount: services.length,
      financeEntriesCount: financeEntries.length,
      storagePath: storagePath,
      payloadBytes: bytes.length,
      note: storagePath != null
          ? 'نسخة كاملة في Storage'
          : 'ملخص فقط (تعذّر رفع الملف)',
    );

    await _col(shopId).doc(id).set(meta.toMap());
    await _markLocal(shopId, now);

    await ActivityLogService.instance.log(
      shopId: shopId,
      action: 'backup',
      entity: 'backup',
      entityId: id,
      summary: trigger == 'auto'
          ? 'نسخ احتياطي تلقائي'
          : 'نسخ احتياطي يدوي',
      actorUid: actorUid,
      actorName: actorName,
      meta: {
        'bytes': bytes.length,
        'storage': storagePath != null,
      },
    );

    return meta;
  }

  Stream<List<BackupMeta>> watch(String shopId, {int limit = 50}) {
    return _col(shopId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => BackupMeta.fromMap(d.id, d.data())).toList(),
        );
  }
}
