import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/appointment_provider.dart';
import '../providers/business_tools_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/discount_provider.dart';
import '../providers/feedback_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/shop_provider.dart';
import '../services/backup_service.dart';
import '../services/firebase_status.dart';
import 'admin/admin_home_screen.dart';
import 'auth/login_screen.dart';
import 'auth/setup_wizard_screen.dart';
import 'config_error_screen.dart';
import 'splash_screen.dart';

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  AuthProvider? _auth;
  String? _lastUid;
  String? _backupScheduledFor;

  @override
  void initState() {
    super.initState();
    if (!firebaseReady) return;
    _auth = context.read<AuthProvider>();
    _lastUid = _auth!.user?.uid;
    _auth!.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final uid = _auth?.user?.uid;
    if (uid == _lastUid) return;
    _lastUid = uid;
    _backupScheduledFor = null;
    _resetDataProviders();
  }

  void _resetDataProviders() {
    context.read<ShopProvider>().reset();
    context.read<AppointmentProvider>().reset();
    context.read<BusinessToolsProvider>().reset();
    context.read<DiscountProvider>().reset();
    context.read<FeedbackProvider>().reset();
    context.read<FinanceProvider>().reset();
  }

  void _scheduleAutoBackup(String shopId) {
    if (_backupScheduledFor == shopId) return;
    _backupScheduledFor = shopId;
    // بعد تحميل أولي قصير حتى تمتلئ القوائم من الـ streams
    Future<void>.delayed(const Duration(seconds: 8), () async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.shopId != shopId) return;
      try {
        await BackupService.instance.maybeAutoBackup(
          shopId: shopId,
          actorUid: auth.user?.uid ?? '',
          actorName: auth.user?.email ?? 'system',
          appointments: context.read<AppointmentProvider>().appointments,
          employees: context.read<ShopProvider>().employees,
          services: context.read<ShopProvider>().services,
          financeEntries: context.read<FinanceProvider>().entries,
        );
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!firebaseReady) {
      return ConfigErrorScreen(message: firebaseError);
    }

    final auth = context.watch<AuthProvider>();

    if (auth.initializing) {
      return const SplashScreen();
    }

    if (auth.user == null) {
      return const LoginScreen();
    }

    if (auth.shopId == null) {
      return const SetupWizardScreen();
    }

    final shopId = auth.shopId!;
    context.read<ShopProvider>().bind(shopId);
    context.read<AppointmentProvider>().bind(shopId);
    context.read<BusinessToolsProvider>().bind(shopId, auth.role);
    context.read<DiscountProvider>().bind(shopId);
    context.read<FeedbackProvider>().bind(shopId);

    _scheduleAutoBackup(shopId);

    return const AdminHomeScreen();
  }
}
