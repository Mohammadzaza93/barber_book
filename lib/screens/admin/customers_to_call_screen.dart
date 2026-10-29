import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/business_tools_provider.dart';
import '../../services/ops_helpers.dart';

class CustomersToCallScreen extends StatelessWidget {
  const CustomersToCallScreen({super.key, this.inactiveDays = 30});

  final int inactiveDays;

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final list = OpsHelpers.customersToCall(
      tools.customers,
      inactiveDays: inactiveDays,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('عملاء يستحقون اتصال')),
      body: list.isEmpty
          ? const Center(
              child: Text('لا يوجد عملاء متأخرون عن الزيارة حالياً'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final c = list[i];
                final days = c.daysSinceLastVisit;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        c.name.isEmpty ? '?' : c.name.characters.first,
                      ),
                    ),
                    title: Text(c.name),
                    subtitle: Text(
                      [
                        c.phone,
                        if (days != null) 'منذ $days يوم',
                        if (c.visitCount > 0) '${c.visitCount} زيارة',
                      ].join('  •  '),
                    ),
                    trailing: IconButton(
                      tooltip: 'نسخ الرقم',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: c.phone));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تم نسخ ${c.phone}')),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
