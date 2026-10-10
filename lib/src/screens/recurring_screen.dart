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

  void refresh() => setState(() {
        future = widget.database.recurringTransactions();
      });

  Future<void> openForm([RecurringTransaction? item]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RecurringForm(database: widget.database, item: item),
    );
    if (changed == true) {
      await NotificationService.instance.syncRecurring(widget.database);
      refresh();
      widget.onDataChanged();
    }
  }

  Future<void> postDue() async {
    final count = await widget.database.postDueRecurring();
    await NotificationService.instance.syncRecurring(widget.database);
    if (!mounted) return;
    refresh();
    widget.onDataChanged();
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
            1 => item.type == TransactionType.income,
            2 => item.type == TransactionType.expense,
            _ => true,
          }).toList();
          final monthlyIncome = active
              .where((item) => item.type == TransactionType.income)
              .fold<int>(0, (sum, item) => sum + _monthlyAmount(item));
          final monthlyExpense = active
              .where((item) => item.type == TransactionType.expense)
              .fold<int>(0, (sum, item) => sum + _monthlyAmount(item));
          final next = active.isEmpty ? null : active.first;
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
                activeCount: active.length,
                income: monthlyIncome,
                expense: monthlyExpense,
                next: next,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: LText(
                      'လာမည့်ငွေပေးချေမှုများ',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton.filledTonal(
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
                      await NotificationService.instance.syncRecurring(widget.database);
                      refresh();
                      widget.onDataChanged();
                    },
                  ),
                  const SizedBox(height: 9),
                ],
              const SizedBox(height: 8),
              _RecurringTotalsCard(
                income: monthlyIncome,
                expense: monthlyExpense,
                onPostDue: postDue,
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
          gradient: const LinearGradient(
            colors: [Color(0xFFE6FFF2), Color(0xFFC8F9E2)],
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
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppColors.emeraldDark,
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
                  color: Colors.white.withValues(alpha: .72),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
                      '${_frequencyLabel(item.frequency)} • ${context.appDate(item.nextRun)}',
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
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
                        style: const TextStyle(fontSize: 12, color: Colors.black54))),
                      const SizedBox(width: 8),
                      Icon(item.dueSoon ? Icons.notifications_active : Icons.notifications_none,
                        size: 20, color: item.dueSoon ? AppColors.coral : Colors.black45),
                    ]),
                    const SizedBox(height: 8),
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
                const Icon(Icons.chevron_right, color: Colors.black45),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringTotalsCard extends StatelessWidget {
  const _RecurringTotalsCard({required this.income, required this.expense, required this.onPostDue});
  final int income;
  final int expense;
  final VoidCallback onPostDue;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(children: [
            const Align(alignment: Alignment.centerLeft, child: LText('အကြွေးစာရင်း အနှစ်ချုပ်',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _total(context, Icons.people_alt, 'ရရန်', income, AppColors.emerald)),
              const VerticalDivider(),
              Expanded(child: _total(context, Icons.handshake, 'ပေးရန်', expense, AppColors.coral)),
            ]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: onPostDue,
              icon: const Icon(Icons.fact_check_outlined),
              label: const LText('ရက်ရောက်စာရင်းများ ယခုသွင်းမည်'),
            )),
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
  _ => item.amount,
};

double _cycleProgress(RecurringTransaction item) {
  final cycleDays = switch (item.frequency) {'weekly' => 7, 'yearly' => 365, _ => 30};
  final remaining = item.daysUntilDue.clamp(0, cycleDays);
  return (1 - remaining / cycleDays).clamp(0.0, 1.0).toDouble();
}

String _dueLabel(RecurringTransaction item) {
  if (!item.enabled) return 'ပိတ်ထားသည်';
  if (item.daysUntilDue < 0) return '${item.daysUntilDue.abs()} ရက်ကျော်';
  if (item.daysUntilDue == 0) return 'ယနေ့';
  return '${item.daysUntilDue} ရက်လို';
}

class _RecurringForm extends StatefulWidget {
  const _RecurringForm({required this.database, this.item});
  final LocalDatabase database;
  final RecurringTransaction? item;

  @override
  State<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends State<_RecurringForm> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController amountController;
  late TransactionType type;
  late String category;
  late String frequency;
  late DateTime nextRun;
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
    type = item?.type ?? TransactionType.expense;
    category = item?.category ?? categories.first;
    frequency = item?.frequency ?? 'monthly';
    nextRun = item?.nextRun ?? DateTime.now().add(const Duration(days: 1));
    reminderDays = item?.reminderDays ?? 1;
    enabled = item?.enabled ?? true;
    accountId = item?.accountId;
    titleController = TextEditingController(text: item?.title ?? '');
    amountController = TextEditingController(
      text: item?.amount.toString() ?? '',
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
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || accountId == null) return;
    setState(() => saving = true);
    await widget.database.saveRecurring(
      id: widget.item?.id,
      title: titleController.text,
      category: category,
      accountId: accountId!,
      type: type,
      amount: int.parse(amountController.text.replaceAll(',', '')),
      frequency: frequency,
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
                SegmentedButton<TransactionType>(
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
                const SizedBox(height: 14),
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
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: InputDecoration(
                    labelText: context.tr('ထပ်လုပ်မည့်ကာလ'),
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: LText('အပတ်စဉ်')),
                    DropdownMenuItem(value: 'monthly', child: LText('လစဉ်')),
                    DropdownMenuItem(value: 'yearly', child: LText('နှစ်စဉ်')),
                  ],
                  onChanged: (value) => setState(() => frequency = value!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  leading: const Icon(Icons.event),
                  title: const LText('နောက်တစ်ကြိမ် စာရင်းသွင်းမည့်ရက်'),
                  subtitle: LText(context.appDate(nextRun)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: nextRun,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) setState(() => nextRun = date);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
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

String _frequencyLabel(String value) => switch (value) {
      'weekly' => 'အပတ်စဉ်',
      'yearly' => 'နှစ်စဉ်',
      _ => 'လစဉ်',
    };
