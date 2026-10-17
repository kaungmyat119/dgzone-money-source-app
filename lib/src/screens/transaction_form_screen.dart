import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../data/local_database.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import 'amount_calculator_screen.dart';
import 'receipt_image_viewer.dart';
import 'templates_screen.dart';

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({
    super.key,
    required this.database,
    this.transaction,
    this.initialType,
  });

  final LocalDatabase database;
  final MoneyTransaction? transaction;
  final TransactionType? initialType;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  static const transferCategory = 'ငွေလွှဲ';
  final formKey = GlobalKey<FormState>();
  late final TextEditingController amountController;
  late final TextEditingController titleController;
  late final TextEditingController noteController;
  late final TextEditingController locationController;
  late TransactionType type;
  late String category;
  late DateTime occurredAt;
  int? accountId;
  int? targetAccountId;
  bool saving = false;
  bool locating = false;
  String? receiptImagePath;
  double? latitude;
  double? longitude;

  List<String> expenseCategories = [
    'စားသောက်စရိတ်',
    'သယ်ယူပို့ဆောင်ရေး',
    'အိမ်အသုံးစရိတ်',
    'ဖုန်းနှင့်အင်တာနက်',
    'ကျန်းမာရေး',
    'အခြား',
  ];
  List<String> incomeCategories = ['လစာ', 'စီးပွားရေး', 'အပိုဝင်ငွေ', 'အခြား'];

  @override
  void initState() {
    super.initState();
    final item = widget.transaction;
    type = item?.type ?? widget.initialType ?? TransactionType.expense;
    category = item?.category ??
        (type == TransactionType.income
            ? incomeCategories.first
            : expenseCategories.first);
    occurredAt = item?.occurredAt ?? DateTime.now();
    accountId = item?.accountId;
    targetAccountId = item?.targetAccountId;
    amountController = TextEditingController(
      text: item?.amount.toString() ?? '',
    );
    titleController = TextEditingController(text: item?.title ?? '');
    noteController = TextEditingController(text: item?.note ?? '');
    locationController = TextEditingController(text: item?.locationLabel ?? '');
    receiptImagePath = item?.receiptImagePath;
    latitude = item?.latitude;
    longitude = item?.longitude;
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
    amountController.dispose();
    titleController.dispose();
    noteController.dispose();
    locationController.dispose();
    super.dispose();
  }

  List<String> get categories =>
      type == TransactionType.income ? incomeCategories : expenseCategories;

  Future<void> pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (result != null) setState(() => occurredAt = result);
  }

  Future<void> openCalculator() async {
    final current =
        int.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
    final amount = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => AmountCalculatorScreen(initialAmount: current),
      ),
    );
    if (amount != null) {
      amountController.text = NumberFormat('#,##0').format(amount);
    }
  }

  Future<void> chooseReceiptSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const LText('ကင်မရာဖြင့် ရိုက်မည်'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const LText('Gallery မှ ရွေးမည်'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (image == null) return;
      final documents = await getApplicationDocumentsDirectory();
      final receipts = Directory(path.join(documents.path, 'receipts'));
      await receipts.create(recursive: true);
      final destination = path.join(
        receipts.path,
        'receipt_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}',
      );
      await File(image.path).copy(destination);
      if (mounted) setState(() => receiptImagePath = destination);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LText('ပြေစာပုံ ရယူ၍မရပါ။ Permission စစ်ပေးပါ။'),
        ),
      );
    }
  }

  Future<void> useCurrentLocation() async {
    setState(() => locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationServiceDisabledException();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException('Location permission denied');
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
        locationController.text =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LText('Location မရပါ။ GPS နှင့် Permission ကို စစ်ပေးပါ။'),
        ),
      );
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || accountId == null) return;
    setState(() => saving = true);
    await widget.database.saveTransaction(
      id: widget.transaction?.id,
      title: titleController.text,
      category: type == TransactionType.transfer ? transferCategory : category,
      accountId: accountId!,
      type: type,
      amount: int.parse(amountController.text.replaceAll(',', '')),
      occurredAt: occurredAt,
      targetAccountId:
          type == TransactionType.transfer ? targetAccountId : null,
      note: noteController.text,
      receiptImagePath: receiptImagePath,
      locationLabel: locationController.text,
      latitude: latitude,
      longitude: longitude,
    );
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> openTemplates(List<MoneyAccount> accounts) async {
    final template = await Navigator.push<TransactionTemplate>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TemplatesScreen(database: widget.database, initialType: type),
      ),
    );
    if (template != null) applyTemplate(template, accounts);
  }

  void applyTemplate(
    TransactionTemplate template,
    List<MoneyAccount> accounts,
  ) {
    final accountIds = accounts.map((item) => item.id).toSet();
    setState(() {
      type = template.type;
      titleController.text = template.title;
      amountController.text = template.amount.toString();
      category = type == TransactionType.transfer
          ? transferCategory
          : categories.contains(template.category)
              ? template.category
              : categories.last;
      accountId = accountIds.contains(template.accountId)
          ? template.accountId
          : accounts.firstOrNull?.id;
      targetAccountId = accountIds.contains(template.targetAccountId) &&
              template.targetAccountId != accountId
          ? template.targetAccountId
          : accounts.where((item) => item.id != accountId).firstOrNull?.id;
      noteController.text = template.note ?? '';
      occurredAt = DateTime.now();
    });
  }

  Future<void> saveAsTemplate() async {
    if (!formKey.currentState!.validate() || accountId == null) return;
    if (type == TransactionType.transfer && targetAccountId == null) return;
    final nameController = TextEditingController(text: titleController.text);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('Template အဖြစ်သိမ်းရန်'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.tr('Template အမည်'),
            hintText: context.tr('ဥပမာ - ဆီဖိုး၊ နေ့လယ်စာ'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const LText('မသိမ်းပါ'),
          ),
          FilledButton(
            onPressed: () {
              final value = nameController.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const LText('သိမ်းမည်'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null) return;
    await widget.database.saveTransactionTemplate(
      name: name,
      title: titleController.text,
      category: type == TransactionType.transfer ? transferCategory : category,
      accountId: accountId!,
      type: type,
      amount: int.parse(amountController.text.replaceAll(',', '')),
      targetAccountId:
          type == TransactionType.transfer ? targetAccountId : null,
      note: noteController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: LText('Quick Template သိမ်းပြီးပါပြီ')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: LText(
          widget.transaction == null ? 'စာရင်းအသစ်ထည့်ရန်' : 'စာရင်းပြင်ရန်',
        ),
        actions: [
          if (widget.transaction == null)
            IconButton(
              tooltip: context.tr('Template သိမ်းရန်'),
              onPressed: saveAsTemplate,
              icon: const Icon(Icons.playlist_add_check),
            ),
          IconButton(
            tooltip: context.tr('စာရင်းသိမ်းရန်'),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.income,
                      icon: Icon(Icons.arrow_upward),
                      label: LText('ဝင်ငွေ'),
                    ),
                    ButtonSegment(
                      value: TransactionType.expense,
                      icon: Icon(Icons.arrow_downward),
                      label: LText('အသုံးစရိတ်'),
                    ),
                    ButtonSegment(
                      value: TransactionType.transfer,
                      icon: Icon(Icons.swap_horiz),
                      label: LText('ငွေလွှဲ'),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) {
                    setState(() {
                      type = value.first;
                      category = type == TransactionType.transfer
                          ? transferCategory
                          : categories.first;
                    });
                  },
                ),
                if (widget.transaction == null) ...[
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => openTemplates(accounts),
                      child: const ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.mintSoft,
                          child: Icon(
                            Icons.bookmarks_outlined,
                            color: AppColors.emeraldDark,
                          ),
                        ),
                        title: LText(
                          'Template အသုံးပြုမည်',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        subtitle: LText('သိမ်းထားသောစာရင်းကို ရွေးချယ်ရန်'),
                        trailing: Icon(Icons.chevron_right),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                TextFormField(
                  controller: amountController,
                  readOnly: true,
                  onTap: openCalculator,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
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
                    return amount == null || amount <= 0
                        ? 'မှန်ကန်သောငွေပမာဏထည့်ပါ'
                        : null;
                  },
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
                const SizedBox(height: 14),
                if (type != TransactionType.transfer) DropdownButtonFormField<String>(
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
                if (type != TransactionType.transfer) const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: accountId,
                  decoration: InputDecoration(
                    labelText: context.tr('အကောင့်'),
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: accounts
                      .map(
                        (value) => DropdownMenuItem(
                          value: value.id,
                          child: LText(value.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => accountId = value),
                ),
                if (type == TransactionType.transfer) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value:
                        targetAccountId == accountId ? null : targetAccountId,
                    decoration: InputDecoration(
                      labelText: context.tr('လက်ခံမည့်အကောင့်'),
                      prefixIcon: Icon(Icons.move_to_inbox_outlined),
                    ),
                    items: accounts
                        .where((value) => value.id != accountId)
                        .map(
                          (value) => DropdownMenuItem(
                            value: value.id,
                            child: LText(value.name),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'လက်ခံမည့်အကောင့်ရွေးပါ' : null,
                    onChanged: (value) =>
                        setState(() => targetAccountId = value),
                  ),
                ],
                const SizedBox(height: 14),
                ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: const Icon(
                    Icons.calendar_month,
                    color: AppColors.emerald,
                  ),
                  title: const LText('ရက်စွဲ'),
                  subtitle: LText(context.appDate(occurredAt)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: pickDate,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.tr('မှတ်ချက် (မဖြည့်လည်းရသည်)'),
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: context.tr('Location (မဖြည့်လည်းရသည်)'),
                    hintText: context.tr('လိပ်စာရေးပါ သို့မဟုတ် လက်ရှိနေရာယူပါ'),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: IconButton(
                      tooltip: context.tr('လက်ရှိ Location ယူမည်'),
                      onPressed: locating ? null : useCurrentLocation,
                      icon: locating
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ),
                  onChanged: (_) {
                    latitude = null;
                    longitude = null;
                  },
                ),
                const SizedBox(height: 14),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: receiptImagePath == null
                      ? ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.mintSoft,
                            child: Icon(
                              Icons.receipt_long_outlined,
                              color: AppColors.emeraldDark,
                            ),
                          ),
                          title: const LText('ပြေစာပုံ ထည့်မည်'),
                          subtitle: const LText('Camera သို့မဟုတ် Gallery'),
                          trailing: const Icon(Icons.add_a_photo_outlined),
                          onTap: chooseReceiptSource,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GestureDetector(
                              onTap: () => openReceiptImage(
                                context,
                                receiptImagePath!,
                              ),
                              child: Hero(
                                tag: 'receipt:$receiptImagePath',
                                child: Image.file(
                                  File(receiptImagePath!),
                                  height: 190,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    height: 120,
                                    child: Center(
                                      child: LText('ပြေစာပုံ ဖွင့်၍မရပါ'),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: chooseReceiptSource,
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const LText('ပုံပြောင်းမည်'),
                                  ),
                                ),
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () => setState(
                                      () => receiptImagePath = null,
                                    ),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const LText('ဖယ်ရှားမည်'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: LText('သိမ်းမည်'),
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
