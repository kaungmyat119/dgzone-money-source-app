import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/local_database.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import 'amount_input_helper.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({
    super.key,
    required this.database,
    required this.onDataChanged,
  });
  final LocalDatabase database;
  final VoidCallback onDataChanged;

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  late Future<List<BudgetProgress>> future;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => future = widget.database.budgets();
  void refresh() => setState(reload);

  Future<void> edit([BudgetProgress? budget]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BudgetForm(database: widget.database, budget: budget),
    );
    if (changed == true) {
      widget.onDataChanged();
      refresh();
    }
  }

  Future<void> remove(BudgetProgress budget) async {
    await widget.database.deleteBudget(budget.id);
    widget.onDataChanged();
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const LText('ဘတ်ဂျက်')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: edit,
        icon: const Icon(Icons.add),
        label: const LText('ဘတ်ဂျက်အသစ်'),
      ),
      body: FutureBuilder<List<BudgetProgress>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final budgets = snapshot.data!;
          final limit = budgets.fold<int>(
            0,
            (sum, item) => sum + item.limitAmount,
          );
          final spent = budgets.fold<int>(
            0,
            (sum, item) => sum + item.spentAmount,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _BudgetSummary(limit: limit, spent: spent),
              const SizedBox(height: 18),
              LText(
                'အမျိုးအစားအလိုက်',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (budgets.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Icon(
                          Icons.donut_large,
                          size: 48,
                          color: AppColors.emerald,
                        ),
                        SizedBox(height: 12),
                        LText('ဘတ်ဂျက်မသတ်မှတ်ရသေးပါ'),
                      ],
                    ),
                  ),
                ),
              for (final budget in budgets)
                _BudgetCard(
                  budget: budget,
                  onEdit: () => edit(budget),
                  onDelete: () => remove(budget),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.limit, required this.spent});
  final int limit;
  final int spent;

  @override
  Widget build(BuildContext context) {
    final ratio = limit == 0 ? 0.0 : spent / limit;
    return Container(
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
          const LText('လစဉ်ဘတ်ဂျက်'),
          const SizedBox(height: 6),
          LText(
            context.money(limit),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: ratio.clamp(0, 1),
            minHeight: 12,
            borderRadius: BorderRadius.circular(8),
            color: ratio > 1
                ? AppColors.coral
                : ratio > .8
                    ? AppColors.amber
                    : AppColors.emerald,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LText('အသုံးပြုပြီး ${context.money(spent)}'),
              LText('${(ratio * 100).round()}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.onEdit,
    required this.onDelete,
  });
  final BudgetProgress budget;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = budget.ratio > 1
        ? AppColors.coral
        : budget.ratio > .8
            ? AppColors.amber
            : AppColors.emerald;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .14),
                  child: Icon(Icons.category, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        budget.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      LText(budget.category),
                    ],
                  ),
                ),
                LText(
                  '${(budget.ratio * 100).round()}%',
                  style: TextStyle(fontWeight: FontWeight.w900, color: color),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: LText('ပြင်မည်')),
                    PopupMenuItem(value: 'delete', child: LText('ဖျက်မည်')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: budget.ratio.clamp(0, 1),
              minHeight: 9,
              borderRadius: BorderRadius.circular(8),
              color: color,
              backgroundColor: const Color(0xFFE5E7EB),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                LText(
                  '${context.money(budget.spentAmount)} အသုံးပြုပြီး',
                ),
                LText(
                  context.money(budget.limitAmount),
                ),
              ],
            ),
            if (budget.remaining < 0)
              Align(
                alignment: Alignment.centerLeft,
                child: LText(
                  '${context.money(-budget.remaining)} ကျော်လွန်',
                  style: const TextStyle(
                    color: AppColors.coral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetForm extends StatefulWidget {
  const _BudgetForm({required this.database, this.budget});
  final LocalDatabase database;
  final BudgetProgress? budget;

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController amount;
  late String category;
  List<String> categories = [
    'စားသောက်စရိတ်',
    'သယ်ယူပို့ဆောင်ရေး',
    'အိမ်အသုံးစရိတ်',
    'ဖုန်းနှင့်အင်တာနက်',
    'ကျန်းမာရေး',
    'အခြား',
  ];

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.budget?.name ?? '');
    amount = TextEditingController(
      text: widget.budget?.limitAmount.toString() ?? '',
    );
    category = widget.budget?.category ?? categories.first;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final values = await widget.database.categories(TransactionType.expense);
    if (!mounted) return;
    setState(() {
      categories = values.map((item) => item.name).toList();
      if (!categories.contains(category) && categories.isNotEmpty) category = categories.first;
    });
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(
      now.year,
      now.month + 1,
    ).subtract(const Duration(seconds: 1));
    await widget.database.saveBudget(
      id: widget.budget?.id,
      name: name.text,
      category: category,
      limitAmount: int.parse(amount.text.replaceAll(',', '')),
      periodStart: widget.budget?.periodStart ?? start,
      periodEnd: widget.budget?.periodEnd ?? end,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LText(
              widget.budget == null ? 'ဘတ်ဂျက်အသစ်' : 'ဘတ်ဂျက်ပြင်ရန်',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: name,
              decoration: InputDecoration(labelText: context.tr('ဘတ်ဂျက်အမည်')),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'အမည်ထည့်ပါ' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: categories.contains(category) ? category : categories.last,
              decoration: InputDecoration(labelText: context.tr('အမျိုးအစား')),
              items: categories
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: LText(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => category = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: amount,
              readOnly: true,
              onTap: () => openAmountCalculator(context, amount),
              decoration: InputDecoration(
                labelText: context.tr('သတ်မှတ်ငွေ'),
                suffixText: AppPreferencesScope.of(context).currency,
              ),
              validator: (value) {
                final parsed = int.tryParse((value ?? '').replaceAll(',', ''));
                return parsed == null || parsed <= 0
                    ? 'မှန်ကန်သောငွေပမာဏထည့်ပါ'
                    : null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: save,
                child: const LText('သိမ်းမည်'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
