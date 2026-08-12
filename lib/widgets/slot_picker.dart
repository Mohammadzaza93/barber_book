import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SlotPicker extends StatelessWidget {
  final List<DateTime> slots;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;
  final String emptyMessage;
  const SlotPicker({
    super.key,
    required this.slots,
    required this.selected,
    required this.onSelect,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.schedule_rounded, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              emptyMessage,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((s) {
        final isSelected = selected != null &&
            selected!.hour == s.hour &&
            selected!.minute == s.minute &&
            selected!.day == s.day;
        final label = DateFormat('HH:mm').format(s);
        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => onSelect(s),
        );
      }).toList(),
    );
  }
}
