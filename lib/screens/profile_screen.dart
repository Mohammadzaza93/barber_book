import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/business_tools_provider.dart';
import '../providers/discount_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/feedback_provider.dart';
import '../providers/language_provider.dart';
import '../providers/shop_provider.dart';
import '../services/auth_service.dart';
import '../services/shop_manager.dart';
import '../widgets/confirm.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final lang = context.watch<LanguageProvider>();
    final auth = context.read<AuthProvider>();
    final settings = shop.settings;

    return Scaffold(
      appBar: AppBar(title: Text(t(context).profile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.storefront_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings?.shopName ?? 'BarberBook',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          auth.user?.email ?? '',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(t(context).language),
                  subtitle: Text(lang.isArabic
                      ? t(context).arabic
                      : t(context).english),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => lang.setLocale(
                    lang.isArabic ? const Locale('en') : const Locale('ar'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.password_rounded),
                  title: Text(t(context).changePassword),
                  onTap: () => _changePassword(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(t(context).appVersion),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: t(context).logoutConfirm,
                  confirmText: t(context).logout,
                  destructive: true);
              if (!ok || !context.mounted) return;
              await _signOut(context);
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.logout_rounded),
            label: Text(t(context).logout),
          ),
        ],
      ),
    );
  }

  /// Signs out and fully tears down the previous session.
  ///
  /// `RootGate` is the `home:` route, so any screen pushed on top of it (this
  /// one included) survives a plain `signOut()` and would keep rendering the old
  /// shop's data over the login screen. Popping to the first route and clearing
  /// every shop-scoped provider plus the cached favourite barber closes that.
  Future<void> _signOut(BuildContext context) async {
    // Everything that needs a BuildContext is captured before the first await
    // so no lookup happens across an async gap.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    final shopProvider = context.read<ShopProvider>();
    final appointmentProvider = context.read<AppointmentProvider>();
    final businessTools = context.read<BusinessToolsProvider>();
    final discountProvider = context.read<DiscountProvider>();
    final expenseProvider = context.read<ExpenseProvider>();
    final feedbackProvider = context.read<FeedbackProvider>();
    final shopId = ShopManager.shopId;

    await auth.signOut();

    shopProvider.reset();
    appointmentProvider.reset();
    businessTools.reset();
    discountProvider.reset();
    expenseProvider.reset();
    feedbackProvider.reset();

    if (shopId != null) {
      // Best effort: a preference-write failure must not block sign-out.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('favorite_barber_$shopId');
      } catch (e) {
        debugPrint('signOut: clearing favourite barber failed: $e');
      }
    }

    if (!context.mounted) return;
    navigator.popUntil((route) => route.isFirst);
    messenger.showSnackBar(SnackBar(content: Text(t(context).logoutDone)));
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final newPass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(ctx).changePassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: InputDecoration(labelText: t(ctx).currentPassword),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPass,
              obscureText: true,
              decoration: InputDecoration(labelText: t(ctx).newPassword),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t(ctx).cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t(ctx).save)),
        ],
      ),
    );
    if (ok == true) {
      if (!context.mounted) return;
      try {
        await AuthService.instance
            .changePassword(current.text, newPass.text);
        if (!context.mounted) return;
        showSnack(context, t(context).settingsSaved);
      } catch (_) {
        if (!context.mounted) return;
        showSnack(context, t(context).error);
      }
    }
  }
}
