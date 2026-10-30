import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/local_database.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.database});
  final LocalDatabase database;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  TransactionType type = TransactionType.expense;
  final search = TextEditingController();
  List<MoneyCategory> items = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final values = await widget.database.categories(type);
    if (mounted) setState(() { items = values; loading = false; });
  }

  Future<void> _edit([MoneyCategory? item, int? parentId]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryEditor(
        database: widget.database,
        type: type,
        item: item,
        categories: items,
        initialParentId: parentId,
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(MoneyCategory item) async {
    if (items.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LText('အနည်းဆုံး အမျိုးအစားတစ်ခု ချန်ထားရပါမည်')),
      );
      return;
    }
    final okay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('အမျိုးအစား ဖျက်မည်လား?'),
        content: LText('“${item.name}” ကို ရွေးချယ်စာရင်းမှ ဖယ်ရှားပါမည်။ ရှိပြီးသားငွေစာရင်းများ မပျက်ပါ။'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const LText('မဖျက်ပါ')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const LText('ဖျက်မည်')),
        ],
      ),
    );
    if (okay == true) { await widget.database.deleteCategory(item.id); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final shown = items.where((item) => item.name.toLowerCase().contains(query)).toList();
    final mains = shown.where((item) => item.parentId == null).toList();
    final matchedParentIds = shown
        .where((item) => item.parentId != null)
        .map((item) => item.parentId!)
        .toSet();
    final visibleMains = query.isEmpty
        ? mains
        : items
            .where((item) =>
                item.parentId == null &&
                (shown.contains(item) || matchedParentIds.contains(item.id)))
            .toList();
    return Scaffold(
      appBar: AppBar(title: const LText('အမျိုးအစားများ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const LText('အသစ်ထည့်မည်'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(value: TransactionType.expense, icon: Icon(Icons.wallet_outlined), label: LText('အသုံးစရိတ်')),
              ButtonSegment(value: TransactionType.income, icon: Icon(Icons.trending_up), label: LText('ဝင်ငွေ')),
            ],
            selected: {type},
            onSelectionChanged: (value) { setState(() { type = value.first; loading = true; }); _load(); },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: context.tr('အမျိုးအစားရှာရန်'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: const Icon(Icons.sort),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Align(alignment: Alignment.centerLeft, child: LText('အဓိကအမျိုးအစား', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : visibleMains.isEmpty
                  ? const Center(child: LText('အမျိုးအစား မရှိသေးပါ'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: visibleMains.length,
                      itemBuilder: (context, index) {
                        final item = visibleMains[index];
                        final color = Color(item.colorValue);
                        final children = items
                            .where((child) =>
                                child.parentId == item.id &&
                                (query.isEmpty || child.name.toLowerCase().contains(query)))
                            .toList();
                        return Card(
                          key: ValueKey(item.id),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withValues(alpha: .14),
                                  child: Icon(IconData(item.iconCodePoint, fontFamily: 'MaterialIcons'), color: color),
                                ),
                                title: LText(item.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                                subtitle: LText('${children.length} ${context.tr('အမျိုးအစားခွဲ')} • ${context.money(item.totalAmount)}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'add') _edit(null, item.id);
                                    if (value == 'edit') _edit(item);
                                    if (value == 'delete') _delete(item);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'add', child: LText('အမျိုးအစားခွဲအသစ်')),
                                    PopupMenuItem(value: 'edit', child: LText('ပြင်မည်')),
                                    PopupMenuItem(value: 'delete', child: LText('ဖျက်မည်')),
                                  ],
                                ),
                              ),
                              if (children.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => _edit(null, item.id),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const LText('အမျိုးအစားခွဲအသစ်'),
                                    ),
                                  ),
                                ),
                              for (final child in children) ...[
                                const Divider(height: 1, indent: 72),
                                ListTile(
                                  contentPadding: const EdgeInsets.only(left: 72, right: 8),
                                  leading: Icon(
                                    IconData(child.iconCodePoint, fontFamily: 'MaterialIcons'),
                                    color: Color(child.colorValue),
                                  ),
                                  title: LText(child.name),
                                  subtitle: LText(context.money(child.totalAmount)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(onPressed: () => _edit(child), icon: const Icon(Icons.edit_outlined)),
                                      IconButton(onPressed: () => _delete(child), icon: const Icon(Icons.delete_outline)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({
    required this.database,
    required this.type,
    required this.categories,
    this.item,
    this.initialParentId,
  });
  final LocalDatabase database;
  final TransactionType type;
  final List<MoneyCategory> categories;
  final MoneyCategory? item;
  final int? initialParentId;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final TextEditingController name;
  late int colorValue;
  late int iconCodePoint;
  late bool isSubcategory;
  int? parentId;
  String iconGroup = 'အားလုံး';
  static const colors = [0xFF10B981, 0xFFFF5B55, 0xFFF5B82E, 0xFF2196F3, 0xFF12B8B0, 0xFF7C4DFF, 0xFF607D8B];
  static const iconGroups = <String, List<IconData>>{
    'နေ့စဉ်': [
      Icons.restaurant, Icons.fastfood, Icons.lunch_dining, Icons.local_cafe,
      Icons.local_bar, Icons.local_grocery_store, Icons.shopping_cart,
      Icons.shopping_bag, Icons.checkroom, Icons.content_cut,
      Icons.dry_cleaning, Icons.local_laundry_service,
    ],
    'သွားလာ': [
      Icons.directions_car, Icons.local_taxi, Icons.directions_bus,
      Icons.two_wheeler, Icons.directions_bike, Icons.train, Icons.flight,
      Icons.directions_boat, Icons.local_gas_station, Icons.ev_station,
      Icons.car_repair, Icons.build,
    ],
    'အိမ်': [
      Icons.home, Icons.apartment, Icons.chair, Icons.bed, Icons.kitchen,
      Icons.electric_bolt, Icons.water_drop, Icons.wifi, Icons.phone_android,
      Icons.lightbulb, Icons.cleaning_services, Icons.construction,
    ],
    'ငွေကြေး/ဘဏ်': [
      Icons.payments, Icons.account_balance, Icons.account_balance_wallet,
      Icons.savings, Icons.credit_card, Icons.currency_exchange,
      Icons.receipt_long, Icons.request_quote, Icons.monetization_on,
      Icons.trending_up, Icons.trending_down, Icons.attach_money,
    ],
    'ကျန်းမာ/ပညာ': [
      Icons.medical_services, Icons.local_hospital, Icons.medication,
      Icons.health_and_safety, Icons.fitness_center, Icons.spa,
      Icons.self_improvement, Icons.child_care, Icons.pets, Icons.school,
      Icons.menu_book, Icons.science,
    ],
    'ဖျော်ဖြေ': [
      Icons.movie, Icons.music_note, Icons.sports_esports, Icons.sports_soccer,
      Icons.sports_basketball, Icons.camera_alt, Icons.celebration,
      Icons.travel_explore, Icons.hotel, Icons.beach_access, Icons.palette,
      Icons.casino,
    ],
    'လုပ်ငန်း': [
      Icons.work, Icons.business_center, Icons.store, Icons.inventory_2,
      Icons.engineering, Icons.computer, Icons.print, Icons.campaign,
      Icons.groups, Icons.handshake, Icons.delivery_dining, Icons.warehouse,
    ],
    'အခြား': [
      Icons.category, Icons.card_giftcard, Icons.volunteer_activism,
      Icons.shield, Icons.gavel, Icons.public, Icons.language, Icons.park,
      Icons.eco, Icons.recycling, Icons.emergency, Icons.more_horiz,
    ],
  };

  static List<IconData> get icons =>
      iconGroups.values.expand((values) => values).toList(growable: false);

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.item?.name ?? '');
    colorValue = widget.item?.colorValue ?? colors.first;
    iconCodePoint = widget.item?.iconCodePoint ?? icons.first.codePoint;
    parentId = widget.item?.parentId ?? widget.initialParentId;
    isSubcategory = parentId != null;
  }

  @override
  void dispose() { name.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) return;
    if (isSubcategory && parentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LText('မိခင်အမျိုးအစား ရွေးပါ')),
      );
      return;
    }
    await widget.database.saveCategory(
      id: widget.item?.id,
      name: name.text,
      type: widget.type,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      parentId: isSubcategory ? parentId : null,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final shownIcons = iconGroup == 'အားလုံး'
        ? icons
        : iconGroups[iconGroup] ?? icons;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            LText(
              widget.item == null ? 'အမျိုးအစားအသစ်' : 'အမျိုးအစားပြင်ရန်',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: name,
              autofocus: false,
              decoration: InputDecoration(
                labelText: context.tr('အမျိုးအစားအမည်'),
              ),
            ),
            const SizedBox(height: 14),
            const LText('အမျိုးအစားအဆင့်'),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: LText('အဓိကအမျိုးအစား')),
                ButtonSegment(value: true, label: LText('အမျိုးအစားခွဲ')),
              ],
              selected: {isSubcategory},
              onSelectionChanged: (value) => setState(() {
                isSubcategory = value.first;
                if (isSubcategory && parentId == null) {
                  final available = widget.categories.where((item) =>
                      item.parentId == null && item.id != widget.item?.id);
                  parentId = available.isEmpty ? null : available.first.id;
                }
              }),
            ),
            if (isSubcategory) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: widget.categories.any((item) => item.id == parentId)
                    ? parentId
                    : null,
                decoration: InputDecoration(
                  labelText: context.tr('မိခင်အမျိုးအစား'),
                  prefixIcon: const Icon(Icons.account_tree_outlined),
                ),
                items: widget.categories
                    .where((item) =>
                        item.parentId == null && item.id != widget.item?.id)
                    .map((item) => DropdownMenuItem(
                          value: item.id,
                          child: LText(item.name),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => parentId = value),
              ),
            ],
            const SizedBox(height: 14),
            const LText('အရောင်ရွေးပါ'),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in colors)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: CircleAvatar(
                          radius: 10,
                          backgroundColor: Color(value),
                        ),
                        selected: colorValue == value,
                        onSelected: (_) => setState(() => colorValue = value),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: LText('Icon ရွေးပါ')),
                LText('${shownIcons.length} Icons'),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final group in ['အားလုံး', ...iconGroups.keys])
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: LText(group),
                        selected: iconGroup == group,
                        onSelected: (_) => setState(() => iconGroup = group),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(vertical: 4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: shownIcons.length,
                itemBuilder: (context, index) {
                  final icon = shownIcons[index];
                  final selected = iconCodePoint == icon.codePoint;
                  return InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () => setState(() => iconCodePoint = icon.codePoint),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? Color(colorValue).withValues(alpha: .22)
                            : AppColors.mintSoft,
                        border: Border.all(
                          color: selected ? Color(colorValue) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: selected ? Color(colorValue) : AppColors.emeraldDark,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const LText('သိမ်းမည်'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
