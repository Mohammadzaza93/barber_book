import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/shop_provider.dart';
import '../services/auth_service.dart';
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
              if (ok) await auth.signOut();
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.logout_rounded),
            label: Text(t(context).logout),
          ),
        ],
      ),
    );
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
