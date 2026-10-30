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
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
  List<MoneyCategory> categories = const [];
  late Set<String> selectedCategories;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.budget?.name ?? '');
    amount = TextEditingController(
      text: widget.budget?.limitAmount.toString() ?? '',
    );
    selectedCategories = widget.budget?.categories.toSet() ?? <String>{};
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final values = await widget.database.categories(TransactionType.expense);
    if (!mounted) return;
    setState(() {
      categories = values;
      selectedCategories.removeWhere(
        (name) => !categories.any((item) => item.name == name),
      );
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
    if (selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LText('အနည်းဆုံး အမျိုးအစားတစ်ခု ရွေးပါ')),
      );
      return;
    }
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(
      now.year,
      now.month + 1,
    ).subtract(const Duration(seconds: 1));
    await widget.database.saveBudget(
      id: widget.budget?.id,
      name: name.text,
      categories: selectedCategories.toList(),
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
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: categories.isEmpty
                  ? null
                  : () async {
                      final result = await Navigator.push<Set<String>>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _BudgetCategoryPicker(
                            categories: categories,
                            selected: selectedCategories,
                          ),
                        ),
                      );
                      if (result != null) {
                        setState(() => selectedCategories = result);
                      }
                    },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.tr('အမျိုးအစားများ'),
                  prefixIcon: const Icon(Icons.checklist),
                  suffixIcon: const Icon(Icons.chevron_right),
                ),
                child: LText(
                  selectedCategories.isEmpty
                      ? 'အမျိုးအစားများ ရွေးပါ'
                      : '${selectedCategories.length} ခု ရွေးထားသည်',
                ),
              ),
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

class _BudgetCategoryPicker extends StatefulWidget {
  const _BudgetCategoryPicker({
    required this.categories,
    required this.selected,
  });

  final List<MoneyCategory> categories;
  final Set<String> selected;

  @override
  State<_BudgetCategoryPicker> createState() => _BudgetCategoryPickerState();
}

class _BudgetCategoryPickerState extends State<_BudgetCategoryPicker> {
  final search = TextEditingController();
  late Set<String> selected;

  @override
  void initState() {
    super.initState();
    selected = {...widget.selected};
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<MoneyCategory> childrenOf(int parentId) => widget.categories
      .where((item) => item.parentId == parentId)
      .toList();

  void toggleMain(MoneyCategory main, bool checked) {
    final names = [main.name, ...childrenOf(main.id).map((item) => item.name)];
    setState(() {
      if (checked) {
        selected.addAll(names);
      } else {
        selected.removeAll(names);
      }
    });
  }

  bool? mainValue(MoneyCategory main) {
    final names = [main.name, ...childrenOf(main.id).map((item) => item.name)];
    final count = names.where(selected.contains).length;
    if (count == 0) return false;
    if (count == names.length) return true;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final mains = widget.categories.where((item) => item.parentId == null);
    final visibleMains = mains.where((main) {
      if (query.isEmpty || main.name.toLowerCase().contains(query)) return true;
      return childrenOf(main.id)
          .any((child) => child.name.toLowerCase().contains(query));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const LText('အမျိုးအစားများ ရွေးပါ'),
        actions: [
          IconButton(
            tooltip: context.tr('သိမ်းမည်'),
            onPressed: () => Navigator.pop(context, selected),
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.tr('အမျိုးအစားရှာရန်'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: LText(
                    '${selected.length} ခု ရွေးထားသည်',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => selected.clear()),
                  child: const LText('အားလုံးဖြုတ်မည်'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: visibleMains.length,
              itemBuilder: (context, index) {
                final main = visibleMains[index];
                final children = childrenOf(main.id)
                    .where((child) => query.isEmpty ||
                        main.name.toLowerCase().contains(query) ||
                        child.name.toLowerCase().contains(query))
                    .toList();
                final color = Color(main.colorValue);
                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 5, 12, 5),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      CheckboxListTile(
                        tristate: true,
                        value: mainValue(main),
                        onChanged: (_) =>
                            toggleMain(main, mainValue(main) != true),
                        secondary: Icon(
                          IconData(main.iconCodePoint, fontFamily: 'MaterialIcons'),
                          color: color,
                        ),
                        title: LText(
                          main.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: LText('${childrenOf(main.id).length} ${context.tr('အမျိုးအစားခွဲ')}'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      for (final child in children) ...[
                        const Divider(height: 1, indent: 56),
                        CheckboxListTile(
                          value: selected.contains(child.name),
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              selected.add(child.name);
                            } else {
                              selected.remove(child.name);
                            }
                          }),
                          secondary: Icon(
                            IconData(child.iconCodePoint, fontFamily: 'MaterialIcons'),
                            color: Color(child.colorValue),
                          ),
                          title: LText(child.name),
                          contentPadding: const EdgeInsets.only(left: 32, right: 12),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
