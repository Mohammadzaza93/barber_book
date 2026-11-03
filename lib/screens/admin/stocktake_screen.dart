import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_tools_provider.dart';
import '../../providers/shop_provider.dart';
import '../../widgets/confirm_dialogs.dart';
import '../../widgets/empty_state.dart';

/// قائمة جلسات الجرد + بدء جلسة جديدة.
class StocktakeScreen extends StatelessWidget {
  const StocktakeScreen({super.key});

  Future<void> _start(BuildContext context) async {
    final tools = context.read<BusinessToolsProvider>();
    final active = tools.inventory.where((item) => item.active).length;
    if (active == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف مواد نشطة أولاً قبل بدء الجرد')),
      );
      return;
    }
    if (active > Stocktake.maxLines) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'عدد المواد ($active) أكبر من حد الجلسة الواحدة '
            '(${Stocktake.maxLines}).',
          ),
        ),
      );
      return;
    }

    var noteValue = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بدء جرد جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ستُؤخذ لقطة لأرصدة $active مادة نشطة. '
              'أدخل الكميات الفعلية ثم رحّل الجرد ليُحدّث المخزون.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              maxLength: 80,
              onChanged: (value) => noteValue = value,
              decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                hintText: 'مثال: جرد نهاية الشهر',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('بدء الجرد'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final session = await tools.startStocktake(
        note: noteValue.trim(),
        actorId: context.read<AuthProvider>().user?.uid,
      );
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StocktakeDetailScreen(stocktakeId: session.id),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final currency = context.watch<ShopProvider>().settings?.currency ?? 'SAR';
    final sessions = tools.stocktakes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الجرد'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'stocktake_fab',
        onPressed: () => _start(context),
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('جرد جديد'),
      ),
      body: sessions.isEmpty
          ? EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'لا جلسات جرد بعد',
              subtitle:
                  'ابدأ جرداً لأخذ لقطة من أرصدة المخزون، ثم أدخل الكميات '
                  'التي عددتها ورحّلها.',
              action: FilledButton.icon(
                onPressed: () => _start(context),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('بدء أول جرد'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                Text(
                  'الجرد يقارن رصيد النظام بالكمية الفعلية. '
                  'لا يتغيّر المخزون حتى ترحّل الجلسة.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                for (final session in sessions)
                  _StocktakeCard(
                    session: session,
                    currency: currency,
                  ),
              ],
            ),
    );
  }
}

class _StocktakeCard extends StatelessWidget {
  const _StocktakeCard({required this.session, required this.currency});

  final Stocktake session;
  final String currency;

  Color get _statusColor => switch (session.status) {
        StocktakeStatus.draft => Colors.blue.shade700,
        StocktakeStatus.posting => Colors.orange.shade800,
        StocktakeStatus.completed => Colors.green.shade700,
        StocktakeStatus.cancelled => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final variance = session.totalVarianceValue;
    final varianceColor = variance == 0
        ? Colors.grey.shade700
        : variance > 0
            ? Colors.green.shade700
            : Colors.red.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StocktakeDetailScreen(stocktakeId: session.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fact_check_outlined, color: _statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.note.trim().isEmpty
                          ? 'جرد ${DateFormat('yyyy/MM/dd HH:mm').format(session.createdAt.toLocal())}'
                          : session.note,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _statusChip(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${session.countedCount} / ${session.itemCount} مادة معدودة'
                '${session.varianceCount > 0 ? ' · ${session.varianceCount} فرق' : ''}'
                '${session.conflictCount > 0 ? ' · ${session.conflictCount} يحتاج مراجعة' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              if (session.countedCount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'صافي الفرق: ${variance >= 0 ? '+' : ''}'
                  '${variance.toStringAsFixed(2)} $currency',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: varianceColor,
                  ),
                ),
              ],
              if (session.isOpen || session.isCancelled) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (session.isOpen)
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StocktakeDetailScreen(stocktakeId: session.id),
                          ),
                        ),
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('متابعة العد'),
                      ),
                    const Spacer(),
                    if (session.isDeletable && session.postedCount == 0)
                      TextButton(
                        onPressed: () => _delete(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                        child: const Text('حذف'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _statusColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          session.status.label,
          style: TextStyle(
            color: _statusColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmDelete(
      context,
      title: 'حذف جلسة الجرد؟',
      message:
          'سيتم حذف «${session.note.trim().isEmpty ? 'الجرد' : session.note}». '
          'لن يتأثر المخزون لأنها لم تُرحّل.',
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<BusinessToolsProvider>().deleteStocktake(session);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }
}

/// شاشة العدّ والترحيل لجلسة واحدة.
class StocktakeDetailScreen extends StatefulWidget {
  const StocktakeDetailScreen({super.key, required this.stocktakeId});

  final String stocktakeId;

  @override
  State<StocktakeDetailScreen> createState() => _StocktakeDetailScreenState();
}

class _StocktakeDetailScreenState extends State<StocktakeDetailScreen> {
  final Map<String, TextEditingController> _counts = {};
  bool _seeded = false;
  bool _busy = false;
  bool _dirty = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final session =
        context.read<BusinessToolsProvider>().stocktakeById(widget.stocktakeId);
    if (session == null) return;
    _seed(session);
    _seeded = true;
  }

  void _seed(Stocktake session) {
    for (final line in session.lines) {
      _controllerFor(line);
    }
  }

  TextEditingController _controllerFor(StocktakeLine line) =>
      _counts.putIfAbsent(
        line.itemId,
        () => TextEditingController(
          text: line.countedQty == null ? '' : _format(line.countedQty!),
        ),
      );

  @override
  void dispose() {
    for (final controller in _counts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _format(double value) {
    if ((value - value.roundToDouble()).abs() < kStockEpsilon) {
      return value.round().toString();
    }
    return value.toStringAsFixed(2);
  }

  /// يرجع null إذا كانت الخانة فارغة (لم تُعد)، ويرمي إذا كانت غير صالحة.
  double? _parse(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value < 0) {
      throw const FormatException('أدخل كمية صحيحة (0 أو أكثر)');
    }
    return value;
  }

  Map<String, double?> _collectCounts(Stocktake session) {
    final counts = <String, double?>{};
    for (final line in session.lines) {
      if (line.posted) continue;
      counts[line.itemId] = _parse(_controllerFor(line));
    }
    return counts;
  }

  Future<bool> _save(Stocktake session, {bool showMessage = true}) async {
    try {
      final counts = _collectCounts(session);
      await context
          .read<BusinessToolsProvider>()
          .saveStocktakeCounts(session.id, counts);
      if (!mounted) return true;
      setState(() => _dirty = false);
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الأعداد')),
        );
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      final message = error is FormatException
          ? error.message
          : error.toString().replaceFirst('Bad state: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return false;
    }
  }

  Future<void> _post(Stocktake session) async {
    final saved = await _save(session, showMessage: false);
    if (!saved || !mounted) return;
    final latest =
        context.read<BusinessToolsProvider>().stocktakeById(widget.stocktakeId);
    if (latest == null) return;

    final totalCounted = latest.countedCount;
    if (totalCounted == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل كمية معدودة واحدة على الأقل')),
      );
      return;
    }
    final pendingCount =
        latest.lines.where((l) => l.isCounted && !l.posted).length;
    final variance = latest.lines
        .where((l) => l.isCounted && !l.posted)
        .fold<double>(0, (sum, line) => sum + line.varianceValue);
    // حالة استئناف: رُحّلت كل السطور سابقاً لكن الجلسة لم تُغلق (انقطاع بعد
    // آخر سطر). لا نرمي خطأ — نكمل الإغلاق فقط.
    final closingOnly = pendingCount == 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(closingOnly ? 'إغلاق الجرد؟' : 'ترحيل الجرد؟'),
        content: Text(
          closingOnly
              ? 'كل السطور المعدودة رُحّلت مسبقاً. سيُغلق الجلسة كسجل جرد '
                  'مكتمل دون أي كتابة إضافية على المخزون.'
              : 'سيتم تحديث المخزون لـ $pendingCount مادة معدودة.\n'
                  'صافي فرق القيمة: ${variance >= 0 ? '+' : ''}'
                  '${variance.toStringAsFixed(2)}.\n\n'
                  'كل مادة تُرحّل في معاملة مستقلة، ويمكن استئناف الترحيل '
                  'إذا انقطع الاتصال. الجلسة المُرحّلة تصبح سجلاً غير قابل '
                  'للتعديل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(closingOnly ? 'إغلاق' : 'ترحيل'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await context.read<BusinessToolsProvider>().postStocktake(
            latest.id,
            actorId: context.read<AuthProvider>().user?.uid,
          );
      if (!mounted) return;
      await _showPostResult(result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPostResult(StocktakePostResult result) {
    final lines = <String>[
      if (result.posted > 0) 'تم ترحيل ${result.posted} مادة.',
      if (result.conflicts > 0)
        '${result.conflicts} مادة تغيّر رصيدها أثناء الجرد ولم تُرحّل.',
      if (result.failed > 0)
        '${result.failed} مادة تعذّر ترحيلها (محذوفة أو غير متاحة).',
      if (result.completed) 'اكتمل الجرد وأصبح سجلاً محفوظاً.',
      if (!result.completed && !result.hasIssues)
        'لم تكتمل الجلسة. راجع الأعداد ثم أعد المحاولة.',
    ];
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(result.completed ? 'تم الترحيل' : 'الترحيل يحتاج مراجعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $line'),
              ),
            if (result.hasIssues)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'استخدم «تحديث الأرصدة» ثم أعد العد أو أعد الترحيل. '
                  'لن يُكتب أي فرق فوق رصيد تغيّر بصمت.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshExpected(Stocktake session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحديث الأرصدة؟'),
        content: const Text(
          'ستُعاد لقطة أرصدة النظام للسطور غير المرحّلة إلى قيمتها الحالية. '
          'هذا يحلّ تعارض «تغيّر الرصيد أثناء الجرد»، لكن راجع الكميات '
          'المعدودة يدوياً بعد التحديث لأن مبيعات أو صرفاً قد حدث بعد العد.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context
          .read<BusinessToolsProvider>()
          .refreshStocktakeExpected(session.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث أرصدة النظام')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = context.watch<BusinessToolsProvider>();
    final session = tools.stocktakeById(widget.stocktakeId);
    final currency = context.watch<ShopProvider>().settings?.currency ?? 'SAR';

    if (session == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'جلسة الجرد غير موجودة',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('جرد المخزون'),
        actions: [
          if (session.isOpen)
            IconButton(
              tooltip: 'تحديث الأرصدة',
              onPressed: _busy ? null : () => _refreshExpected(session),
              icon: const Icon(Icons.sync_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          _Header(session: session, currency: currency),
          if (session.conflictCount > 0)
            Material(
              color: Colors.orange.shade50,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${session.conflictCount} سطراً يحتاج مراجعة: '
                        'تغيّر رصيد النظام بعد أخذ اللقطة. حدّث الأرصدة ثم راجع '
                        'العدّ.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: session.lines.length,
              itemBuilder: (context, index) => _LineTile(
                line: session.lines[index],
                controller: _controllerFor(session.lines[index]),
                editable: session.isOpen,
                currency: currency,
                onChanged: () {
                  if (!_dirty) setState(() => _dirty = true);
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: session.isOpen
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _save(session),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_dirty ? 'حفظ الأعداد *' : 'حفظ الأعداد'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _post(session),
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_rounded),
                        label: const Text('ترحيل الجرد'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session, required this.currency});

  final Stocktake session;
  final String currency;

  Color get _statusColor => switch (session.status) {
        StocktakeStatus.draft => Colors.blue.shade700,
        StocktakeStatus.posting => Colors.orange.shade800,
        StocktakeStatus.completed => Colors.green.shade700,
        StocktakeStatus.cancelled => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final variance = session.totalVarianceValue;
    final varianceColor = variance == 0
        ? Colors.grey.shade700
        : variance > 0
            ? Colors.green.shade700
            : Colors.red.shade700;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.note.trim().isEmpty
                        ? 'جرد ${DateFormat('yyyy/MM/dd HH:mm').format(session.createdAt.toLocal())}'
                        : session.note,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.status.label,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _metric(
                    'معدود', '${session.countedCount}/${session.itemCount}'),
                _metric('فروق', '${session.varianceCount}'),
                _metric(
                  'صافي القيمة',
                  '${variance >= 0 ? '+' : ''}'
                      '${variance.toStringAsFixed(2)} $currency',
                  color: varianceColor,
                ),
                if (session.postedCount > 0)
                  _metric('مُرحّل', '${session.postedCount}'),
              ],
            ),
            if (session.isCompleted && session.postedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'رُحّل في ${DateFormat('yyyy/MM/dd HH:mm').format(session.postedAt!.toLocal())}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      );
}

class _LineTile extends StatefulWidget {
  const _LineTile({
    required this.line,
    required this.controller,
    required this.editable,
    required this.currency,
    required this.onChanged,
  });

  final StocktakeLine line;
  final TextEditingController controller;
  final bool editable;
  final String currency;
  final VoidCallback onChanged;

  @override
  State<_LineTile> createState() => _LineTileState();
}

class _LineTileState extends State<_LineTile> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _LineTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// يقرأ العدّ الحالي من الخانة (قبل الحفظ) لعرض الفرق لحظياً.
  double? _liveCount() {
    final text = widget.controller.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value < 0) return null;
    return value;
  }

  bool get _invalidInput {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return false;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value == null || value < 0;
  }

  String _fmt(double value) {
    if ((value - value.roundToDouble()).abs() < kStockEpsilon) {
      return value.round().toString();
    }
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final counted = line.posted ? line.countedQty : _liveCount();
    final isCounted = counted != null;
    final variance = isCounted ? counted - line.expectedQty : 0.0;
    final varianceValue = variance * line.unitCost;
    final color = !isCounted
        ? Colors.grey.shade600
        : variance > 0
            ? Colors.green.shade700
            : variance < 0
                ? Colors.red.shade700
                : Colors.grey.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.itemName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (line.posted)
                  const _Tag('مُرحّل', Colors.green)
                else if (line.issue.isNotEmpty)
                  _Tag(line.issue, Colors.red)
                else if (line.conflict)
                  const _Tag('تعارض', Colors.orange),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'رصيد النظام: ${_fmt(line.expectedQty)} ${line.unit}'
              ' · آخر تكلفة: ${_fmt(line.unitCost)} $widget.currency',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            if (line.conflict) ...[
              const SizedBox(height: 4),
              Text(
                'الرصيد الحالي تغيّر إلى ${_fmt(line.conflictQty ?? 0)} '
                '${line.unit}. حدّث الأرصدة من الأعلى ثم راجع العدّ.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    enabled: widget.editable && !line.posted,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText:
                          line.posted ? 'الكمية المرحّلة' : 'العدّ الفعلي',
                      suffixText: line.unit,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      errorText: _invalidInput ? 'كمية غير صالحة' : null,
                    ),
                    onChanged: (_) => widget.onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          !isCounted
                              ? 'لم يُعد'
                              : '${variance > 0 ? '+' : ''}${_fmt(variance)} ${line.unit}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        Text(
                          !isCounted
                              ? 'الفرق يظهر بعد العدّ'
                              : '${varianceValue > 0 ? '+' : ''}'
                                  '${varianceValue.toStringAsFixed(2)} $widget.currency',
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);

  final String label;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
