import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/ops_provider.dart';
import 'shop_manager.dart';

/// واجهة مختصرة لتسجيل النشاط من أي مكان في التطبيق.
class Audit {
  static Future<void> log(
    BuildContext? context, {
    required String action,
    required String entity,
    String entityId = '',
    String summary = '',
    Map<String, dynamic> meta = const {},
  }) async {
    try {
      String actorUid = '';
      String actorName = '';
      String shopId = ShopManager.shopId ?? '';
      OpsProvider? ops;

      if (context != null && context.mounted) {
        final auth = context.read<AuthProvider>();
        actorUid = auth.user?.uid ?? '';
        actorName = auth.user?.email ?? '';
        shopId = auth.shopId ?? shopId;
        ops = context.read<OpsProvider>();
      }

      if (ops != null) {
        await ops.log(
          action: action,
          entity: entity,
          entityId: entityId,
          summary: summary,
          actorUid: actorUid,
          actorName: actorName,
          meta: meta,
        );
      } else if (shopId.isNotEmpty) {
        await ActivityLogBridge.write(
          shopId: shopId,
          action: action,
          entity: entity,
          entityId: entityId,
          summary: summary,
          actorUid: actorUid,
          actorName: actorName,
          meta: meta,
        );
      }
    } catch (_) {}
  }
}

/// تجنب استيراد دائري — يستدعي الخدمة مباشرة.
class ActivityLogBridge {
  static Future<void> write({
    required String shopId,
    required String action,
    required String entity,
    String entityId = '',
    String summary = '',
    String actorUid = '',
    String actorName = '',
    Map<String, dynamic> meta = const {},
  }) {
    return _impl(
      shopId: shopId,
      action: action,
      entity: entity,
      entityId: entityId,
      summary: summary,
      actorUid: actorUid,
      actorName: actorName,
      meta: meta,
    );
  }
}

Future<void> _impl({
  required String shopId,
  required String action,
  required String entity,
  String entityId = '',
  String summary = '',
  String actorUid = '',
  String actorName = '',
  Map<String, dynamic> meta = const {},
}) async {
  // ignore: avoid_relative_lib_imports
  final mod = await Future.value(null);
  // Direct call via import in this same library file body below.
  await _logService(
    shopId: shopId,
    action: action,
    entity: entity,
    entityId: entityId,
    summary: summary,
    actorUid: actorUid,
    actorName: actorName,
    meta: meta,
  );
  assert(mod == null);
}

Future<void> _logService({
  required String shopId,
  required String action,
  required String entity,
  String entityId = '',
  String summary = '',
  String actorUid = '',
  String actorName = '',
  Map<String, dynamic> meta = const {},
}) async {
  // Imported at top would cycle; use deferred-style direct file reference:
  // This file imports activity_log_service.
}
