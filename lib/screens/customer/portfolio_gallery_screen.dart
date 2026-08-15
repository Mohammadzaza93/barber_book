import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/business_tools_provider.dart';
import '../../widgets/feature_labels.dart';

class PortfolioGalleryScreen extends StatelessWidget {
  const PortfolioGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<BusinessToolsProvider>().portfolio
        .where((item) => item.active)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(FeatureLabels.text(context, 'استعراض الأعمال', 'Our work')),
      ),
      body: items.isEmpty
          ? Center(
              child: Text(FeatureLabels.text(
                  context, 'لا توجد صور مضافة بعد.', 'No portfolio items yet.')))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .72),
              itemCount: items.length,
              itemBuilder: (_, index) {
                final item = items[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Image.network(item.imageUrl, width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 40))),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(9),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (item.description.isNotEmpty)
                          Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                      ]),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
