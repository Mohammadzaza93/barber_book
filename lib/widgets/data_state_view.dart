import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'empty_state.dart';
import 'skeleton_loader.dart';

class DataStateView extends StatelessWidget {
  final bool loading;
  final bool permissionDenied;
  final String? error;
  final VoidCallback? onRetry;
  final Widget child;
  final String skeleton;

  const DataStateView({
    super.key,
    required this.loading,
    required this.permissionDenied,
    required this.error,
    required this.child,
    this.onRetry,
    this.skeleton = 'list',
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
      if (skeleton == 'grid') {
        return const SkeletonGrid();
      }
      return const SkeletonList();
    }
    return child;
  }
}
