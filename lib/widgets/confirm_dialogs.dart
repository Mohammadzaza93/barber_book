import 'package:flutter/material.dart';

Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  String message = 'لا يمكن التراجع عن هذا الإجراء بسهولة.',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  return ok == true;
}
