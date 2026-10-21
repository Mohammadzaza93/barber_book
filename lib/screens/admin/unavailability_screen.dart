import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/unavailability_request.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/shop_manager.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';

class UnavailabilityScreen extends StatefulWidget {
  const UnavailabilityScreen({super.key});

  @override
  State<UnavailabilityScreen> createState() => _UnavailabilityScreenState();
}

class _UnavailabilityScreenState extends State<UnavailabilityScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentProvider>();
    // Staff may raise and read out-of-hours requests, but only owner/manager can
    // approve or reject them (firestore.rules `requests` update = manager).
    final canDecide = context.watch<AuthProvider>().canManageOperations;
    return Scaffold(
      body: provider.requests.isEmpty
          ? EmptyState(
              icon: Icons.schedule_send_outlined,
              title: t(context).requestOutOfHours,
              subtitle: t(context).outOfHoursHint,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.requests.length,
              itemBuilder: (context, i) {
                final r = provider.requests[i];
                return _RequestCard(
                  request: r,
                  canDecide: canDecide,
                  onApprove: _busy ? null : () => _decide(context, r, true),
                  onReject: _busy ? null : () => _decide(context, r, false),
                );
              },
            ),
    );
  }

  Future<void> _decide(
      BuildContext context, UnavailabilityRequest r, bool approve) async {
    if (_busy) return;
    // Defensive: decisions are a manager-only write.
    if (!context.read<AuthProvider>().canManageOperations) return;
    setState(() => _busy = true);
    final provider = context.read<AppointmentProvider>();
    final shop = context.read<ShopProvider>();
    final shopId = ShopManager.shopId!;

    try {
      if (approve) {
        try {
          final services = shop.services.where((s) => r.serviceIds.contains(s.id)).toList();
          double total = 0;
          int duration = 0;
          for (final s in services) {
            total += s.price;
            duration += s.durationMinutes;
          }
          final end = r.requestedStart.add(Duration(minutes: duration == 0 ? 30 : duration));
          await provider.create(
            shopId: shopId,
            employeeId: shop.activeEmployees.isNotEmpty
                ? shop.activeEmployees.first.id
                : '',
            serviceIds: r.serviceIds,
            start: r.requestedStart,
            end: end,
            customerName: r.customerName,
            customerPhone: r.customerPhone,
            notes: r.reason,
            outOfHours: true,
            totalAmount: total,
          );
        } catch (error) {
          if (context.mounted) {
            showSnack(context, error.toString().contains('conflict') ? t(context).fillRequiredFields : t(context).error);
          }
          return;
        }
        await provider.updateRequest(
            r.copyWith(status: 'approved'), shopId);
      } else {
        await provider.updateRequest(
            r.copyWith(status: 'rejected'), shopId);
      }
      if (context.mounted) {
        showSnack(context, approve ? t(context).approved : t(context).rejected);
      }
    } catch (error) {
      // A denied/failed decision must surface and release the buttons instead
      // of leaving the card stuck.
      if (context.mounted) showSnack(context, t(context).error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _RequestCard extends StatelessWidget {
  final UnavailabilityRequest request;
  final bool canDecide;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  const _RequestCard({
    required this.request,
    required this.canDecide,
    required this.onApprove,
    required this.onReject,
  });

  Color get _statusColor => switch (request.status) {
        'approved' => Colors.green,
        'rejected' => Colors.red,
        _ => Colors.orange,
      };

  String _statusLabel(BuildContext context) => switch (request.status) {
        'approved' => t(context).approved,
        'rejected' => t(context).rejected,
        _ => t(context).pending,
      };

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(context),
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(r.customerPhone,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, d MMMM - HH:mm').format(r.requestedStart),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (r.reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(r.reason,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
            if (r.status == 'pending' && canDecide) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(t(context).approved),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red),
                      icon: const Icon(Icons.close_rounded),
                      label: Text(t(context).rejected),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
