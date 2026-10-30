import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/local_database.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import 'receipt_image_viewer.dart';
import 'reports_screen.dart';
import 'transaction_form_screen.dart';
import 'accounts_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key, required this.database, required this.onDataChanged});
  final LocalDatabase database;
  final VoidCallback onDataChanged;
  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final searchController = TextEditingController();
  TransactionType? filter;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<MoneyTransaction> transactions = const [];
  List<MoneyTransaction> monthAll = const [];
  Map<int, String> accountNames = const {};
  Map<String, MoneyCategory> categoryInfo = const {};
  bool loading = true;
  int _reloadGeneration = 0;

  @override
  void initState() { super.initState(); reload(); }
  @override
  void dispose() { searchController.dispose(); super.dispose(); }

  Future<void> reload() async {
    final generation = ++_reloadGeneration;
    final results = await Future.wait([
      widget.database.transactions(query: searchController.text),
      widget.database.transactions(query: searchController.text, type: filter),
      widget.database.accounts(),
      widget.database.categories(TransactionType.expense),
      widget.database.categories(TransactionType.income),
    ]);
    if (!mounted || generation != _reloadGeneration) return;
    setState(() {
      monthAll = (results[0] as List<MoneyTransaction>).where((item) =>
        item.occurredAt.year == month.year && item.occurredAt.month == month.month).toList();
      transactions = (results[1] as List<MoneyTransaction>).where((item) =>
        item.occurredAt.year == month.year && item.occurredAt.month == month.month).toList();
      accountNames = {for (final item in results[2] as List<MoneyAccount>) item.id: item.name};
      categoryInfo = {for (final item in [...(results[3] as List<MoneyCategory>), ...(results[4] as List<MoneyCategory>)]) '${item.type.name}:${item.name}': item};
      loading = false;
    });
  }

  void _changeMonth(int amount) { month = DateTime(month.year, month.month + amount); setState(() => loading = true); reload(); }

  Future<void> openForm([MoneyTransaction? transaction]) async {
    if (transaction == null && (await widget.database.accounts()).isEmpty) {
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => AccountsScreen(
        database: widget.database, onDataChanged: widget.onDataChanged,
      )));
      if ((await widget.database.accounts()).isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: LText('စာရင်းမထည့်မီ Account အနည်းဆုံးတစ်ခု ဖန်တီးပါ'),
        ));
        return;
      }
    }
    if (!mounted) return;
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => TransactionFormScreen(database: widget.database, transaction: transaction)));
    if (changed == true) {
      widget.onDataChanged();
      await reload();
    }
  }

  Future<void> remove(MoneyTransaction item) async {
    final okay = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const LText('စာရင်းဖျက်မည်လား?'), content: LText('“${item.title}” ကို ဖျက်ပါမည်။'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const LText('မဖျက်ပါ')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const LText('ဖျက်မည်'))],
    ));
    if (okay == true) {
      await widget.database.deleteTransaction(item.id);
      widget.onDataChanged();
      await reload();
    }
  }

  Map<DateTime, List<MoneyTransaction>> get groups {
    final value = <DateTime, List<MoneyTransaction>>{};
    for (final item in transactions) {
      final day = DateTime(item.occurredAt.year, item.occurredAt.month, item.occurredAt.day);
      value.putIfAbsent(day, () => []).add(item);
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final income = monthAll.where((e) => e.type == TransactionType.income).fold<int>(0, (sum, e) => sum + e.amount);
    final expense = monthAll.where((e) => e.type == TransactionType.expense).fold<int>(0, (sum, e) => sum + e.amount);
    return Scaffold(
      appBar: AppBar(title: const LText('ငွေစာရင်းများ'), actions: [IconButton(onPressed: _pickMonth, icon: const Icon(Icons.calendar_month_outlined))]),
      floatingActionButton: FloatingActionButton(onPressed: openForm, backgroundColor: AppColors.emerald, foregroundColor: Colors.white, child: const Icon(Icons.add)),
      body: RefreshIndicator(onRefresh: reload, child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 10), child: Row(children: [
          Expanded(child: TextField(controller: searchController, onChanged: (_) => reload(), decoration: InputDecoration(hintText: context.tr('စာရင်းရှာရန်'), prefixIcon: const Icon(Icons.search, size: 30), suffixIcon: searchController.text.isEmpty ? null : IconButton(onPressed: () { searchController.clear(); reload(); }, icon: const Icon(Icons.clear))))),
          const SizedBox(width: 10), IconButton.filledTonal(onPressed: _showFilter, icon: const Icon(Icons.filter_alt_outlined), iconSize: 28),
        ]))),
        SliverToBoxAdapter(child: _monthChooser()),
        SliverToBoxAdapter(child: _typeFilters()),
        SliverToBoxAdapter(child: _summary(income, expense)),
        if (loading) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (transactions.isEmpty) const SliverFillRemaining(child: Center(child: LText('စာရင်းမရှိသေးပါ')))
        else SliverList.builder(itemCount: groups.length, itemBuilder: (_, index) { final entry = groups.entries.elementAt(index); return _dayCard(entry.key, entry.value); }),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ])),
    );
  }

  Widget _monthChooser() => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Card(child: Row(children: [
    IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left, size: 32)),
    Expanded(child: Center(child: LText(DateFormat('MMMM yyyy').format(month), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))),
    IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right, size: 32)),
    const VerticalDivider(width: 1), const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.list, color: AppColors.emerald)), IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsScreen(database: widget.database))), icon: const Icon(Icons.bar_chart)),
  ])));

  Widget _typeFilters() => SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 10, 16, 8), child: SegmentedButton<TransactionType?>(
    segments: const [ButtonSegment(value: null, label: LText('အားလုံး')), ButtonSegment(value: TransactionType.income, label: LText('ဝင်ငွေ')), ButtonSegment(value: TransactionType.expense, label: LText('အသုံးစရိတ်')), ButtonSegment(value: TransactionType.transfer, label: LText('ငွေလွှဲ'))],
    selected: {filter}, onSelectionChanged: (value) { filter = value.first; setState(() => loading = true); reload(); },
  ));

  Widget _summary(int income, int expense) => Container(
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 12), padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(gradient: LinearGradient(colors: Theme.of(context).brightness == Brightness.dark ? const [Color(0xFF173D30), Color(0xFF1F513E)] : const [Color(0xFFD9FFEA), Color(0xFFB9F6D3)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const LText('စုစုပေါင်းလက်ကျန်', style: TextStyle(fontWeight: FontWeight.w700)),
      LText(context.money(income - expense), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)), const SizedBox(height: 14),
      Row(children: [Expanded(child: _summaryItem(Icons.arrow_upward, 'ဝင်ငွေ', income, AppColors.emerald)), const SizedBox(width: 10), Expanded(child: _summaryItem(Icons.arrow_downward, 'အသုံးစရိတ်', expense, AppColors.coral))]),
    ]),
  );

  Widget _summaryItem(IconData icon, String label, int amount, Color color) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha: .9), borderRadius: BorderRadius.circular(18)), child: Row(children: [
    CircleAvatar(backgroundColor: color.withValues(alpha: .16), child: Icon(icon, color: color)), const SizedBox(width: 8),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [LText(label), LText(context.money(amount), style: TextStyle(fontWeight: FontWeight.w900, color: color))])),
  ]));

  Widget _dayCard(DateTime day, List<MoneyTransaction> items) {
    final total = items.fold<int>(0, (sum, e) => sum + switch (e.type) {
      TransactionType.income => e.amount,
      TransactionType.expense => -e.amount,
      TransactionType.transfer => 0,
    });
    return Card(margin: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 12, 10), child: Row(children: [
        Expanded(child: LText(context.appDate(day), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
        LText(
          '${total > 0 ? '+' : total < 0 ? '−' : ''} ${context.money(total.abs())}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: total > 0
                ? AppColors.emerald
                : total < 0
                    ? AppColors.coral
                    : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ), const Icon(Icons.expand_more),
      ])), const Divider(height: 1),
      for (var i = 0; i < items.length; i++) ...[_transactionRow(items[i]), if (i != items.length - 1) const Divider(height: 1, indent: 72)],
    ]));
  }

  Widget _transactionRow(MoneyTransaction item) {
    final positive = item.type == TransactionType.income;
    final transfer = item.type == TransactionType.transfer;
    final color = transfer
        ? Theme.of(context).colorScheme.primary
        : positive
            ? AppColors.emerald
            : AppColors.coral;
    final category = categoryInfo['${item.type.name}:${item.category}'];
    final icon = transfer
        ? Icons.swap_horiz
        : category == null
            ? (positive ? Icons.payments : Icons.receipt_long)
            : IconData(category.iconCodePoint, fontFamily: 'MaterialIcons');
    final iconColor = transfer || category == null
        ? color
        : Color(category.colorValue);
    final accountLabel = transfer
        ? '${accountNames[item.accountId] ?? 'အကောင့်'} → ${accountNames[item.targetAccountId] ?? 'အကောင့်'}'
        : '${accountNames[item.accountId] ?? 'အကောင့်'} • ${item.category}';
    final imagePath = item.receiptImagePath;
    return InkWell(onTap: () => openForm(item), onLongPress: () => remove(item), child: Padding(padding: const EdgeInsets.fromLTRB(14, 10, 8, 10), child: Row(children: [
      CircleAvatar(radius: 25, backgroundColor: iconColor.withValues(alpha: .14), child: Icon(icon, color: iconColor)), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [LText(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), LText(accountLabel, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)), LText(DateFormat('h:mm a').format(item.occurredAt), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))])),
      LText('${transfer ? '↔' : positive ? '+' : '−'} ${context.money(item.amount)}', style: TextStyle(fontWeight: FontWeight.w900, color: color)),
      if (imagePath != null && File(imagePath).existsSync()) IconButton(onPressed: () => openReceiptImage(context, imagePath), icon: const Icon(Icons.receipt_long_outlined)), const Icon(Icons.chevron_right),
    ])));
  }

  void _showFilter() {
    showModalBottomSheet<void>(context: context, builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const LText('စာရင်းစစ်ထုတ်ရန်', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 12),
      for (final value in [null, TransactionType.income, TransactionType.expense, TransactionType.transfer]) RadioListTile<TransactionType?>(value: value, groupValue: filter, title: LText(value == null ? 'အားလုံး' : value == TransactionType.income ? 'ဝင်ငွေ' : value == TransactionType.expense ? 'အသုံးစရိတ်' : 'ငွေလွှဲ'), onChanged: (selected) { Navigator.pop(sheetContext); filter = selected; setState(() => loading = true); reload(); }),
    ]))));
  }

  Future<void> _pickMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    month = DateTime(selected.year, selected.month);
    setState(() => loading = true);
    reload();
  }
}
