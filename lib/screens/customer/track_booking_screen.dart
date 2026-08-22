import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/strings.dart';
import '../../models/appointment.dart';
import '../../models/enums.dart';
import '../../models/feedback.dart' as fb;
import '../../models/service.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/shop_manager.dart';
import '../../widgets/confirm.dart';
import '../../widgets/status_chip.dart';

class TrackBookingScreen extends StatefulWidget {
  const TrackBookingScreen({super.key});

  @override
  State<TrackBookingScreen> createState() => _TrackBookingScreenState();
}

class _TrackBookingScreenState extends State<TrackBookingScreen> {
  final _phone = TextEditingController();
  final _ref = TextEditingController();
  List<Appointment>? _results;
  bool _searching = false;

  @override
  void dispose() {
    _phone.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_ref.text.trim().isEmpty) return;
    setState(() => _searching = true);
    final shopId = ShopManager.shopId!;
    final all = await FirestoreService.instance
        .findAppointmentsByPhone(shopId, _phone.text.trim());
    final filtered = all.where((a) =>
        a.reference.toUpperCase() == _ref.text.trim().toUpperCase());
    setState(() {
      _results = filtered.toList();
      _searching = false;
    });
  }

  Future<void> _rate(Appointment a) async {
    final comment = TextEditingController();
    var rating = 5;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(t(ctx).leaveRating),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setState(() => rating = i + 1),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: comment,
                maxLines: 3,
                decoration: InputDecoration(labelText: t(ctx).yourComment),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t(ctx).cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t(ctx).submitFeedback)),
          ],
        ),
      ),
    );
    if (submitted == true) {
      if (!mounted) return;
      final feedbackProvider = context.read<FeedbackProvider>();
      final apptProvider = context.read<AppointmentProvider>();
      final shopId = ShopManager.shopId!;
      await feedbackProvider.add(
            fb.Feedback(
              id: const Uuid().v4(),
              appointmentId: a.id,
              employeeId: a.employeeId,
              customerName: a.customerName,
              rating: rating,
              comment: comment.text.trim(),
              createdAt: DateTime.now(),
            ),
            shopId,
          );
      await apptProvider.setRating(a, rating, shopId);
      if (!mounted) return;
      showSnack(context, t(context).thankYouFeedback);
      await _search();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(t(context).trackBooking)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t(context).trackBookingHint,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
                labelText: t(context).phone,
                prefixIcon: const Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ref,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
                labelText: t(context).reference,
                prefixIcon: const Icon(Icons.receipt_long_rounded)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _searching ? null : _search,
            icon: const Icon(Icons.search_rounded),
            label: Text(t(context).search),
          ),
          const SizedBox(height: 20),
          if (_searching)
            const Center(child: CircularProgressIndicator())
          else if (_results != null)
            ..._results!.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(t(context).noBookingsFound,
                              style: TextStyle(
                                  color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ]
                : _results!.map((a) => _appointmentCard(context, a, shop)),
        ],
      ),
    );
  }

  Widget _appointmentCard(BuildContext context, Appointment a, ShopProvider shop) {
    final services = a.serviceIds
        .map((id) => shop.serviceById(id))
        .whereType<Service>()
        .toList();
    final canRate = a.status == AppointmentStatus.completed && a.rating == null;
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
                  child: Text(
                    '${DateFormat('d MMM yyyy').format(a.startTime)} · ${DateFormat('HH:mm').format(a.startTime)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip(status: a.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              services.map((s) => s.name).join(' + '),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            Text(
              shop.employeeById(a.employeeId)?.name ?? '-',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            if (canRate) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _rate(a),
                icon: const Icon(Icons.star_rounded, color: Colors.amber),
                label: Text(t(context).leaveRating),
              ),
            ] else if (a.rating != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: List.generate(5, (i) => Icon(
                        i < a.rating! ? Icons.star_rounded : Icons.star_border_rounded,
                        color: Colors.amber,
                        size: 16,
                      )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
