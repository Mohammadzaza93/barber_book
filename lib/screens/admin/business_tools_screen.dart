import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/business_features.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/media_upload_service.dart';
import '../../widgets/skeleton_loader.dart';
import 'business_management_tabs.dart';

class BusinessToolsScreen extends StatelessWidget {
  const BusinessToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(
                    text: t(context).tabPortfolio,
                    icon: const Icon(Icons.photo_library_outlined)),
                Tab(
                    text: t(context).tabCustomers,
                    icon: const Icon(Icons.people_alt_outlined)),
                Tab(
                    text: t(context).tabLoyalty,
                    icon: const Icon(Icons.stars_outlined)),
                Tab(
                    text: t(context).tabChairs,
                    icon: const Icon(Icons.event_seat_outlined)),
                Tab(
                    text: t(context).tabQueue,
                    icon: const Icon(Icons.queue_outlined)),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _PortfolioTab(),
                CustomerManagementTab(),
                LoyaltyProgramTab(),
                ChairOperationsTab(),
                _QueueTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioTab extends StatefulWidget {
  const _PortfolioTab();

  @override
  State<_PortfolioTab> createState() => _PortfolioTabState();
}

class _PortfolioTabState extends State<_PortfolioTab> {
  bool _uploading = false;

  Future<void> _add(BuildContext context) async {
    final title = TextEditingController();
    final category = TextEditingController(text: 'haircut');
    final description = TextEditingController();
    File? picked;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t(context).portfolioAddTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Material(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () async {
                            final x = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1600,
                              maxHeight: 1600,
                              imageQuality: 85,
                            );
                            if (x == null) return;
                            setLocal(() => picked = File(x.path));
                          },
                          child: picked == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        size: 40),
                                    SizedBox(height: 8),
                                    Text('اختر صورة من الجهاز'),
                                  ],
                                )
                              : Image.file(
                                  picked!,
                                  fit: BoxFit.cover,
                                  cacheWidth: 800,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: title,
                      decoration: InputDecoration(
                        labelText: t(context).portfolioItemTitle,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: category,
                      decoration: InputDecoration(
                        labelText: t(context).category,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: description,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: t(context).description,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        if (picked == null || title.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('اختر صورة وأدخل العنوان')),
                          );
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('رفع وحفظ'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(t(context).cancel),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final titleText = title.text.trim();
    final categoryText = category.text.trim();
    final descriptionText = description.text.trim();
    title.dispose();
    category.dispose();
    description.dispose();
    if (result != true ||
        !context.mounted ||
        picked == null ||
        titleText.isEmpty) {
      return;
    }

    setState(() => _uploading = true);
    try {
      final tools = context.read<BusinessToolsProvider>();
      final url = await MediaUploadService.instance.uploadPortfolioImage(
        shopId: tools.shopId,
        file: picked!,
      );
      await tools.addPortfolio(PortfolioItem(
        id: tools.newId(),
        title: titleText,
        imageUrl: url,
        category: categoryText.isEmpty ? 'general' : categoryText,
        description: descriptionText,
        createdAt: DateTime.now(),
      ));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع الصورة وحفظ العنصر')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الرفع: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final dpr = MediaQuery.devicePixelRatioOf(context);

    if (_uploading) {
      return const SkeletonGrid();
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'portfolio_fab',
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(t(context).add),
      ),
      body: tools.portfolio.isEmpty
          ? Center(child: Text(t(context).portfolioEmpty))
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemCount: tools.portfolio.length,
              itemBuilder: (context, index) {
                final item = tools.portfolio[index];
                final cacheW = (180 * dpr).round();
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Hero(
                                tag: 'portfolio-${item.id}',
                                child: item.imageUrl.isEmpty
                                    ? const SizedBox(
                                        height: 200,
                                        child: Icon(Icons.image, size: 64),
                                      )
                                    : Image.network(
                                        item.imageUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 280,
                                        cacheWidth: (400 * dpr).round(),
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox(
                                          height: 200,
                                          child: Icon(Icons.broken_image),
                                        ),
                                      ),
                              ),
                              ListTile(
                                title: Text(item.title),
                                subtitle: Text(item.description.isEmpty
                                    ? item.category
                                    : item.description),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    tools.deletePortfolio(item.id);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Hero(
                            tag: 'portfolio-${item.id}',
                            child: item.imageUrl.isEmpty
                                ? const ColoredBox(
                                    color: Color(0x11000000),
                                    child: Icon(Icons.image_outlined),
                                  )
                                : Image.network(
                                    item.imageUrl,
                                    fit: BoxFit.cover,
                                    cacheWidth: cacheW,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _QueueTab extends StatelessWidget {
  const _QueueTab();

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final shop = context.read<ShopProvider>();
    String? employeeId =
        shop.activeEmployees.isEmpty ? null : shop.activeEmployees.first.id;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(t(context).queueAddTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration:
                      InputDecoration(labelText: t(context).customerNameField)),
              TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      InputDecoration(labelText: t(context).phoneNumberField)),
              if (shop.activeEmployees.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: employeeId,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: t(context).assignedBarberField),
                  items: shop.activeEmployees
                      .map((e) =>
                          DropdownMenuItem(value: e.id, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setState(() => employeeId = v),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t(context).cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(t(context).save)),
          ],
        ),
      ),
    );
    final nameText = name.text.trim();
    final phoneText = phone.text.trim();
    name.dispose();
    phone.dispose();
    if (result != true || !context.mounted || nameText.isEmpty) return;
    await context.read<BusinessToolsProvider>().addQueue(QueueEntry(
          id: context.read<BusinessToolsProvider>().newId(),
          customerName: nameText,
          customerPhone: phoneText,
          employeeId: employeeId ?? '',
          joinedAt: DateTime.now(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'queue_fab',
        onPressed: () => _add(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(t(context).add),
      ),
      body: tools.queue.isEmpty
          ? const Center(child: Text('لا يوجد أحد في الطابور حالياً'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: tools.queue.length,
              itemBuilder: (context, index) {
                final entry = tools.queue[index];
                return Card(
                  child: ListTile(
                    title: Text(entry.customerName),
                    subtitle: Text(
                      '${entry.customerPhone}  •  ${DateFormat('HH:mm').format(entry.joinedAt)}  •  ${entry.status.name}',
                    ),
                    trailing: auth.canManageRules
                        ? IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () => tools.saveQueue(
                                  entry.copyWith(
                                    status: QueueStatus.completed,
                                    completedAt: DateTime.now(),
                                  ),
                                ),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
