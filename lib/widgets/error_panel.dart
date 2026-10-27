import 'package:flutter/material.dart';

import '../services/app_error.dart';

/// لوحة خطأ واضحة مع حل مقترح وزر إعادة المحاولة.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final e = AppError.from(error);
    final scheme = Theme.of(context).colorScheme;

    if (compact) {
      return Material(
        color: scheme.errorContainer.withOpacity(0.85),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.message,
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (onRetry != null && e.canRetry)
                TextButton(
                  onPressed: onRetry,
                  child: const Text('إعادة'),
                ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: scheme.errorContainer.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.message,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              e.suggestion,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withOpacity(0.8),
              ),
            ),
            if (e.code != null) ...[
              const SizedBox(height: 6),
              Text(
                'رمز: ${e.code}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            if (onRetry != null && e.canRetry) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
