import 'package:flutter/material.dart';

import '../data/local_database.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import 'amount_input_helper.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({
    super.key,
    required this.database,
    required this.initialType,
  });

  final LocalDatabase database;
  final TransactionType initialType;

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabController;
  late Future<List<TransactionTemplate>> future;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _types.indexOf(widget.initialType),
    )..addListener(() {
        if (!tabController.indexIsChanging) setState(() {});
      });
    reload();
  }

  @override
  void dispose() {
    tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void reload() => future = widget.database.transactionTemplates();

  static const _types = [
    TransactionType.expense,
    TransactionType.income,
    TransactionType.transfer,
  ];

  TransactionType get selectedType => _types[tabController.index];

  Future<void> editTemplate([TransactionTemplate? template]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen(
          database: widget.database,
          initialType: selectedType,
          template: template,
        ),
      ),
    );
    if (changed == true && mounted) setState(reload);
  }

  Future<void> deleteTemplate(TransactionTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('Template ဖျက်ရန်'),
        content: LText('“${template.name}” ကို ဖျက်မည်လား?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const LText('မဖျက်ပါ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const LText('ဖျက်မည်'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.database.deleteTransactionTemplate(template.id);
    if (mounted) setState(reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const LText('Templates'),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: 'အသုံးစရိတ်'),
            Tab(text: 'ဝင်ငွေ'),
            Tab(text: 'ငွေလွှဲ'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: editTemplate,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.tr('Template ရှာရန်'),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<TransactionTemplate>>(
              future: future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final query = searchController.text.trim().toLowerCase();
                final items = snapshot.data!
                    .where((item) => item.type == selectedType)
                    .where(
                      (item) =>
                          query.isEmpty ||
                          item.name.toLowerCase().contains(query) ||
                          item.title.toLowerCase().contains(query) ||
                          item.category.toLowerCase().contains(query),
                    )
                    .toList();
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bookmarks_outlined,
                            size: 58,
                            color: AppColors.emerald,
                          ),
                          const SizedBox(height: 12),
                          const LText('Template မရှိသေးပါ'),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: editTemplate,
                            icon: const Icon(Icons.add),
                            label: const LText('Template အသစ်ထည့်မည်'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 90),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.only(left: 10, right: 2),
                      onTap: () => Navigator.pop(context, item),
                      leading: CircleAvatar(
                        backgroundColor: _typeColor(
                          item.type,
                        ).withValues(alpha: .12),
                        child: Icon(
                          _typeIcon(item.type),
                          color: _typeColor(item.type),
                        ),
                      ),
                      title: LText(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: LText('${item.category} • ${item.title}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LText(
                            context.money(item.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: _typeColor(item.type),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) => value == 'edit'
                                ? editTemplate(item)
                                : deleteTemplate(item),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: LText('ပြင်မည်'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: LText('ဖျက်မည်'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({
    super.key,
    required this.database,
    required this.initialType,
    this.template,
  });

  final LocalDatabase database;
  final TransactionType initialType;
  final TransactionTemplate? template;

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController titleController;
  late final TextEditingController amountController;
  late final TextEditingController noteController;
  late TransactionType type;
  late String category;
  int? accountId;
  int? targetAccountId;
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
    final item = widget.template;
    type = item?.type ?? widget.initialType;
    category = item?.category ?? categories.first;
    accountId = item?.accountId;
    targetAccountId = item?.targetAccountId;
    nameController = TextEditingController(text: item?.name ?? '');
    titleController = TextEditingController(text: item?.title ?? '');
    amountController = TextEditingController(
      text: item?.amount.toString() ?? '0',
    );
    noteController = TextEditingController(text: item?.note ?? '');
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
    nameController.dispose();
    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || accountId == null) return;
    if (type == TransactionType.transfer && targetAccountId == null) return;
    setState(() => saving = true);
    await widget.database.saveTransactionTemplate(
      id: widget.template?.id,
      name: nameController.text,
      title: titleController.text,
      category: category,
      accountId: accountId!,
      targetAccountId:
          type == TransactionType.transfer ? targetAccountId : null,
      type: type,
      amount: int.parse(amountController.text.replaceAll(',', '')),
      note: noteController.text,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: LText(
          widget.template == null ? 'Template အသစ်' : 'Template ပြင်ရန်',
        ),
        actions: [
          IconButton(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.check),
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
          if (type == TransactionType.transfer) {
            targetAccountId ??=
                accounts.where((item) => item.id != accountId).firstOrNull?.id;
          }
          return Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: LText('အသုံးစရိတ်'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: LText('ဝင်ငွေ'),
                    ),
                    ButtonSegment(
                      value: TransactionType.transfer,
                      label: LText('ငွေလွှဲ'),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (values) => setState(() {
                    type = values.first;
                    category = categories.first;
                  }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.tr('Template အမည်'),
                    prefixIcon: Icon(Icons.bookmark_outline),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Template အမည်ထည့်ပါ'
                      : null,
                ),
                const SizedBox(height: 12),
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
                  onTap: () => openAmountCalculator(
                    context,
                    amountController,
                    allowZero: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr('ငွေပမာဏ'),
                    suffixText: AppPreferencesScope.of(context).currency,
                    prefixIcon: Icon(Icons.calculate_outlined),
                  ),
                  validator: (value) {
                    final amount = int.tryParse(
                      (value ?? '').replaceAll(',', ''),
                    );
                    return amount == null || amount < 0
                        ? 'ငွေပမာဏကို 0 သို့မဟုတ် အပေါင်းကိန်းထည့်ပါ'
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
                if (type == TransactionType.transfer) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value:
                        targetAccountId == accountId ? null : targetAccountId,
                    decoration: InputDecoration(
                      labelText: context.tr('လက်ခံမည့်အကောင့်'),
                      prefixIcon: Icon(Icons.move_to_inbox_outlined),
                    ),
                    items: accounts
                        .where((item) => item.id != accountId)
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: LText(item.name),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'အကောင့်ရွေးပါ' : null,
                    onChanged: (value) =>
                        setState(() => targetAccountId = value),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.tr('မှတ်ချက် (မဖြည့်လည်းရသည်)'),
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.check),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    child: LText('Template သိမ်းမည်'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Color _typeColor(TransactionType type) =>
    type == TransactionType.expense ? AppColors.coral : AppColors.emerald;

IconData _typeIcon(TransactionType type) => switch (type) {
      TransactionType.income => Icons.arrow_upward,
      TransactionType.expense => Icons.arrow_downward,
      TransactionType.transfer => Icons.swap_horiz,
    };
