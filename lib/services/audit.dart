import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/ops_provider.dart';
import 'activity_log_service.dart';
import 'shop_manager.dart';

/// تسجيل نشاط للمراجعة الأمنية — best-effort ولا يوقف العملية الأساسية.
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
      var actorUid = '';
      var actorName = '';
      var shopId = ShopManager.shopId ?? '';

      if (context != null && context.mounted) {
        try {
          final auth = context.read<AuthProvider>();
          actorUid = auth.user?.uid ?? '';
          actorName = auth.user?.email ?? '';
          shopId = auth.shopId ?? shopId;
          final ops = context.read<OpsProvider>();
          await ops.log(
            action: action,
            entity: entity,
            entityId: entityId,
            summary: summary,
            actorUid: actorUid,
            actorName: actorName,
            meta: meta,
          );
          return;
        } catch (_) {
          // fallback below
        }
      }

      if (shopId.isEmpty) return;
      await ActivityLogService.instance.log(
        shopId: shopId,
        action: action,
        entity: entity,
        entityId: entityId,
        summary: summary,
        actorUid: actorUid,
        actorName: actorName,
        meta: meta,
      );
    } catch (_) {}
  }
}
