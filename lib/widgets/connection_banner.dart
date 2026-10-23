import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../providers/connection_provider.dart';

/// Unobtrusive status strip shown above the authenticated content.
///
/// It reports three honest states: offline (writes are queued locally),
/// syncing (queued writes are draining), and sync-error (a flush was rejected
/// and will be retried). When everything is online and synced it renders
/// nothing, so it never steals vertical space from the real UI.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<ConnectionProvider>().status;

    final Widget child;
    switch (status) {
      case SyncStatus.online:
        return const SizedBox.shrink();
      case SyncStatus.offline:
        child = _Banner(
          color: const Color(0xFF8A6D00),
          background: const Color(0xFFFFF3CD),
          icon: Icons.cloud_off_rounded,
          text: t(context).offlineBannerMessage,
        );
      case SyncStatus.syncing:
        child = _Banner(
          color: const Color(0xFF1B5E20),
          background: const Color(0xFFE7F3E8),
          icon: Icons.sync_rounded,
          text: t(context).syncingMessage,
        );
      case SyncStatus.syncError:
        child = _Banner(
          color: const Color(0xFF8E1B1B),
          background: const Color(0xFFFBE4E4),
          icon: Icons.error_outline_rounded,
          text: t(context).syncErrorBanner,
        );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: child,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.background,
    required this.icon,
    required this.text,
  });

  final Color color;
  final Color background;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
