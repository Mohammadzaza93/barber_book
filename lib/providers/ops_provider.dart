import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/activity_log.dart';
import '../services/activity_log_service.dart';
import '../services/backup_service.dart';
import '../services/shop_manager.dart';

class OpsProvider extends ChangeNotifier {
  final _logApi = ActivityLogService.instance;
  final _backupApi = BackupService.instance;
  final List<StreamSubscription> _subs = [];

  String? shopId;
  List<ActivityLogEntry> logs = [];
  List<BackupMeta> backups = [];
  bool loading = false;
  bool backingUp = false;
  String? lastError;

  void bind(String? id) {
    if (id == shopId) return;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    shopId = id;
    logs = [];
    backups = [];
    if (id == null || id.isEmpty) {
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    _subs.add(_logApi.watch(id).listen((list) {
      logs = list;
      loading = false;
      notifyListeners();
    }));
    _subs.add(_backupApi.watch(id).listen((list) {
      backups = list;
      notifyListeners();
    }));
  }

  Future<void> log({
    required String action,
    required String entity,
    String entityId = '',
    String summary = '',
    String actorUid = '',
    String actorName = '',
    Map<String, dynamic> meta = const {},
  }) {
    final sid = shopId ?? ShopManager.shopId ?? '';
    return _logApi.log(
      shopId: sid,
      action: action,
      entity: entity,
      entityId: entityId,
      summary: summary,
      actorUid: actorUid,
      actorName: actorName,
      meta: meta,
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
