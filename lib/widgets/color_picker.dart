import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ColorOption {
  final String hex;
  final Color color;
  const ColorOption(this.hex, this.color);
}

const colorOptions = [
  ColorOption('0xFF111827', Color(0xFF111827)),
  ColorOption('0xFF2563EB', Color(0xFF2563EB)),
  ColorOption('0xFF7C3AED', Color(0xFF7C3AED)),
  ColorOption('0xFF059669', Color(0xFF059669)),
  ColorOption('0xFFB91C1C', Color(0xFFB91C1C)),
  ColorOption('0xFFD97706', Color(0xFFD97706)),
  ColorOption('0xFF0E7490', Color(0xFF0E7490)),
  ColorOption('0xFFBE185D', Color(0xFFBE185D)),
];

class ColorPicker extends StatelessWidget {
  final String selectedHex;
  final ValueChanged<String> onChanged;
  final String label;
  const ColorPicker({
    super.key,
    required this.selectedHex,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colorOptions.map((o) {
            final isSelected = o.hex == selectedHex;
            return InkWell(
              onTap: () => onChanged(o.hex),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: o.color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: appBrandGoldDark, width: 3)
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
