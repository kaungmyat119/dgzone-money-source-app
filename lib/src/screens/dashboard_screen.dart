import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/local_database.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import 'accounts_screen.dart';
import 'budgets_screen.dart';
import 'recurring_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'transaction_form_screen.dart';
import 'transaction_list_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.database,
    required this.language,
    required this.darkMode,
    required this.onLanguageChanged,
    required this.onDarkModeChanged,
    required this.onCurrencyChanged,
    required this.onDateFormatChanged,
    required this.onSecurityChanged,
    required this.onDataChanged,
  });

  final LocalDatabase database;
  final AppLanguage language;
  final bool darkMode;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<bool> onDarkModeChanged;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<String> onDateFormatChanged;
  final VoidCallback onSecurityChanged;
  final VoidCallback onDataChanged;

  Future<void> _openTransactionForm(
    BuildContext context, {
    TransactionType? initialType,
  }) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
          database: database,
          initialType: initialType,
        ),
      ),
    );
    if (changed == true) onDataChanged();
  }

  Future<void> _openTransactions(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionListScreen(
          database: database,
          onDataChanged: onDataChanged,
        ),
      ),
    );
    // A child route may have added, edited, deleted or auto-posted entries.
    // Refresh the dashboard immediately when returning from that route.
    onDataChanged();
  }

  Future<void> _openBudgets(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BudgetsScreen(database: database, onDataChanged: onDataChanged),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          database: database,
          language: language,
          darkMode: darkMode,
          onLanguageChanged: onLanguageChanged,
          onDarkModeChanged: onDarkModeChanged,
          onCurrencyChanged: onCurrencyChanged,
          onDateFormatChanged: onDateFormatChanged,
          onSecurityChanged: onSecurityChanged,
          onDataChanged: onDataChanged,
        ),
      ),
    );
  }

  Future<void> _editTransaction(
    BuildContext context,
    MoneyTransaction transaction,
  ) async {
    if ((await database.accounts()).isEmpty) {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AccountsScreen(
            database: database,
            onDataChanged: onDataChanged,
          ),
        ),
      );
      if ((await database.accounts()).isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: LText('စာရင်းမထည့်မီ Account အနည်းဆုံးတစ်ခု ဖန်တီးပါ')),
          );
        }
        return;
      }
    }
    if (!context.mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
          database: database,
          transaction: transaction,
        ),
      ),
    );
    if (changed == true) onDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(language);
    return FutureBuilder<DashboardSnapshot>(
      future: database.dashboard(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            titleSpacing: 20,
            title: Row(
              children: [
                Image.asset('assets/images/dgzone_money_logo.png', height: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: LText(
                    'DGzone Money',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF8CF0BD)
                          : AppColors.emeraldDark,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: context.tr('ပုံမှန်စာရင်းနှင့် သတိပေးချက်'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecurringScreen(
                        database: database,
                        onDataChanged: onDataChanged,
                      ),
                    ),
                  );
                  onDataChanged();
                },
                icon: const Icon(Icons.notifications_active_outlined),
              ),
              PopupMenuButton<AppLanguage>(
                icon: const Icon(Icons.language),
                initialValue: language,
                onSelected: onLanguageChanged,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: AppLanguage.myanmar,
                    child: LText('မြန်မာ'),
                  ),
                  PopupMenuItem(
                    value: AppLanguage.english,
                    child: LText('English'),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'accounts') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountsScreen(
                          database: database,
                          onDataChanged: onDataChanged,
                        ),
                      ),
                    );
                  } else if (value == 'budgets') {
                    _openBudgets(context);
                  } else if (value == 'settings') {
                    _openSettings(context);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'accounts',
                    child: ListTile(
                      leading: Icon(Icons.account_balance_wallet_outlined),
                      title: LText('အကောင့်များ'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'budgets',
                    child: ListTile(
                      leading: Icon(Icons.donut_large),
                      title: LText('ဘတ်ဂျက်'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: LText('ဆက်တင်'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _BalanceCard(data: data, strings: strings),
              const SizedBox(height: 14),
              _QuickActions(
                strings: strings,
                onIncome: () => _openTransactionForm(
                  context,
                  initialType: TransactionType.income,
                ),
                onExpense: () => _openTransactionForm(
                  context,
                  initialType: TransactionType.expense,
                ),
                onTransfer: () => _openTransactionForm(
                  context,
                  initialType: TransactionType.transfer,
                ),
                onBudget: () => _openBudgets(context),
              ),
              const SizedBox(height: 18),
              _SectionHeader(title: strings.get('monthly')),
              const SizedBox(height: 10),
              _SpendingCard(data: data),
              const SizedBox(height: 18),
              _SectionHeader(
                title: strings.get('recent'),
                action: strings.get('seeAll'),
                onAction: () => _openTransactions(context),
              ),
              const SizedBox(height: 10),
              _RecentCard(
                data: data,
                onTap: (transaction) => _editTransaction(context, transaction),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (index) {
              if (index == 1) {
                _openTransactions(context);
              } else if (index == 2) {
                _openTransactionForm(context);
              } else if (index == 3) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportsScreen(database: database),
                  ),
                );
              } else if (index == 4) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecurringScreen(
                      database: database,
                      onDataChanged: onDataChanged,
                    ),
                  ),
                );
              }
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: strings.get('home'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                label: strings.get('transactions'),
              ),
              const NavigationDestination(
                icon: Icon(
                  Icons.add_circle,
                  size: 38,
                  color: AppColors.emerald,
                ),
                label: '',
              ),
              NavigationDestination(
                icon: const Icon(Icons.bar_chart),
                label: strings.get('reports'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.event_repeat_outlined),
                selectedIcon: const Icon(Icons.event_repeat),
                label: context.tr('ပုံမှန်စာရင်း'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.data, required this.strings});
  final DashboardSnapshot data;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE4FFF0), Color(0xFFA6F1C7)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LText(
            strings.get('balance'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LText(
            context.money(data.balance),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: 34),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  icon: Icons.arrow_upward,
                  label: strings.get('income'),
                  value: data.income,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryValue(
                  icon: Icons.arrow_downward,
                  label: strings.get('expense'),
                  value: data.expense,
                  color: AppColors.coral,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .14),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  LText(
                    context.money(value),
                    style: TextStyle(fontWeight: FontWeight.w800, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.strings,
    required this.onIncome,
    required this.onExpense,
    required this.onTransfer,
    required this.onBudget,
  });
  final AppStrings strings;
  final VoidCallback onIncome;
  final VoidCallback onExpense;
  final VoidCallback onTransfer;
  final VoidCallback onBudget;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.add, strings.get('income'), AppColors.emerald, onIncome),
      (Icons.remove, strings.get('expense'), AppColors.coral, onExpense),
      (
        Icons.swap_horiz,
        strings.get('transfer'),
        AppColors.emerald,
        onTransfer,
      ),
      (Icons.donut_large, strings.get('budget'), AppColors.emerald, onBudget),
    ];
    return Row(
      children: [
        for (final item in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: item.$4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: item.$3,
                          foregroundColor: Colors.white,
                          child: Icon(item.$1),
                        ),
                        const SizedBox(height: 8),
                        LText(
                          item.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LText(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: LText(action!)),
      ],
    );
  }
}

class _SpendingCard extends StatelessWidget {
  const _SpendingCard({required this.data});
  final DashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final entries = data.categoryTotals.entries.toList();
    const colors = [
      AppColors.coral,
      AppColors.emerald,
      AppColors.amber,
      Color(0xFF4299E1),
      Color(0xFF9CA3AF),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 126,
              height: 126,
              child: CustomPaint(
                painter: _DonutPainter(
                  values: entries.map((e) => e.value).toList(),
                  colors: colors,
                ),
                child: Center(
                  child: LText(
                    context.money(data.expense, compact: true),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                children: [
                  for (var index = 0; index < entries.length; index++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors[index % colors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LText(
                              entries[index].key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          LText(
                            context.money(entries[index].value, compact: true),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});
  final List<int> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;
    if (total == 0) {
      paint.color = AppColors.mintSoft;
      canvas.drawArc(rect.deflate(14), 0, math.pi * 2, false, paint);
      return;
    }
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index] / total * math.pi * 2;
      paint.color = colors[index % colors.length];
      canvas.drawArc(rect.deflate(14), start, sweep - .025, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.data, required this.onTap});
  final DashboardSnapshot data;
  final ValueChanged<MoneyTransaction> onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < data.recent.length; index++) ...[
            _TransactionTile(
              transaction: data.recent[index],
              onTap: () => onTap(data.recent[index]),
            ),
            if (index != data.recent.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.onTap});
  final MoneyTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final income = transaction.type == TransactionType.income;
    final color = income ? AppColors.emerald : AppColors.coral;
    final icon = income
        ? Icons.payments
        : transaction.category.contains('စား')
            ? Icons.restaurant
            : transaction.category.contains('ပို့')
                ? Icons.local_gas_station
                : Icons.receipt_long;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .12),
        child: Icon(icon, color: color),
      ),
      title: LText(
        transaction.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: LText(transaction.category),
      trailing: LText(
        '${income ? '+' : '−'} ${context.money(transaction.amount)}',
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
