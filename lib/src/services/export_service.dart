import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models.dart';

class ExportService {
  const ExportService();

  Future<Directory> get _directory async => getApplicationDocumentsDirectory();

  List<List<dynamic>> _rows(ReportSnapshot report, String currency, String dateFormat) => [
        ['Date', 'Type', 'Title', 'Category', 'Amount ($currency)', 'Note'],
        for (final item in report.transactions)
          [
            DateFormat(dateFormat).format(item.occurredAt),
            item.type.name,
            item.title,
            item.category,
            item.amount,
            item.note ?? '',
          ],
      ];

  Future<File> csv(ReportSnapshot report, {String currency = 'MMK', String dateFormat = 'dd/MM/yyyy'}) async {
    final directory = await _directory;
    final file = File('${directory.path}/DGzone_Money_Report.csv');
    await file.writeAsString(const ListToCsvConverter().convert(_rows(report, currency, dateFormat)));
    return file;
  }

  Future<File> excelFile(ReportSnapshot report, {String currency = 'MMK', String dateFormat = 'dd/MM/yyyy'}) async {
    final directory = await _directory;
    final workbook = Excel.createExcel();
    final sheet = workbook['Transactions'];
    for (final row in _rows(report, currency, dateFormat)) {
      sheet.appendRow(
        row.map((value) => TextCellValue(value.toString())).toList(),
      );
    }
    final bytes = workbook.save();
    if (bytes == null) throw StateError('Excel file could not be generated.');
    final file = File('${directory.path}/DGzone_Money_Report.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> pdfFile(ReportSnapshot report, {String currency = 'MMK', String dateFormat = 'dd/MM/yyyy'}) async {
    final directory = await _directory;
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'DGzone Money - Monthly Report',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Income: ${NumberFormat('#,##0').format(report.income)} $currency',
              ),
              pw.Text(
                'Expense: ${NumberFormat('#,##0').format(report.expense)} $currency',
              ),
              pw.Text(
                'Saving: ${NumberFormat('#,##0').format(report.saving)} $currency',
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: _rows(
              report, currency, dateFormat,
            ).first.map((value) => value.toString()).toList(),
            data: _rows(report, currency, dateFormat)
                .skip(1)
                .map(
                  (row) => row.map((value) => value.toString()).toList(),
                )
                .toList(),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.green100,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
    final file = File('${directory.path}/DGzone_Money_Report.pdf');
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  Future<void> share(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'DGzone Money Report');
  }
}
