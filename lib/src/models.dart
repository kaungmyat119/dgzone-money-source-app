enum TransactionType { income, expense, transfer }

class MoneyCategory {
  const MoneyCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.colorValue,
    required this.iconCodePoint,
    required this.sortOrder,
    this.totalAmount = 0,
  });

  final int id;
  final String name;
  final TransactionType type;
  final int colorValue;
  final int iconCodePoint;
  final int sortOrder;
  final int totalAmount;
}

class MoneyAccount {
  const MoneyAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    this.currentBalance = 0,
    this.accountNumber,
    this.creditLimit = 0,
    this.goalAmount = 0,
    this.colorValue = 0xFF10B981,
    this.iconCodePoint = 0xe8f6,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final String type;
  final int openingBalance;
  final int currentBalance;
  final String? accountNumber;
  final int creditLimit;
  final int goalAmount;
  final int colorValue;
  final int iconCodePoint;
  final int sortOrder;
}

class MoneyTransaction {
  const MoneyTransaction({
    required this.id,
    required this.title,
    required this.category,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.occurredAt,
    this.targetAccountId,
    this.note,
    this.receiptImagePath,
    this.locationLabel,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String title;
  final String category;
  final int accountId;
  final TransactionType type;
  final int amount;
  final DateTime occurredAt;
  final int? targetAccountId;
  final String? note;
  final String? receiptImagePath;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
}

class TransactionTemplate {
  const TransactionTemplate({
    required this.id,
    required this.name,
    required this.title,
    required this.category,
    required this.accountId,
    required this.type,
    required this.amount,
    this.targetAccountId,
    this.note,
  });

  final int id;
  final String name;
  final String title;
  final String category;
  final int accountId;
  final TransactionType type;
  final int amount;
  final int? targetAccountId;
  final String? note;
}

class BudgetProgress {
  const BudgetProgress({
    required this.id,
    required this.name,
    required this.category,
    required this.limitAmount,
    required this.spentAmount,
    required this.periodStart,
    required this.periodEnd,
  });

  final int id;
  final String name;
  final String category;
  final int limitAmount;
  final int spentAmount;
  final DateTime periodStart;
  final DateTime periodEnd;

  double get ratio => limitAmount == 0 ? 0 : spentAmount / limitAmount;
  int get remaining => limitAmount - spentAmount;
}

class ReportSnapshot {
  const ReportSnapshot({
    required this.income,
    required this.expense,
    required this.categoryTotals,
    required this.weeklyIncome,
    required this.weeklyExpense,
    required this.transactions,
  });

  final int income;
  final int expense;
  final Map<String, int> categoryTotals;
  final List<int> weeklyIncome;
  final List<int> weeklyExpense;
  final List<MoneyTransaction> transactions;
  int get saving => income - expense;
}

class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.title,
    required this.category,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.frequency,
    required this.nextRun,
    required this.enabled,
    required this.reminderDays,
    this.accountName = '',
    this.categoryColorValue = 0xFF10B981,
    this.categoryIconCodePoint = 0xe5d3,
  });

  final int id;
  final String title;
  final String category;
  final int accountId;
  final TransactionType type;
  final int amount;
  final String frequency;
  final DateTime nextRun;
  final bool enabled;
  final int reminderDays;
  final String accountName;
  final int categoryColorValue;
  final int categoryIconCodePoint;

  bool get dueSoon =>
      enabled && nextRun.difference(DateTime.now()).inDays <= reminderDays;

  int get daysUntilDue {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final due = DateTime(nextRun.year, nextRun.month, nextRun.day);
    return due.difference(start).inDays;
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.balance,
    required this.income,
    required this.expense,
    required this.recent,
    required this.categoryTotals,
  });

  final int balance;
  final int income;
  final int expense;
  final List<MoneyTransaction> recent;
  final Map<String, int> categoryTotals;
}
