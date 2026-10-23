import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/local_database.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../services/notification_service.dart';
import 'amount_input_helper.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({
    super.key,
    required this.database,
    required this.onDataChanged,
  });

  final LocalDatabase database;
  final VoidCallback onDataChanged;

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  late Future<List<RecurringTransaction>> future;
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    future = widget.database.recurringTransactions();
  }

  Future<void> refresh() async {
    final next = widget.database.recurringTransactions();
    if (mounted) setState(() => future = next);
    await next;
  }

  Future<void> openForm([RecurringTransaction? item]) async {
    final initialKind = switch (selectedTab) {
      1 => 'receivable',
      2 => 'payable',
      _ => 'scheduled',
    };
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RecurringForm(
        database: widget.database,
        item: item,
        initialKind: initialKind,
      ),
    );
    if (changed == true) {
      await refresh();
      widget.onDataChanged();
      // Refresh the visible list first. Notification scheduling is optional
      // background work and must never delay newly saved data appearing.
      unawaited(
        NotificationService.instance
            .syncRecurring(widget.database)
            .catchError((_) {}),
      );
    }
  }

  Future<void> postDue() async {
    final count = await widget.database.postDueRecurring();
    if (!mounted) return;
    await refresh();
    widget.onDataChanged();
    unawaited(
      NotificationService.instance
          .syncRecurring(widget.database)
          .catchError((_) {}),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: LText(
          count == 0
              ? 'ထည့်ရန်ရောက်ရှိနေသော စာရင်းမရှိပါ'
              : '$count ခု စာရင်းသွင်းပြီးပါပြီ',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/dgzone_money_logo.png', height: 38),
            const SizedBox(width: 8),
            const Expanded(
              child: LText(
                'ပုံမှန်စာရင်းနှင့် Reminder',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.tr('ရက်ရောက်စာရင်းသွင်းရန်'),
            onPressed: postDue,
            icon: const Icon(Icons.playlist_add_check_circle_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openForm(),
        icon: const Icon(Icons.add),
        label: const LText('အသစ်ထည့်မည်'),
      ),
      body: FutureBuilder<List<RecurringTransaction>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return _EmptyRecurring(onAdd: () => openForm());
          }
          final active = items.where((item) => item.enabled).toList();
          final shown = items.where((item) => switch (selectedTab) {
            1 => item.kind == 'receivable',
            2 => item.kind == 'payable',
            _ => item.kind == 'scheduled',
          }).toList();
          final scheduled = active.where((item) => item.kind == 'scheduled');
          final monthlyIncome = scheduled
              .where((item) => item.type == TransactionType.income)
              .fold<int>(0, (sum, item) => sum + _monthlyAmount(item));
          final monthlyExpense = scheduled
              .where((item) => item.type == TransactionType.expense)
              .fold<int>(0, (sum, item) => sum + _monthlyAmount(item));
          // Debt totals represent every outstanding debt record. The enabled
          // switch controls reminders only, so disabled reminders must still
          // remain in the receivable/payable totals.
          final receivableTotal = items
              .where((item) => item.kind == 'receivable')
              .fold<int>(0, (sum, item) => sum + item.amount);
          final payableTotal = items
              .where((item) => item.kind == 'payable')
              .fold<int>(0, (sum, item) => sum + item.amount);
          final datedScheduled = scheduled.where((item) => item.nextRun != null).toList()
            ..sort((a, b) => a.nextRun!.compareTo(b.nextRun!));
          final next = datedScheduled.firstOrNull;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: LText('ပုံမှန်စာရင်း')),
                  ButtonSegment(value: 1, label: LText('အကြွေးရရန်')),
                  ButtonSegment(value: 2, label: LText('အကြွေးပေးရန်')),
                ],
                selected: {selectedTab},
                onSelectionChanged: (value) =>
                    setState(() => selectedTab = value.first),
              ),
              const SizedBox(height: 14),
              _RecurringSummaryCard(
                activeCount: scheduled.length,
                income: monthlyIncome,
                expense: monthlyExpense,
                next: next,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: LText(
                      switch (selectedTab) {
                        1 => 'အကြွေးရရန်စာရင်း',
                        2 => 'အကြွေးပေးရန်စာရင်း',
                        _ => 'လာမည့်ပုံမှန်စာရင်းများ',
                      },
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (selectedTab == 0) IconButton.filledTonal(
                    tooltip: context.tr('ရက်ရောက်စာရင်းသွင်းရန်'),
                    onPressed: postDue,
                    icon: const Icon(Icons.playlist_add_check),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (shown.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: LText('ဤအမျိုးအစားတွင် စာရင်းမရှိသေးပါ')),
                  ),
                )
              else
                for (final item in shown) ...[
                  _RecurringPaymentCard(
                    item: item,
                    onTap: () => openForm(item),
                    onEnabledChanged: (value) async {
                      await widget.database.toggleRecurring(item.id, value);
                      await refresh();
                      widget.onDataChanged();
                      unawaited(
                        NotificationService.instance
                            .syncRecurring(widget.database)
                            .catchError((_) {}),
                      );
                    },
                  ),
                  const SizedBox(height: 9),
                ],
              const SizedBox(height: 8),
              _RecurringTotalsCard(
                income: receivableTotal,
                expense: payableTotal,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecurringSummaryCard extends StatelessWidget {
  const _RecurringSummaryCard({
    required this.activeCount,
    required this.income,
    required this.expense,
    required this.next,
  });

  final int activeCount;
  final int income;
  final int expense;
  final RecurringTransaction? next;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? const [Color(0xFF173D30), Color(0xFF1F513E)]
                : const [Color(0xFFE6FFF2), Color(0xFFC8F9E2)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LText(
              'ယခုလ အလိုအလျောက်စာရင်း',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Row(
              children: [
                Expanded(
                  child: LText(
                    '$activeCount ခု',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF8CF0BD)
                          : AppColors.emeraldDark,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_month,
                  size: 72,
                  color: AppColors.emerald,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _SummaryAmount(
                    icon: Icons.arrow_upward,
                    label: 'ဝင်ငွေစုစုပေါင်း',
                    amount: income,
                    color: AppColors.emerald,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryAmount(
                    icon: Icons.arrow_downward,
                    label: 'ထွက်ငွေစုစုပေါင်း',
                    amount: expense,
                    color: AppColors.coral,
                  ),
                ),
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available, color: AppColors.emeraldDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LText(
                        'နောက်တစ်ခု — ${next!.title} • ${_dueLabel(next!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
}

class _SummaryAmount extends StatelessWidget {
  const _SummaryAmount({required this.icon, required this.label, required this.amount, required this.color});
  final IconData icon;
  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: .14), child: Icon(icon, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LText(label, maxLines: 1, style: const TextStyle(fontSize: 11)),
            LText(context.money(amount), maxLines: 1,
              style: TextStyle(fontWeight: FontWeight.w900, color: color)),
          ])),
        ]),
      );
}

class _RecurringPaymentCard extends StatelessWidget {
  const _RecurringPaymentCard({required this.item, required this.onTap, required this.onEnabledChanged});
  final RecurringTransaction item;
  final VoidCallback onTap;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final color = item.type == TransactionType.income ? AppColors.emerald : AppColors.coral;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Color(item.categoryColorValue).withValues(alpha: .14),
                child: Icon(
                  IconData(item.categoryIconCodePoint, fontFamily: 'MaterialIcons'),
                  color: Color(item.categoryColorValue),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: LText(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                      LText(
                        '${item.type == TransactionType.income ? '+' : '−'} ${context.money(item.amount)}',
                        style: TextStyle(fontWeight: FontWeight.w900, color: color),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    LText(
                      item.kind == 'scheduled'
                          ? '${_frequencyDescription(item)} • ${context.appDate(item.nextRun!)}'
                          : item.nextRun == null
                              ? 'ရက်သတ်မှတ်မထားပါ'
                              : 'ပေး/ရမည့်ရက် • ${context.appDate(item.nextRun!)}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 7),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (item.dueSoon ? AppColors.coral : AppColors.emerald).withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: LText(_dueLabel(item), style: TextStyle(
                          fontSize: 11,
                          color: item.dueSoon ? AppColors.coral : AppColors.emeraldDark,
                          fontWeight: FontWeight.w700,
                        )),
                      ),
                      const Spacer(),
                      Icon(Icons.account_balance_wallet_outlined, size: 17, color: color),
                      const SizedBox(width: 4),
                      Flexible(child: LText(item.accountName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                      const SizedBox(width: 8),
                      Icon(item.dueSoon ? Icons.notifications_active : Icons.notifications_none,
                        size: 20, color: item.dueSoon ? AppColors.coral : Theme.of(context).colorScheme.onSurfaceVariant),
                    ]),
                    const SizedBox(height: 8),
                    if (item.nextRun != null)
                      LinearProgressIndicator(
                        value: _cycleProgress(item),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(8),
                        color: color,
                        backgroundColor: color.withValues(alpha: .12),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(children: [
                Switch(value: item.enabled, onChanged: onEnabledChanged),
                Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringTotalsCard extends StatelessWidget {
  const _RecurringTotalsCard({required this.income, required this.expense});
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(children: [
            const Align(alignment: Alignment.centerLeft, child: LText('အကြွေးစာရင်း အနှစ်ချုပ်',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _total(context, Icons.people_alt, 'စုစုပေါင်း ရရန်', income, AppColors.emerald)),
              const VerticalDivider(),
              Expanded(child: _total(context, Icons.handshake, 'စုစုပေါင်း ပေးရန်', expense, AppColors.coral)),
            ]),
          ]),
        ),
      );

  Widget _total(BuildContext context, IconData icon, String label, int amount, Color color) => Row(children: [
    CircleAvatar(backgroundColor: color.withValues(alpha: .12), child: Icon(icon, color: color)),
    const SizedBox(width: 8),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LText(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      LText(context.money(amount), maxLines: 1,
        style: TextStyle(color: color, fontWeight: FontWeight.w900)),
    ])),
  ]);
}

class _EmptyRecurring extends StatelessWidget {
  const _EmptyRecurring({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.event_repeat, size: 76, color: AppColors.emerald),
      const SizedBox(height: 12),
      const LText('ပုံမှန်စာရင်း မရှိသေးပါ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const LText('လစာ၊ အိမ်လခ၊ ဖုန်းဘေလ်နှင့် လစဉ်ပေးချေမှုများကို အလိုအလျောက်မှတ်တမ်းတင်နိုင်သည်', textAlign: TextAlign.center),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const LText('ပုံမှန်စာရင်းအသစ်')),
    ]),
  ));
}

int _monthlyAmount(RecurringTransaction item) => switch (item.frequency) {
  'weekly' => item.amount * 52 ~/ 12,
  'yearly' => item.amount ~/ 12,
  'custom' => item.amount * 30 ~/ (item.intervalDays ?? 1),
  _ => item.amount,
};

double _cycleProgress(RecurringTransaction item) {
  final cycleDays = switch (item.frequency) {
    'weekly' => 7,
    'yearly' => 365,
    'custom' => item.intervalDays ?? 1,
    _ => 30,
  };
  final remaining = item.daysUntilDue.clamp(0, cycleDays);
  return (1 - remaining / cycleDays).clamp(0.0, 1.0).toDouble();
}

String _dueLabel(RecurringTransaction item) {
  if (!item.enabled) return 'ပိတ်ထားသည်';
  if (item.nextRun == null) return 'ရက်သတ်မှတ်မထားပါ';
  if (item.daysUntilDue < 0) return '${item.daysUntilDue.abs()} ရက်ကျော်';
  if (item.daysUntilDue == 0) return 'ယနေ့';
  return '${item.daysUntilDue} ရက်လို';
}

class _RecurringForm extends StatefulWidget {
  const _RecurringForm({
    required this.database,
    required this.initialKind,
    this.item,
  });
  final LocalDatabase database;
  final RecurringTransaction? item;
  final String initialKind;

  @override
  State<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends State<_RecurringForm> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController amountController;
  late final TextEditingController intervalDaysController;
  late TransactionType type;
  late String kind;
  late String category;
  late String frequency;
  DateTime? nextRun;
  late int reminderDays;
  late bool enabled;
  int? accountId;
  bool saving = false;

  List<String> expenseCategories = [
    'စားသောက်စရိတ်',
    'သယ်ယူပို့ဆောင်ရေး',
    'အိမ်အသုံးစရိတ်',
    'ဖုန်းနှင့်အင်တာနက်',
    'ကျန်းမာရေး',
    'အခြား',
  ];
  List<String> incomeCategories = ['လစာ', 'စီးပွားရေး', 'အပိုဝင်ငွေ', 'အခြား'];

  List<String> get categories =>
      type == TransactionType.income ? incomeCategories : expenseCategories;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    kind = item?.kind ?? widget.initialKind;
    type = item?.type ??
        (kind == 'receivable'
            ? TransactionType.income
            : TransactionType.expense);
    category = item?.category ?? categories.first;
    frequency = item?.frequency ?? 'monthly';
    nextRun = item?.nextRun ??
        (kind == 'scheduled' ? DateTime.now().add(const Duration(days: 1)) : null);
    reminderDays = item?.reminderDays ?? 1;
    enabled = item?.enabled ?? true;
    accountId = item?.accountId;
    titleController = TextEditingController(text: item?.title ?? '');
    amountController = TextEditingController(
      text: item?.amount.toString() ?? '',
    );
    intervalDaysController = TextEditingController(
      text: item?.intervalDays?.toString() ?? '1',
    );
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final result = await Future.wait([
      widget.database.categories(TransactionType.expense),
      widget.database.categories(TransactionType.income),
    ]);
    if (!mounted) return;
    setState(() {
      expenseCategories = result[0].map((item) => item.name).toList();
      incomeCategories = result[1].map((item) => item.name).toList();
      if (!categories.contains(category) && categories.isNotEmpty) category = categories.first;
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    intervalDaysController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || accountId == null) return;
    if (kind == 'scheduled' && nextRun == null) return;
    setState(() => saving = true);
    await widget.database.saveRecurring(
      id: widget.item?.id,
      title: titleController.text,
      category: category,
      accountId: accountId!,
      type: type,
      amount: int.parse(amountController.text.replaceAll(',', '')),
      kind: kind,
      frequency: kind == 'scheduled' ? frequency : null,
      intervalDays: kind == 'scheduled' && frequency == 'custom'
          ? int.parse(intervalDaysController.text)
          : null,
      nextRun: nextRun,
      enabled: enabled,
      reminderDays: reminderDays,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: LText(
          widget.item == null ? 'ပုံမှန်စာရင်းအသစ်' : 'ပုံမှန်စာရင်းပြင်ရန်',
        ),
        actions: [
          if (widget.item != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await widget.database.deleteRecurring(widget.item!.id);
                if (!context.mounted) return;
                Navigator.pop(context, true);
              },
            ),
        ],
      ),
      body: FutureBuilder<List<MoneyAccount>>(
        future: widget.database.accounts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final accounts = snapshot.data!;
          accountId ??= accounts.firstOrNull?.id;
          return Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'scheduled', label: LText('ပုံမှန်စာရင်း')),
                    ButtonSegment(value: 'receivable', label: LText('အကြွေးရရန်')),
                    ButtonSegment(value: 'payable', label: LText('အကြွေးပေးရန်')),
                  ],
                  selected: {kind},
                  onSelectionChanged: (value) => setState(() {
                    kind = value.first;
                    if (kind == 'receivable') type = TransactionType.income;
                    if (kind == 'payable') type = TransactionType.expense;
                    category = categories.first;
                    if (kind == 'scheduled' && nextRun == null) {
                      nextRun = DateTime.now().add(const Duration(days: 1));
                    } else if (kind != 'scheduled') {
                      nextRun = null;
                    }
                  }),
                ),
                const SizedBox(height: 14),
                if (kind == 'scheduled') SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.income,
                      label: LText('ဝင်ငွေ'),
                      icon: Icon(Icons.arrow_upward),
                    ),
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: LText('အသုံးစရိတ်'),
                      icon: Icon(Icons.arrow_downward),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) => setState(() {
                    type = value.first;
                    category = categories.first;
                  }),
                ),
                if (kind == 'scheduled') const SizedBox(height: 14),
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: context.tr('အကြောင်းအရာ'),
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'အကြောင်းအရာထည့်ပါ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  readOnly: true,
                  onTap: () => openAmountCalculator(context, amountController),
                  decoration: InputDecoration(
                    labelText: context.tr('ငွေပမာဏ'),
                    suffixText: AppPreferencesScope.of(context).currency,
                    prefixIcon: Icon(Icons.calculate_outlined),
                  ),
                  validator: (value) {
                    final amount = int.tryParse(
                      (value ?? '').replaceAll(',', ''),
                    );
                    return amount == null || amount <= 0
                        ? 'မှန်ကန်သောငွေပမာဏထည့်ပါ'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: categories.contains(category)
                      ? category
                      : categories.last,
                  decoration: InputDecoration(
                    labelText: context.tr('အမျိုးအစား'),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: categories
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: LText(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => category = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: accountId,
                  decoration: InputDecoration(
                    labelText: context.tr('အကောင့်'),
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: accounts
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: LText(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => accountId = value),
                ),
                const SizedBox(height: 12),
                if (kind == 'scheduled') DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: InputDecoration(
                    labelText: context.tr('ထပ်လုပ်မည့်ကာလ'),
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: LText('အပတ်စဉ်')),
                    DropdownMenuItem(value: 'monthly', child: LText('လစဉ်')),
                    DropdownMenuItem(value: 'yearly', child: LText('နှစ်စဉ်')),
                    DropdownMenuItem(value: 'custom', child: LText('ရက်အလိုက် စိတ်ကြိုက်')),
                  ],
                  onChanged: (value) => setState(() => frequency = value!),
                ),
                if (kind == 'scheduled' && frequency == 'custom') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: intervalDaysController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('ဘယ်နှစ်ရက်တစ်ခါ'),
                      suffixText: context.tr('ရက်'),
                      prefixIcon: const Icon(Icons.date_range_outlined),
                    ),
                    validator: (value) {
                      if (kind != 'scheduled' || frequency != 'custom') return null;
                      final days = int.tryParse(value ?? '');
                      return days == null || days < 1
                          ? 'ရက်အရေအတွက် အနည်းဆုံး ၁ ရက်ထည့်ပါ'
                          : null;
                    },
                  ),
                ],
                if (kind == 'scheduled') const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  leading: const Icon(Icons.event),
                  title: LText(kind == 'scheduled'
                      ? 'နောက်တစ်ကြိမ် စာရင်းသွင်းမည့်ရက်'
                      : 'ပေး/ရမည့်ရက် (မဖြစ်မနေ မလိုပါ)'),
                  subtitle: LText(nextRun == null
                      ? 'ရက်သတ်မှတ်မထားပါ'
                      : context.appDate(nextRun!)),
                  trailing: kind != 'scheduled' && nextRun != null
                      ? IconButton(
                          tooltip: context.tr('ရက်စွဲဖယ်မည်'),
                          onPressed: () => setState(() => nextRun = null),
                          icon: const Icon(Icons.close),
                        )
                      : null,
                  onTap: () async {
                    final initial = nextRun ?? DateTime.now();
                    final date = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) setState(() => nextRun = date);
                  },
                ),
                if (nextRun != null) const SizedBox(height: 12),
                if (nextRun != null) DropdownButtonFormField<int>(
                  value: reminderDays,
                  decoration: InputDecoration(
                    labelText: context.tr('သတိပေးမည့်ရက်'),
                    prefixIcon: Icon(Icons.notifications_outlined),
                  ),
                  items: const [0, 1, 3, 7]
                      .map(
                        (days) => DropdownMenuItem(
                          value: days,
                          child: LText(
                            days == 0 ? 'ရက်ရောက်သောနေ့' : '$days ရက်ကြိုတင်',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => reminderDays = value!),
                ),
                SwitchListTile(
                  title: const LText('အသုံးပြုထားမည်'),
                  value: enabled,
                  onChanged: (value) => setState(() => enabled = value),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const LText('သိမ်းမည်'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _frequencyLabel(String? value) => switch (value) {
      'weekly' => 'အပတ်စဉ်',
      'yearly' => 'နှစ်စဉ်',
      'custom' => 'ရက်အလိုက်',
      _ => 'လစဉ်',
    };

String _frequencyDescription(RecurringTransaction item) =>
    item.frequency == 'custom'
        ? '${item.intervalDays ?? 1} ရက်တစ်ခါ'
        : _frequencyLabel(item.frequency);
