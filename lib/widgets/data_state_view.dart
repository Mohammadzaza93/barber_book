import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'empty_state.dart';

/// Renders the standard data lifecycle for a provider-backed screen so the UI
/// never confuses loading, permission denial, transient errors, and genuinely
/// empty data.
///
/// Access control stays server-authoritative; this widget only decides which
/// user-facing state to show for whatever the provider reported. It is placed
/// around already-authorized screens, so it never grants access to data.
class DataStateView extends StatelessWidget {
  final bool loading;
  final bool permissionDenied;
  final String? error;

  /// Called from the error state's retry button. When null the button is hidden.
  final VoidCallback? onRetry;

  /// Shown once the provider has loaded successfully (empty or not).
  final Widget child;

  const DataStateView({
    super.key,
    required this.loading,
    required this.permissionDenied,
    required this.error,
    required this.child,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (permissionDenied) {
      return EmptyState(
        icon: Icons.lock_outline_rounded,
        title: t(context).accessDeniedTitle,
        subtitle: t(context).accessDeniedMessage,
      );
    }
    if (error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: t(context).error,
        action: onRetry == null
            ? null
            : FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(t(context).retry),
              ),
      );
    }
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return child;
  }
}
