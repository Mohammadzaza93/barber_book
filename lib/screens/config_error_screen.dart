import 'package:flutter/material.dart';

import '../l10n/strings.dart';

class ConfigErrorScreen extends StatelessWidget {
  final String? message;
  const ConfigErrorScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final error = (message ?? '').trim();
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                t(context).setupConfigError,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 12),
                // The concrete reason matters more than the headline: the
                // headline is the same for every failure mode.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
