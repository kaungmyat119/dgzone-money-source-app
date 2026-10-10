import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/local_database.dart';

class ImportSheet {
  const ImportSheet({required this.fileName, required this.rows});

  final String fileName;
  final List<List<String>> rows;
  List<String> get headers => rows.isEmpty ? const [] : rows.first;
  List<List<String>> get data => rows.length < 2 ? const [] : rows.sublist(1);
}

class DataTransferService {
  const DataTransferService();

  Future<ImportSheet> readSheet(String path) async {
    final file = File(path);
    final name = path.split(Platform.pathSeparator).last;
    if (name.toLowerCase().endsWith('.csv')) {
      final text = await file.readAsString();
      final rows = const CsvToListConverter(eol: '\n')
          .convert(text)
          .map((row) => row.map((value) => value.toString().trim()).toList())
          .toList();
      return ImportSheet(fileName: name, rows: rows);
    }
    final workbook = Excel.decodeBytes(await file.readAsBytes());
    final table = workbook.tables.values.first;
    final rows = table.rows
        .map(
          (row) => row
              .map((cell) => cell?.value?.toString().trim() ?? '')
              .toList(),
        )
        .toList();
    return ImportSheet(fileName: name, rows: rows);
  }

  Future<File> createBackup(LocalDatabase database, {Directory? destination}) async {
    const tables = [
      'accounts',
      'transactions',
      'budgets',
      'recurring_transactions',
      'transaction_templates',
      'money_categories',
      'app_settings',
    ];
    final receiptFiles = <String, File>{};
    final transactionRows = await database.db.query('transactions');
    for (final row in transactionRows) {
      final path = row['receipt_image_path'] as String?;
      if (path == null || path.isEmpty) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      final name = '${row['id']}_${p.basename(path)}';
      receiptFiles['receipts/$name'] = file;
    }
    final payload = <String, dynamic>{
      'format': 'dgzone-money-backup',
      'version': 2,
      'createdAt': DateTime.now().toIso8601String(),
      'appVersion': '0.5.0',
      'receiptFiles': receiptFiles.keys.toList(),
      'tables': <String, dynamic>{},
    };
    final tableData = payload['tables'] as Map<String, dynamic>;
    for (final table in tables) {
      tableData[table] = table == 'transactions'
          ? transactionRows
          : await database.db.query(table);
    }
    final canonical = jsonEncode(payload);
    payload['sha256'] = sha256.convert(utf8.encode(canonical)).toString();
    final archive = Archive();
    final manifest = utf8.encode(jsonEncode(payload));
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    for (final entry in receiptFiles.entries) {
      final bytes = await entry.value.readAsBytes();
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    }
    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) {
      throw StateError('Could not encode the backup archive');
    }
    final directory = destination ?? await getApplicationDocumentsDirectory();
    await directory.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/DGzone_Money_Backup_$stamp.dgzbackup');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> restoreBackup(LocalDatabase database, String path) async {
    final source = File(path);
    dynamic payload;
    Archive? backupArchive;
    if (path.toLowerCase().endsWith('.json')) {
      payload = jsonDecode(await source.readAsString());
    } else {
      backupArchive = ZipDecoder().decodeBytes(await source.readAsBytes(), verify: true);
      final manifest = backupArchive.findFile('manifest.json');
      if (manifest == null) throw const FormatException('Backup manifest missing');
      payload = jsonDecode(utf8.decode(Uint8List.fromList(manifest.content as List<int>)));
    }
    if (payload is! Map || payload['format'] != 'dgzone-money-backup') {
      throw const FormatException('Invalid DGzone Money backup file');
    }
    final claimedHash = payload.remove('sha256');
    if (claimedHash != null &&
        sha256.convert(utf8.encode(jsonEncode(payload))).toString() != claimedHash) {
      throw const FormatException('Backup checksum failed');
    }
    final tables = payload['tables'];
    if (tables is! Map) throw const FormatException('Backup tables missing');
    // Make a recoverable local snapshot before replacing anything.
    final documents = await getApplicationDocumentsDirectory();
    await createBackup(database, destination: Directory('${documents.path}/safety_backups'));

    final restoredReceipts = <int, String>{};
    if (backupArchive != null) {
      final receiptDirectory = Directory('${documents.path}/receipts');
      await receiptDirectory.create(recursive: true);
      for (final item in backupArchive.files.where((item) => item.name.startsWith('receipts/') && item.isFile)) {
        final baseName = p.basename(item.name);
        final id = int.tryParse(baseName.split('_').first);
        if (id == null) continue;
        final target = File('${receiptDirectory.path}/$baseName');
        await target.writeAsBytes(Uint8List.fromList(item.content as List<int>), flush: true);
        restoredReceipts[id] = target.path;
      }
    }
    const order = [
      'transactions',
      'budgets',
      'recurring_transactions',
      'transaction_templates',
      'money_categories',
      'accounts',
      'app_settings',
    ];
    await database.db.transaction((txn) async {
      for (final table in order) {
        if (tables[table] is! List) continue;
        await txn.delete(table);
      }
      for (final table in order.reversed) {
        final rows = tables[table];
        if (rows is! List) continue;
        for (final row in rows) {
          if (row is Map) {
            final values = Map<String, Object?>.from(row);
            if (table == 'transactions' && values['id'] is int && restoredReceipts.containsKey(values['id'])) {
              values['receipt_image_path'] = restoredReceipts[values['id']];
            }
            await txn.insert(table, values);
          }
        }
      }
    });
  }
}
