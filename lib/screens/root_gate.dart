import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/appointment_provider.dart';
import '../providers/business_tools_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/discount_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/feedback_provider.dart';
import '../providers/shop_provider.dart';
import '../services/firebase_status.dart';
import 'admin/admin_home_screen.dart';
import 'auth/login_screen.dart';
import 'auth/setup_wizard_screen.dart';
import 'config_error_screen.dart';
import 'splash_screen.dart';

/// Owns the auth/session lifecycle for the shop-scoped data providers.
///
/// `AuthProvider` clears its own fields on sign-out, but the data providers
/// keep their Firestore subscriptions and cached tenant data. This gate watches
/// the authenticated uid and, whenever it changes (sign-out, auth expiry, or an
/// account switch), tears every data provider down so a previous session's
/// data can never render in the next one. When a session is present it binds
/// the providers to the resolved shop.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  AuthProvider? _auth;
  String? _lastUid;

  @override
  void initState() {
    super.initState();
    // When Firebase failed to initialise there is no AuthProvider stream to
    // observe, and build() renders the config error screen instead.
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
    // A different (or absent) identity means the previous session is over.
    _resetDataProviders();
  }

  void _resetDataProviders() {
    context.read<ShopProvider>().reset();
    context.read<AppointmentProvider>().reset();
    context.read<BusinessToolsProvider>().reset();
    context.read<DiscountProvider>().reset();
    context.read<ExpenseProvider>().reset();
    context.read<FeedbackProvider>().reset();
  }

  @override
  Widget build(BuildContext context) {
    // Checked before watching AuthProvider so a failed Firebase init shows the
    // config error screen instead of reaching into a missing app instance.
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

    // Bind data providers to the current shop (idempotent per shop).
    final shopId = auth.shopId!;
    context.read<ShopProvider>().bind(shopId);
    context.read<AppointmentProvider>().bind(shopId);
    context.read<BusinessToolsProvider>().bind(shopId, auth.role);
    context.read<DiscountProvider>().bind(shopId);
    context.read<ExpenseProvider>().bind(shopId);
    context.read<FeedbackProvider>().bind(shopId);

    return const AdminHomeScreen();
  }
}
