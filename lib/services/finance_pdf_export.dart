import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/finance/finance_models.dart';

/// تصدير ملخص وارد يومي/شهري إلى PDF ومشاركته.
class FinancePdfExport {
  FinancePdfExport._();
  static final instance = FinancePdfExport._();

  static String paymentLabel(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return 'نقداً';
      case PaymentMethod.card:
        return 'بطاقة';
      case PaymentMethod.transfer:
        return 'حوالة';
      case PaymentMethod.other:
        return 'أخرى';
    }
  }

  Future<void> sharePeriodSummary({
    required List<DailyFinanceEntry> entries,
    required DateTime from,
    required DateTime to,
    required String currency,
    required String shopName,
  }) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
    final list = entries
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final revenue = list.fold<double>(0, (s, e) => s + e.totalAmount);
    final tips = list.fold<double>(0, (s, e) => s + e.tipAmount);
    final salon = list.fold<double>(0, (s, e) => s + e.salonShare);
    final barber = list.fold<double>(0, (s, e) => s + e.barberShare);
    final material = list.fold<double>(0, (s, e) => s + e.materialCost);

    final byService = <String, double>{};
    final byBarber = <String, double>{};
    final byPay = <String, double>{};
    for (final e in list) {
      final svc = e.serviceName.trim().isEmpty ? '—' : e.serviceName;
      byService[svc] = (byService[svc] ?? 0) + e.totalAmount;
      final b = e.barberName.trim().isEmpty ? '—' : e.barberName;
      byBarber[b] = (byBarber[b] ?? 0) + e.totalAmount;
      final p = paymentLabel(e.paymentMethod);
      byPay[p] = (byPay[p] ?? 0) + e.totalAmount + e.tipAmount;
    }

    final df = DateFormat('yyyy/MM/dd HH:mm');
    final rangeLabel =
        '${DateFormat('yyyy/MM/dd').format(start)} — ${DateFormat('yyyy/MM/dd').format(end)}';

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(shopName.isEmpty ? 'Barber' : shopName,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Finance summary / ملخص الوارد',
              style: const pw.TextStyle(fontSize: 14)),
          pw.Text(rangeLabel, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 16),
          pw.Text('Totals',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.SizedBox(height: 6),
          _row('Service revenue', '$currency ${revenue.toStringAsFixed(2)}'),
          _row('Tips', '$currency ${tips.toStringAsFixed(2)}'),
          _row('Collected (service+tips)',
              '$currency ${(revenue + tips).toStringAsFixed(2)}'),
          _row('Salon share', '$currency ${salon.toStringAsFixed(2)}'),
          _row('Barber share', '$currency ${barber.toStringAsFixed(2)}'),
          _row('Material cost', '$currency ${material.toStringAsFixed(2)}'),
          _row('Operations count', '${list.length}'),
          pw.SizedBox(height: 14),
          pw.Text('By service',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...byService.entries.map(
            (e) => _row(e.key, '$currency ${e.value.toStringAsFixed(2)}'),
          ),
          pw.SizedBox(height: 10),
          pw.Text('By barber',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...byBarber.entries.map(
            (e) => _row(e.key, '$currency ${e.value.toStringAsFixed(2)}'),
          ),
          pw.SizedBox(height: 10),
          pw.Text('By payment method',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...byPay.entries.map(
            (e) => _row(e.key, '$currency ${e.value.toStringAsFixed(2)}'),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Line items',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: const [
              'Date',
              'Customer',
              'Service',
              'Barber',
              'Amount',
              'Tip',
              'Pay',
            ],
            data: [
              for (final e in list)
                [
                  df.format(e.date),
                  e.customerName,
                  e.serviceName,
                  e.barberName,
                  e.totalAmount.toStringAsFixed(0),
                  e.tipAmount.toStringAsFixed(0),
                  paymentLabel(e.paymentMethod),
                ],
            ],
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerRight,
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final name =
        'finance_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}.pdf';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Finance $rangeLabel',
      text: 'ملخص الوارد $rangeLabel',
    );
  }

  pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
