import 'dart:typed_data';
import 'package:excel/excel.dart' as xls;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/formatters.dart';
import 'reports_provider.dart';

class ReportExportService {
  ReportExportService._();
  static final instance = ReportExportService._();

  /// Buat PDF ringkasan laporan penjualan lalu buka dialog cetak/share bawaan
  /// OS (lewat package `printing`, share ke WhatsApp/Drive/dll juga bisa dari situ).
  Future<void> exportPdf({
    required String storeName,
    required ReportsSummary summary,
    required DateTime from,
    required DateTime to,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(storeName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text('Laporan Penjualan: ${Formatters.date(from)} - ${Formatters.date(to)}'),
                pw.SizedBox(height: 4),
                pw.Text('Dicetak: ${Formatters.dateTime(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfMetric('Total Omzet', Formatters.rupiah(summary.totalRevenue)),
              _pdfMetric('Total Transaksi', '${summary.totalTransactions}'),
              _pdfMetric('Laba Kotor', Formatters.rupiah(summary.totalProfit)),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('Rincian Harian', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Tanggal', 'Transaksi', 'Omzet'],
            data: [
              for (final d in summary.daily)
                [Formatters.date(d.date), '${d.transactionCount}', Formatters.rupiah(d.revenue)],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {1: pw.Alignment.center, 2: pw.Alignment.centerRight},
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'laporan-penjualan-${_dateSlug(from)}-${_dateSlug(to)}.pdf');
  }

  pw.Widget _pdfMetric(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  /// Buat file .xlsx ringkasan laporan penjualan lalu share lewat share_plus.
  Future<void> exportExcel({
    required String storeName,
    required ReportsSummary summary,
    required DateTime from,
    required DateTime to,
  }) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel['Laporan Penjualan'];
    excel.setDefaultSheet('Laporan Penjualan');

    sheet.appendRow([xls.TextCellValue(storeName)]);
    sheet.appendRow([xls.TextCellValue('Periode: ${Formatters.date(from)} - ${Formatters.date(to)}')]);
    sheet.appendRow([]);
    sheet.appendRow([xls.TextCellValue('Total Omzet'), xls.IntCellValue(summary.totalRevenue)]);
    sheet.appendRow([xls.TextCellValue('Total Transaksi'), xls.IntCellValue(summary.totalTransactions)]);
    sheet.appendRow([xls.TextCellValue('Laba Kotor'), xls.IntCellValue(summary.totalProfit)]);
    sheet.appendRow([]);
    sheet.appendRow([
      xls.TextCellValue('Tanggal'),
      xls.TextCellValue('Jumlah Transaksi'),
      xls.TextCellValue('Omzet'),
    ]);
    for (final d in summary.daily) {
      sheet.appendRow([
        xls.TextCellValue(Formatters.date(d.date)),
        xls.IntCellValue(d.transactionCount),
        xls.IntCellValue(d.revenue),
      ]);
    }

    final bytesList = excel.encode();
    if (bytesList == null) throw Exception('Gagal membuat file Excel.');
    final bytes = Uint8List.fromList(bytesList);
    final filename = 'laporan-penjualan-${_dateSlug(from)}-${_dateSlug(to)}.xlsx';

    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        name: filename,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    ]);
  }

  String _dateSlug(DateTime d) => '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}
