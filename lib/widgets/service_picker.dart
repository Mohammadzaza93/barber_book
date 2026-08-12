import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/service.dart';

class ServicePicker extends StatelessWidget {
  final List<Service> services;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;
  final String currency;
  const ServicePicker({
    super.key,
    required this.services,
    required this.selectedIds,
    required this.onChanged,
    required this.currency,
  });

  void _toggle(String id) {
    final next = List<String>.from(selectedIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Center(
        child: Text(
          t(context).noServices,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return Column(
      children: services.map((s) {
        final isSelected = selectedIds.contains(s.id);
        return Card(
          child: ListTile(
            onTap: () => _toggle(s.id),
            leading: CircleAvatar(
              backgroundColor: Color(s.colorValue).withOpacity(0.15),
              child: Icon(
                Icons.content_cut_rounded,
                color: Color(s.colorValue),
                size: 20,
              ),
            ),
            title: Text(
              s.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${s.durationMinutes} ${t(context).minutesShort}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fmtPrice(s.price, currency),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade300,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
