import 'package:flutter/material.dart';

import '../data/local_database.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import 'amount_input_helper.dart';
import 'transaction_form_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({
    super.key,
    required this.database,
    required this.onDataChanged,
  });
  final LocalDatabase database;
  final VoidCallback onDataChanged;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late Future<List<MoneyAccount>> future;
  bool balancesVisible = true;
  String accountFilter = 'all';

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => future = widget.database.accounts();
  void refresh() => setState(reload);

  Future<void> editAccount([MoneyAccount? account]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AccountForm(database: widget.database, account: account),
    );
    if (changed == true) {
      widget.onDataChanged();
      refresh();
    }
  }

  Future<void> deleteAccount(MoneyAccount account) async {
    final deleted = await widget.database.deleteAccount(account.id);
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LText('ဒီအကောင့်မှာ ငွေစာရင်းရှိနေသဖြင့် ဖျက်၍မရပါ။'),
        ),
      );
      return;
    }
    widget.onDataChanged();
    refresh();
  }

  Future<void> transfer() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
          database: widget.database,
          initialType: TransactionType.transfer,
        ),
      ),
    );
    if (changed == true) {
      widget.onDataChanged();
      refresh();
    }
  }

  Future<void> adjustBalance(List<MoneyAccount> accounts) async {
    if (accounts.isEmpty) return;
    int accountId = accounts.first.id;
    var direction = TransactionType.income;
    final amount = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const LText('လက်ကျန်ညှိရန်', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: accountId,
              decoration: InputDecoration(labelText: context.tr('အကောင့်')),
              items: accounts.map((item) => DropdownMenuItem(value: item.id, child: LText(item.name))).toList(),
              onChanged: (value) => setSheetState(() => accountId = value!),
            ),
            const SizedBox(height: 12),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(value: TransactionType.income, label: LText('လက်ကျန်တိုးမည်'), icon: Icon(Icons.add)),
                ButtonSegment(value: TransactionType.expense, label: LText('လက်ကျန်လျှော့မည်'), icon: Icon(Icons.remove)),
              ],
              selected: {direction},
              onSelectionChanged: (value) => setSheetState(() => direction = value.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              readOnly: true,
              onTap: () => openAmountCalculator(context, amount),
              decoration: InputDecoration(labelText: context.tr('ငွေပမာဏ'), suffixText: AppPreferencesScope.of(context).currency, prefixIcon: Icon(Icons.calculate_outlined)),
            ),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () => Navigator.pop(sheetContext, (int.tryParse(amount.text.replaceAll(',', '')) ?? 0) > 0),
              child: const LText('လက်ကျန်ညှိမည်'),
            )),
          ]),
        ),
      ),
    );
    final value = int.tryParse(amount.text.replaceAll(',', '')) ?? 0;
    amount.dispose();
    if (confirmed != true || value <= 0) return;
    await widget.database.saveTransaction(
      title: 'လက်ကျန်ညှိခြင်း',
      category: 'အခြား',
      accountId: accountId,
      type: direction,
      amount: value,
      occurredAt: DateTime.now(),
      note: 'Account Management မှ လက်ကျန်ညှိထားသည်',
    );
    widget.onDataChanged();
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/images/dgzone_money_logo.png', height: 38),
          const SizedBox(width: 8),
          const Expanded(child: LText('DGzone Money', style: TextStyle(fontWeight: FontWeight.w900))),
        ]),
        actions: [
          IconButton(
            onPressed: () => setState(() => balancesVisible = !balancesVisible),
            icon: Icon(balancesVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: editAccount,
        icon: const Icon(Icons.add),
        label: const LText('အကောင့်အသစ်'),
      ),
      body: FutureBuilder<List<MoneyAccount>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final accounts = snapshot.data!;
          final total = accounts.fold<int>(
            0,
            (sum, item) => sum + item.currentBalance,
          );
          final assets = accounts.where((item) => item.currentBalance > 0)
              .fold<int>(0, (sum, item) => sum + item.currentBalance);
          final liabilities = accounts.where((item) => item.currentBalance < 0)
              .fold<int>(0, (sum, item) => sum + item.currentBalance.abs());
          final visibleAccounts = accountFilter == 'all'
              ? accounts
              : accounts.where((item) => item.type == accountFilter).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              const LText('အကောင့်များ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE4FFF0), Color(0xFFA6F1C7)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LText('စုစုပေါင်းလက်ကျန်'),
                    const SizedBox(height: 6),
                    LText(
                      balancesVisible ? context.money(total) : '•••••• ${AppPreferencesScope.of(context).currency}',
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8CF0BD) : AppColors.emeraldDark),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _BalancePart(icon: Icons.arrow_upward, label: 'ပိုင်ဆိုင်မှုစုစုပေါင်း', amount: assets, color: AppColors.emerald, hidden: !balancesVisible)),
                      const SizedBox(width: 10),
                      Expanded(child: _BalancePart(icon: Icons.arrow_downward, label: 'ပေးရန်ငွေ', amount: liabilities, color: AppColors.coral, hidden: !balancesVisible)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _QuickAccountAction(icon: Icons.swap_horiz, label: 'ငွေလွှဲ', onTap: transfer)),
                const SizedBox(width: 8),
                Expanded(child: _QuickAccountAction(icon: Icons.bar_chart, label: 'လက်ကျန်ညှိ', onTap: () => adjustBalance(accounts))),
                const SizedBox(width: 8),
                Expanded(child: _QuickAccountAction(icon: Icons.add, label: 'အကောင့်အသစ်', onTap: () => editAccount())),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: LText('ကျွန်ုပ်၏အကောင့်များ', style: Theme.of(context).textTheme.titleLarge)),
                PopupMenuButton<String>(
                  initialValue: accountFilter,
                  icon: const Icon(Icons.filter_list),
                  onSelected: (value) => setState(() => accountFilter = value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'all', child: LText('အားလုံး')),
                    PopupMenuItem(value: 'cash', child: LText('ငွေသား')),
                    PopupMenuItem(value: 'bank', child: LText('ဘဏ်အကောင့်')),
                    PopupMenuItem(value: 'wallet', child: LText('Mobile Wallet')),
                    PopupMenuItem(value: 'credit', child: LText('Credit Card')),
                    PopupMenuItem(value: 'saving', child: LText('စုဆောင်းငွေ')),
                    PopupMenuItem(value: 'loan', child: LText('ချေးငွေ')),
                  ],
                ),
              ]),
              const SizedBox(height: 8),
              for (final account in visibleAccounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AccountCard(
                    account: account,
                    typeLabel: _typeLabel(account.type),
                    onTap: () => editAccount(account),
                    onEdit: () => editAccount(account),
                    onDelete: () => deleteAccount(account),
                    hidden: !balancesVisible,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => editAccount(),
                icon: const Icon(Icons.add),
                label: const LText('အကောင့်အသစ်ထည့်ရန်'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
        'bank' => 'ဘဏ်အကောင့်',
        'wallet' => 'Mobile Wallet',
        'credit' => 'Credit Card',
        'saving' => 'စုဆောင်းငွေ',
        'loan' => 'ချေးငွေ',
        _ => 'ငွေသား',
      };
}

class _BalancePart extends StatelessWidget {
  const _BalancePart({required this.icon, required this.label, required this.amount, required this.color, required this.hidden});
  final IconData icon;
  final String label;
  final int amount;
  final Color color;
  final bool hidden;

  @override
  Widget build(BuildContext context) => Row(children: [
    CircleAvatar(backgroundColor: color.withValues(alpha: .14), child: Icon(icon, color: color)),
    const SizedBox(width: 8),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LText(label, maxLines: 1, style: const TextStyle(fontSize: 11)),
      LText(hidden ? '•••••• ${AppPreferencesScope.of(context).currency}' : context.money(amount), maxLines: 1,
        style: TextStyle(color: color, fontWeight: FontWeight.w900)),
    ])),
  ]);
}

class _QuickAccountAction extends StatelessWidget {
  const _QuickAccountAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(radius: 19, backgroundColor: AppColors.mintSoft,
            child: Icon(icon, color: AppColors.emeraldDark)),
          const SizedBox(width: 7),
          Flexible(child: LText(label, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
      ),
    ),
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.typeLabel,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.hidden,
  });
  final MoneyAccount account;
  final String typeLabel;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool hidden;

  String get maskedNumber {
    final value = (account.accountNumber ?? '').replaceAll(' ', '');
    if (value.isEmpty) return typeLabel;
    final visible = value.length <= 4 ? value : value.substring(value.length - 4);
    return '•••• $visible';
  }

  @override
  Widget build(BuildContext context) {
    final color = account.currentBalance < 0 ? AppColors.coral : Color(account.colorValue);
    final limit = account.type == 'credit' ? account.creditLimit : account.goalAmount;
    final progress = limit <= 0 ? null :
        (account.currentBalance.abs() / limit).clamp(0.0, 1.0).toDouble();
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Color(account.colorValue).withValues(alpha: .14),
              child: Icon(IconData(account.iconCodePoint, fontFamily: 'MaterialIcons'), color: Color(account.colorValue)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: LText(account.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                LText(hidden ? '•••••• ${AppPreferencesScope.of(context).currency}' : '${account.currentBalance < 0 ? '− ' : ''}${context.money(account.currentBalance.abs())}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
              ]),
              const SizedBox(height: 3),
              LText(maskedNumber, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (progress != null) ...[
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(10),
                    color: color,
                    backgroundColor: color.withValues(alpha: .12),
                  )),
                  const SizedBox(width: 8),
                  LText('${(progress * 100).round()}%', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                ]),
              ],
            ])),
            PopupMenuButton<String>(
              icon: const Icon(Icons.drag_indicator),
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: LText('ပြင်မည်')),
                PopupMenuItem(value: 'delete', child: LText('ဖျက်မည်')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _AccountForm extends StatefulWidget {
  const _AccountForm({required this.database, this.account});
  final LocalDatabase database;
  final MoneyAccount? account;

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController balance;
  late final TextEditingController accountNumber;
  late final TextEditingController creditLimit;
  late final TextEditingController goalAmount;
  late String type;
  late int colorValue;
  late int iconCodePoint;
  static const colors = [0xFF10B981, 0xFF2196F3, 0xFFFF5B55, 0xFFF5B82E, 0xFF7C4DFF, 0xFF12B8B0, 0xFF607D8B];
  static const icons = [Icons.account_balance_wallet, Icons.account_balance, Icons.phone_android, Icons.credit_card, Icons.savings, Icons.payments, Icons.currency_exchange, Icons.monetization_on];

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.account?.name ?? '');
    balance = TextEditingController(
      text: widget.account?.openingBalance.toString() ?? '0',
    );
    accountNumber = TextEditingController(text: widget.account?.accountNumber ?? '');
    creditLimit = TextEditingController(text: '${widget.account?.creditLimit ?? 0}');
    goalAmount = TextEditingController(text: '${widget.account?.goalAmount ?? 0}');
    type = widget.account?.type ?? 'cash';
    colorValue = widget.account?.colorValue ?? colors.first;
    iconCodePoint = widget.account?.iconCodePoint ?? icons.first.codePoint;
  }

  @override
  void dispose() {
    name.dispose();
    balance.dispose();
    accountNumber.dispose();
    creditLimit.dispose();
    goalAmount.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    await widget.database.saveAccount(
      id: widget.account?.id,
      name: name.text,
      type: type,
      openingBalance: int.parse(balance.text.replaceAll(',', '')),
      accountNumber: accountNumber.text,
      creditLimit: int.tryParse(creditLimit.text.replaceAll(',', '')) ?? 0,
      goalAmount: int.tryParse(goalAmount.text.replaceAll(',', '')) ?? 0,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Form(
          key: key,
          child: Column(children: [
            Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 12),
            LText(
              widget.account == null ? 'အကောင့်အသစ်' : 'အကောင့်ပြင်ရန်',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Expanded(child: ListView(children: [
            TextFormField(
              controller: name,
              decoration: InputDecoration(labelText: context.tr('အကောင့်အမည်')),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'အမည်ထည့်ပါ' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              decoration: InputDecoration(labelText: context.tr('အကောင့်အမျိုးအစား')),
              items: const [
                DropdownMenuItem(value: 'cash', child: LText('ငွေသား')),
                DropdownMenuItem(value: 'bank', child: LText('ဘဏ်အကောင့်')),
                DropdownMenuItem(value: 'wallet', child: LText('Mobile Wallet')),
                DropdownMenuItem(value: 'credit', child: LText('Credit Card')),
                DropdownMenuItem(value: 'saving', child: LText('စုဆောင်းငွေ')),
                DropdownMenuItem(value: 'loan', child: LText('ချေးငွေ')),
              ],
              onChanged: (value) => setState(() {
                type = value!;
                iconCodePoint = _defaultIcon(type).codePoint;
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: accountNumber,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.tr('အကောင့်နံပါတ် (နောက်ဆုံး ၄ လုံး)'), prefixIcon: Icon(Icons.pin_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: balance,
              readOnly: true,
              onTap: () => openAmountCalculator(
                context,
                balance,
                allowZero: true,
              ),
              decoration: InputDecoration(
                labelText: context.tr('မူလလက်ကျန်'),
                suffixText: AppPreferencesScope.of(context).currency,
              ),
              validator: (value) =>
                  int.tryParse((value ?? '').replaceAll(',', '')) == null
                      ? 'မှန်ကန်သောငွေပမာဏထည့်ပါ'
                      : null,
            ),
            if (type == 'credit' || type == 'loan') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: creditLimit,
                readOnly: true,
                onTap: () => openAmountCalculator(context, creditLimit, allowZero: true),
                decoration: InputDecoration(labelText: context.tr('ချေးငွေ/ကတ် Limit'), suffixText: AppPreferencesScope.of(context).currency, prefixIcon: Icon(Icons.speed)),
              ),
            ],
            if (type == 'saving') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: goalAmount,
                readOnly: true,
                onTap: () => openAmountCalculator(context, goalAmount, allowZero: true),
                decoration: InputDecoration(labelText: context.tr('စုဆောင်းရန် ရည်မှန်းချက်'), suffixText: AppPreferencesScope.of(context).currency, prefixIcon: Icon(Icons.flag_outlined)),
              ),
            ],
            const SizedBox(height: 14),
            const Align(alignment: Alignment.centerLeft, child: LText('အရောင်ရွေးပါ')),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final value in colors) ChoiceChip(
                label: CircleAvatar(radius: 10, backgroundColor: Color(value)),
                selected: colorValue == value,
                onSelected: (_) => setState(() => colorValue = value),
              ),
            ]),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: LText('Icon ရွေးပါ')),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final icon in icons) IconButton.filledTonal(
                onPressed: () => setState(() => iconCodePoint = icon.codePoint),
                icon: Icon(icon, color: iconCodePoint == icon.codePoint ? Color(colorValue) : null),
              ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: save,
                child: const LText('သိမ်းမည်'),
              ),
            ),
            const SizedBox(height: 8),
            ])),
          ]),
        ),
      ),
    );
  }

  IconData _defaultIcon(String value) => switch (value) {
    'bank' => Icons.account_balance,
    'wallet' => Icons.phone_android,
    'credit' => Icons.credit_card,
    'saving' => Icons.savings,
    'loan' => Icons.payments,
    _ => Icons.account_balance_wallet,
  };
}
