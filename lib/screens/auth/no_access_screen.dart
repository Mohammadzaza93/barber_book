import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

/// Shown when a signed-in account has no shop membership.
///
/// Only the owner account may create the salon; anyone else must be linked by
/// the owner from the staff screen. This replaces the old behaviour where any
/// signed-in stranger could run the setup wizard and create a shop.
class NoAccessScreen extends StatelessWidget {
  const NoAccessScreen({super.key});

  Future<void> _claimWithCode(BuildContext context) async {
    final controller = TextEditingController();
    final auth = context.read<AuthProvider>();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ربط الحساب برمز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اطلب من الأدمن رمز الربط من شاشة الموظفين، ثم أدخله هنا.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'رمز الربط',
                prefixIcon: Icon(Icons.key_rounded),
              ),
              onSubmitted: (value) => Navigator.pop(ctx, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('ربط'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty) return;
    try {
      await auth.claimInvite(code);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم ربط الحساب بالمحل')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر الربط: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'الحساب غير مرتبط بأي محل',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    auth.user?.email ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'اطلب من الأدمن رمز ربط من شاشة الموظفين، ثم أدخله هنا. '
                    'أو اطلب منه ربط البريد ثم اضغط «إعادة المحاولة».',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        auth.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _claimWithCode(context),
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('ربط برمز من الأدمن'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        context.read<AuthProvider>().refreshSession(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.read<AuthProvider>().signOut(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
