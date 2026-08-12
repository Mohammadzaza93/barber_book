import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/feedback.dart' as fb;
import '../../providers/feedback_provider.dart';
import '../../services/shop_manager.dart';
import '../../widgets/empty_state.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final feedback = context.watch<FeedbackProvider>();
    final avg = feedback.averageRating;

    return Scaffold(
      body: Column(
        children: [
          if (feedback.approved.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(context).averageRating,
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 12),
                      ),
                      Text(
                        avg.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: feedback.feedback.isEmpty
                ? EmptyState(
                    icon: Icons.star_border_rounded,
                    title: t(context).feedback,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: feedback.feedback.length,
                    itemBuilder: (context, i) {
                      final f = feedback.feedback[i];
                      return _FeedbackCard(
                        feedback: f,
                        onToggle: (show) async {
                          await context
                              .read<FeedbackProvider>()
                              .toggleShow(f, show, ShopManager.shopId!);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final fb.Feedback feedback;
  final ValueChanged<bool> onToggle;
  const _FeedbackCard({required this.feedback, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final f = feedback;
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
                  child: Text(f.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    return Icon(
                      i < f.rating ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 18,
                      color: Colors.amber,
                    );
                  }),
                ),
              ],
            ),
            if (f.comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(f.comment, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  f.showOnPage ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  size: 16,
                  color: f.showOnPage ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  t(context).reviews,
                  style: TextStyle(
                    fontSize: 12,
                    color: f.showOnPage ? Colors.green : Colors.grey,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: f.showOnPage,
                  onChanged: (v) => onToggle(v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
