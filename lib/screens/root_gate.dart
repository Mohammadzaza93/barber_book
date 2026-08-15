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

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!firebaseReady) {
      return const ConfigErrorScreen();
    }

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
    context.read<BusinessToolsProvider>().bind(shopId);
    context.read<DiscountProvider>().bind(shopId);
    context.read<ExpenseProvider>().bind(shopId);
    context.read<FeedbackProvider>().bind(shopId);

    return const AdminHomeScreen();
  }
}
