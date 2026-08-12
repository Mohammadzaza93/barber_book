import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../l10n/strings.dart';
import '../models/employee.dart';

String _timeLabel(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

class WorkHoursEditor extends StatefulWidget {
  final Map<int, List<WorkSlot>> value;
  final ValueChanged<Map<int, List<WorkSlot>>> onChanged;
  const WorkHoursEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<WorkHoursEditor> createState() => _WorkHoursEditorState();
}

class _WorkHoursEditorState extends State<WorkHoursEditor> {
  String _dayLabel(int day, AppLocalizations l10n) {
    switch (day) {
      case 1: return l10n.monday;
      case 2: return l10n.tuesday;
      case 3: return l10n.wednesday;
      case 4: return l10n.thursday;
      case 5: return l10n.friday;
      case 6: return l10n.saturday;
      default: return l10n.sunday;
    }
  }

  void _update(int day, List<WorkSlot> slots) {
    final map = Map<int, List<WorkSlot>>.from(widget.value);
    if (slots.isEmpty) {
      map.remove(day);
    } else {
      map[day] = slots;
    }
    widget.onChanged(map);
  }

  Future<void> _pickTime(int day, int index, {required bool start}) async {
    final slots = widget.value[day] ?? const [];
    final current = slots[index];
    final initial = TimeOfDay(
      hour: (start ? current.startMinutes : current.endMinutes) ~/ 60,
      minute: (start ? current.startMinutes : current.endMinutes) % 60,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    final next = List<WorkSlot>.from(slots);
    if (start) {
      next[index] = WorkSlot(startMinutes: minutes, endMinutes: current.endMinutes);
    } else {
      next[index] = WorkSlot(startMinutes: current.startMinutes, endMinutes: minutes);
    }
    _update(day, next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = t(context);
    return Column(
      children: List.generate(7, (i) {
        final day = i + 1;
        final slots = widget.value[day] ?? const <WorkSlot>[];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dayLabel(day, l10n),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Switch(
                      value: slots.isNotEmpty,
                      onChanged: (on) =>
                          _update(day, on ? [const WorkSlot(startMinutes: 9 * 60, endMinutes: 18 * 60)] : []),
                    ),
                  ],
                ),
                if (slots.isNotEmpty)
                  Column(
                    children: [
                      for (var j = 0; j < slots.length; j++)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickTime(day, j, start: true),
                                  icon: const Icon(Icons.timer_outlined, size: 16),
                                  label: Text(_timeLabel(slots[j].startMinutes)),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('–'),
                              ),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickTime(day, j, start: false),
                                  icon: const Icon(Icons.timer_off_outlined, size: 16),
                                  label: Text(_timeLabel(slots[j].endMinutes)),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  final next = List<WorkSlot>.from(slots)..removeAt(j);
                                  _update(day, next);
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ],
                          ),
                        ),
                      TextButton.icon(
                        onPressed: () => _update(day, [
                          ...slots,
                          const WorkSlot(startMinutes: 0, endMinutes: 0),
                        ]),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(l10n.addBreak),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
