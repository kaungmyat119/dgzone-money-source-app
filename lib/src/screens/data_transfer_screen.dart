
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/local_database.dart';
import '../models.dart';
import '../services/data_transfer_service.dart';
import '../services/export_service.dart';
import '../strings.dart';
import '../theme.dart';

class DataTransferScreen extends StatefulWidget {
  const DataTransferScreen({
    super.key,
    required this.database,
    required this.onDataChanged,
    this.initialTab = 0,
  });

  final LocalDatabase database;
  final VoidCallback onDataChanged;
  final int initialTab;

  @override
  State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen>
    with SingleTickerProviderStateMixin {
  final transfer = const DataTransferService();
  final exporter = const ExportService();
  late final TabController tabs;
  ImportSheet? sheet;
  List<MoneyAccount> accounts = const [];
  int? accountId;
  bool skipDuplicates = true;
  bool busy = false;
  final mapping = <String, String?>{
    'date': null,
    'description': null,
    'debit': null,
    'credit': null,
    'amount': null,
    'type': null,
    'category': null,
    'memo': null,
  };

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _loadAccounts();
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final values = await widget.database.accounts();
    if (!mounted) return;
    setState(() {
      accounts = values;
      accountId = values.isEmpty ? null : values.first.id;
    });
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: LText(message)));
  }

  Future<void> _pickImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => busy = true);
    try {
      final value = await transfer.readSheet(path);
      _autoMap(value.headers);
      if (mounted) setState(() => sheet = value);
    } catch (_) {
      if (mounted) _notice('ဖိုင်ကို ဖတ်၍မရပါ');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _autoMap(List<String> headers) {
    String? find(List<String> names) {
      for (final header in headers) {
        final lower = header.toLowerCase();
        if (names.any(lower.contains)) return header;
      }
      return null;
    }
    mapping
      ..['date'] = find(['date', 'ရက်စွဲ'])
      ..['description'] = find(['description', 'title', 'အကြောင်း'])
      ..['debit'] = find(['debit', 'expense', 'အသုံး'])
      ..['credit'] = find(['credit', 'income', 'ဝင်ငွေ'])
      ..['amount'] = find(['amount', 'ပမာဏ'])
      ..['type'] = find(['type', 'အမျိုးအစား'])
      ..['category'] = find(['category', 'ကဏ္ဍ'])
      ..['memo'] = find(['memo', 'note', 'မှတ်ချက်']);
  }

  String _cell(List<String> row, String key) {
    final header = mapping[key];
    final index = sheet?.headers.indexOf(header ?? '') ?? -1;
    return index >= 0 && index < row.length ? row[index].trim() : '';
  }

  int _number(String value) =>
      int.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), '').split('.').first) ?? 0;

  DateTime? _date(String value) {
    final direct = DateTime.tryParse(value);
    if (direct != null) return direct;
    for (final format in ['dd/MM/yyyy', 'MM/dd/yyyy', 'dd-MM-yyyy']) {
      try {
        return DateFormat(format).parseStrict(value);
      } catch (_) {}
    }
    return null;
  }

  ({DateTime date, String title, String category, TransactionType type, int amount, String note})?
      _parse(List<String> row) {
    final date = _date(_cell(row, 'date'));
    final title = _cell(row, 'description');
    if (date == null || title.isEmpty) return null;
    final debit = _number(_cell(row, 'debit')).abs();
    final credit = _number(_cell(row, 'credit')).abs();
    final rawAmount = _number(_cell(row, 'amount'));
    final rawType = _cell(row, 'type').toLowerCase();
    final type = credit > 0 || rawType.contains('income') || rawType.contains('ဝင်')
        ? TransactionType.income
        : TransactionType.expense;
    final amount = credit > 0 ? credit : (debit > 0 ? debit : rawAmount.abs());
    if (amount <= 0) return null;
    return (
      date: date,
      title: title,
      category: _cell(row, 'category').isEmpty ? 'အခြား' : _cell(row, 'category'),
      type: type,
      amount: amount,
      note: _cell(row, 'memo'),
    );
  }

  Future<void> _import() async {
    final selectedSheet = sheet;
    final selectedAccount = accountId;
    if (selectedSheet == null || selectedAccount == null) {
      _notice('ဖိုင်နှင့် အကောင့်ရွေးပါ');
      return;
    }
    setState(() => busy = true);
    var imported = 0;
    var skipped = 0;
    for (final row in selectedSheet.data) {
      final item = _parse(row);
      if (item == null) {
        skipped++;
        continue;
      }
      if (skipDuplicates &&
          await widget.database.transactionExists(
            date: item.date,
            title: item.title,
            type: item.type,
            amount: item.amount,
          )) {
        skipped++;
        continue;
      }
      await widget.database.saveTransaction(
        title: item.title,
        category: item.category,
        accountId: selectedAccount,
        type: item.type,
        amount: item.amount,
        occurredAt: item.date,
        note: item.note,
      );
      imported++;
    }
    widget.onDataChanged();
    if (mounted) {
      setState(() => busy = false);
      _notice('$imported စာရင်း တင်သွင်းပြီး၊ $skipped စာရင်းကျော်ထားသည်');
    }
  }

  Future<void> _export(String type) async {
    setState(() => busy = true);
    try {
      final report = await widget.database.report();
      final preferences = AppPreferencesScope.of(context);
      final file = switch (type) {
        'pdf' => await exporter.pdfFile(report, currency: preferences.currency, dateFormat: preferences.dateFormat),
        'xlsx' => await exporter.excelFile(report, currency: preferences.currency, dateFormat: preferences.dateFormat),
        _ => await exporter.csv(report, currency: preferences.currency, dateFormat: preferences.dateFormat),
      };
      await exporter.share(file);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _createBackup() async {
    setState(() => busy = true);
    try {
      final file = await transfer.createBackup(widget.database);
      await Share.shareXFiles([XFile(file.path)], text: 'DGzone Money Backup');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['dgzbackup', 'json'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('Backup ပြန်သွင်းရန်'),
        content: const LText('လက်ရှိဒေတာကို Backup ဖိုင်ထဲကဒေတာဖြင့် အစားထိုးမည်။ ဆက်လုပ်မလား?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const LText('မလုပ်တော့ပါ')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const LText('ဆက်လုပ်မည်')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await transfer.restoreBackup(widget.database, path);
      widget.onDataChanged();
      if (mounted) _notice('Backup ပြန်သွင်းပြီးပါပြီ');
    } catch (_) {
      if (mounted) _notice('Backup ဖိုင်မမှန်ပါ');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const LText('ဒေတာ တင်သွင်း/ထုတ်ယူရန်'),
        bottom: TabBar(
          controller: tabs,
          tabs: const [
            Tab(icon: Icon(Icons.upload_outlined), text: 'Import'),
            Tab(icon: Icon(Icons.download_outlined), text: 'Export'),
            Tab(icon: Icon(Icons.cloud_outlined), text: 'Backup'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: tabs,
            children: [_importPage(), _exportPage(), _backupPage()],
          ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _importPage() {
    final current = sheet;
    final preview = current?.data.take(3).toList() ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _steps(),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.table_view)),
            title: LText(current?.fileName ?? 'CSV / Excel ဖိုင်ရွေးပါ'),
            subtitle: LText(current == null ? 'CSV သို့မဟုတ် XLSX' : '${current.data.length} စာရင်း'),
            trailing: FilledButton.tonal(onPressed: busy ? null : _pickImport, child: const LText('ဖိုင်ရွေးရန်')),
          ),
        ),
        if (current != null) ...[
          const SizedBox(height: 14),
          const LText('Column များတွဲပေးရန်', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const LText('ဖိုင်ထဲက Column ကို App Field နှင့် တွဲပါ'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _mapRow('date', 'ရက်စွဲ', required: true),
                  _mapRow('description', 'အကြောင်းအရာ', required: true),
                  _mapRow('debit', 'အသုံးစရိတ်'),
                  _mapRow('credit', 'ဝင်ငွေ'),
                  _mapRow('amount', 'ငွေပမာဏ'),
                  _mapRow('type', 'စာရင်းအမျိုးအစား'),
                  _mapRow('category', 'ကဏ္ဍ'),
                  _mapRow('memo', 'မှတ်ချက်'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          LText('နမူနာစာရင်း ${preview.length} ခု', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: LText('ရက်စွဲ')),
                  DataColumn(label: LText('အကြောင်းအရာ')),
                  DataColumn(label: LText('အမျိုးအစား')),
                  DataColumn(label: LText('ငွေပမာဏ')),
                ],
                rows: [
                  for (final row in preview)
                    if (_parse(row) case final item?)
                      DataRow(cells: [
                        DataCell(LText(context.appDate(item.date))),
                        DataCell(LText(item.title)),
                        DataCell(LText(item.type == TransactionType.income ? 'ဝင်ငွေ' : 'အသုံးစရိတ်')),
                        DataCell(LText(NumberFormat('#,##0').format(item.amount))),
                      ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(children: [
              SwitchListTile(
                title: const LText('တူညီသောစာရင်းများ မထည့်ရန်'),
                value: skipDuplicates,
                onChanged: (value) => setState(() => skipDuplicates = value),
              ),
              const Divider(height: 1),
              DropdownButtonFormField<int>(
                value: accountId,
                decoration: InputDecoration(labelText: context.tr('ထည့်သွင်းမည့်အကောင့်')),
                items: accounts.map((item) => DropdownMenuItem(value: item.id, child: LText(item.name))).toList(),
                onChanged: (value) => setState(() => accountId = value),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: busy ? null : _import,
            icon: const Icon(Icons.upload_file),
            label: LText('${current.data.length} စာရင်း တင်သွင်းမည်'),
          ),
        ],
      ],
    );
  }

  Widget _steps() => Row(
    children: const [
      Expanded(child: _Step(number: '1', label: 'ဖိုင်ရွေး')),
      Expanded(child: _Step(number: '2', label: 'Column တွဲ')),
      Expanded(child: _Step(number: '3', label: 'စစ်ဆေး')),
      Expanded(child: _Step(number: '4', label: 'ပြီးမြောက်')),
    ],
  );

  Widget _mapRow(String key, String label, {bool required = false}) {
    final headers = sheet?.headers ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: mapping[key],
            hint: const LText('Column ရွေးပါ'),
            items: headers.map((value) => DropdownMenuItem(value: value, child: LText(value))).toList(),
            onChanged: (value) => setState(() => mapping[key] = value),
          ),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_forward, color: AppColors.emerald)),
        Expanded(child: LText(label)),
        Icon(required ? Icons.check_circle : Icons.circle_outlined, color: required ? AppColors.emerald : Colors.grey),
      ]),
    );
  }

  Widget _exportPage() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const LText('ဒေတာထုတ်ယူရန်', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const LText('ယခုလ ငွေစာရင်းများကို လိုချင်သောဖိုင်ပုံစံဖြင့်ထုတ်ယူပါ'),
      const SizedBox(height: 14),
      _exportTile(Icons.picture_as_pdf_outlined, 'PDF Report', 'pdf'),
      _exportTile(Icons.table_chart_outlined, 'Excel Workbook', 'xlsx'),
      _exportTile(Icons.description_outlined, 'CSV Data', 'csv'),
    ],
  );

  Widget _exportTile(IconData icon, String title, String type) => Card(
    child: ListTile(
      leading: CircleAvatar(backgroundColor: AppColors.mintSoft, child: Icon(icon, color: AppColors.emeraldDark)),
      title: LText(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: busy ? null : () => _export(type),
    ),
  );

  Widget _backupPage() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const LText('Backup', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const LText('အကောင့်၊ စာရင်း၊ Budget၊ Template နှင့် Setting အားလုံးကို Backup ပြုလုပ်နိုင်သည်'),
      const SizedBox(height: 14),
      Card(child: ListTile(
        leading: const CircleAvatar(backgroundColor: AppColors.mintSoft, child: Icon(Icons.cloud_upload_outlined, color: AppColors.emeraldDark)),
        title: const LText('Backup ဖိုင်အသစ်ထုတ်ရန်'),
        subtitle: const LText('စာရင်းနှင့် ပြေစာပုံများပါဝင်သော DGzone Backup'),
        trailing: const Icon(Icons.chevron_right),
        onTap: busy ? null : _createBackup,
      )),
      Card(child: ListTile(
        leading: const CircleAvatar(backgroundColor: AppColors.mintSoft, child: Icon(Icons.restore, color: AppColors.emeraldDark)),
        title: const LText('Backup ပြန်သွင်းရန်'),
        subtitle: const LText('လက်ရှိဒေတာကို Backup ဖြင့် အစားထိုးမည်'),
        trailing: const Icon(Icons.chevron_right),
        onTap: busy ? null : _restoreBackup,
      )),
    ],
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.label});
  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [
    CircleAvatar(radius: 17, backgroundColor: AppColors.mintSoft, child: LText(number)),
    const SizedBox(height: 4),
    LText(label, maxLines: 1, style: const TextStyle(fontSize: 11)),
  ]);
}
