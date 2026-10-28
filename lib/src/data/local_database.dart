import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();
  Database? _database;

  Future<void> open() async {
    final root = await getDatabasesPath();
    _database = await openDatabase(
      p.join(root, 'dgzone_money.db'),
      version: 11,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            opening_balance INTEGER NOT NULL DEFAULT 0,
            account_number TEXT,
            credit_limit INTEGER NOT NULL DEFAULT 0,
            goal_amount INTEGER NOT NULL DEFAULT 0,
            color_value INTEGER NOT NULL DEFAULT 4279286145,
            icon_code_point INTEGER NOT NULL DEFAULT 59638,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            category TEXT NOT NULL,
            account_id INTEGER NOT NULL,
            target_account_id INTEGER,
            type TEXT NOT NULL CHECK(type IN ('income','expense','transfer')),
            amount INTEGER NOT NULL CHECK(amount >= 0),
            occurred_at TEXT NOT NULL,
            note TEXT,
            receipt_image_path TEXT,
            location_label TEXT,
            latitude REAL,
            longitude REAL,
            created_at TEXT NOT NULL,
            FOREIGN KEY(account_id) REFERENCES accounts(id)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_transactions_date ON transactions(occurred_at)',
        );
        await _createBudgetsTable(db);
        await _createRecurringTable(db);
        await _createSettingsTable(db);
        await _createTemplatesTable(db);
        await _createCategoriesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN target_account_id INTEGER',
          );
          await _createBudgetsTable(db);
        }
        if (oldVersion < 3) await _createRecurringTable(db);
        if (oldVersion < 4) await _createSettingsTable(db);
        if (oldVersion < 5) await _createTemplatesTable(db);
        if (oldVersion == 5) await _migrateTemplatesAllowZero(db);
        if (oldVersion < 7) {
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN receipt_image_path TEXT',
          );
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN location_label TEXT',
          );
          await db.execute('ALTER TABLE transactions ADD COLUMN latitude REAL');
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN longitude REAL',
          );
        }
        if (oldVersion < 8) await _createCategoriesTable(db);
        if (oldVersion < 9) {
          await db.execute('ALTER TABLE accounts ADD COLUMN account_number TEXT');
          await db.execute('ALTER TABLE accounts ADD COLUMN credit_limit INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE accounts ADD COLUMN goal_amount INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE accounts ADD COLUMN color_value INTEGER NOT NULL DEFAULT 4279286145');
          await db.execute('ALTER TABLE accounts ADD COLUMN icon_code_point INTEGER NOT NULL DEFAULT 59638');
          await db.execute('ALTER TABLE accounts ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 10) await _migrateRecurringKinds(db);
        if (oldVersion >= 10 && oldVersion < 11) {
          await db.execute(
            'ALTER TABLE recurring_transactions ADD COLUMN interval_days INTEGER',
          );
        }
      },
    );
  }

  static Future<void> _createBudgetsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        limit_amount INTEGER NOT NULL CHECK(limit_amount > 0),
        period_start TEXT NOT NULL,
        period_end TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createRecurringTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income','expense')),
        amount INTEGER NOT NULL CHECK(amount > 0),
        kind TEXT NOT NULL DEFAULT 'scheduled' CHECK(kind IN ('scheduled','receivable','payable')),
        frequency TEXT CHECK(frequency IS NULL OR frequency IN ('weekly','monthly','yearly','custom')),
        interval_days INTEGER CHECK(interval_days IS NULL OR interval_days > 0),
        next_run TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        reminder_days INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY(account_id) REFERENCES accounts(id)
      )
    ''');
  }

  static Future<void> _migrateRecurringKinds(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE recurring_transactions RENAME TO recurring_transactions_old');
    await _createRecurringTable(db);
    await db.execute('''
      INSERT INTO recurring_transactions (
        id, title, category, account_id, type, amount, kind, frequency,
        next_run, enabled, reminder_days, created_at
      )
      SELECT id, title, category, account_id, type, amount, 'scheduled',
        frequency, next_run, enabled, reminder_days, created_at
      FROM recurring_transactions_old
    ''');
    await db.execute('DROP TABLE recurring_transactions_old');
  }

  static Future<void> _migrateTemplatesAllowZero(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE transaction_templates RENAME TO transaction_templates_old',
    );
    await _createTemplatesTable(db);
    await db.execute('''
      INSERT INTO transaction_templates (
        id, name, title, category, account_id, target_account_id,
        type, amount, note, created_at
      )
      SELECT
        id, name, title, category, account_id, target_account_id,
        type, amount, note, created_at
      FROM transaction_templates_old
    ''');
    await db.execute('DROP TABLE transaction_templates_old');
  }

  static Future<void> _createSettingsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createTemplatesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transaction_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        target_account_id INTEGER,
        type TEXT NOT NULL CHECK(type IN ('income','expense','transfer')),
        amount INTEGER NOT NULL CHECK(amount >= 0),
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createCategoriesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS money_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income','expense')),
        color_value INTEGER NOT NULL,
        icon_code_point INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        UNIQUE(name, type)
      )
    ''');
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM money_categories'),
        ) ??
        0;
    if (count > 0) return;
    const expense = [
      ['စားသောက်စရိတ်', 0xFF10B981, 0xe25a],
      ['သယ်ယူပို့ဆောင်ရေး', 0xFFFF5B55, 0xe1d7],
      ['အိမ်အသုံးစရိတ်', 0xFFF5B82E, 0xe318],
      ['ဖုန်းနှင့်အင်တာနက်', 0xFF2196F3, 0xe0cd],
      ['ကျန်းမာရေး', 0xFF12B8B0, 0xe3f3],
      ['အခြား', 0xFF7C4DFF, 0xe5d3],
    ];
    const income = [
      ['လစာ', 0xFF079455, 0xe263],
      ['စီးပွားရေး', 0xFF2196F3, 0xe8f9],
      ['အပိုဝင်ငွေ', 0xFFF5B82E, 0xe8f6],
      ['အခြား', 0xFF7C4DFF, 0xe5d3],
    ];
    var order = 0;
    for (final row in expense) {
      await db.insert('money_categories', {
        'name': row[0], 'type': 'expense', 'color_value': row[1],
        'icon_code_point': row[2], 'sort_order': order++,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    order = 0;
    for (final row in income) {
      await db.insert('money_categories', {
        'name': row[0], 'type': 'income', 'color_value': row[1],
        'icon_code_point': row[2], 'sort_order': order++,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Database get db {
    final value = _database;
    if (value == null) throw StateError('Database has not been opened.');
    return value;
  }

  /// Closes SQLite before a destructive restore and reopens it afterwards.
  /// Callers should always use [reopen] in a finally block.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> reopen() => open();

  Future<String?> readSetting(String key) async {
    final rows = await db.query(
      'app_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['setting_value'] as String;
  }

  Future<void> saveSetting(String key, String value) async {
    await db.insert(
        'app_settings',
        {
          'setting_key': key,
          'setting_value': value,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> transactionExists({
    required DateTime date,
    required String title,
    required TransactionType type,
    required int amount,
  }) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery(
            '''
            SELECT COUNT(*) FROM transactions
            WHERE date(occurred_at)=date(?) AND title=? AND type=? AND amount=?
            ''',
            [date.toIso8601String(), title.trim(), type.name, amount],
          ),
        ) ??
        0;
    return count > 0;
  }

  Future<List<MoneyCategory>> categories(TransactionType type) async {
    final rows = await db.rawQuery('''
      SELECT c.*, COALESCE(SUM(t.amount), 0) total_amount
      FROM money_categories c
      LEFT JOIN transactions t ON t.category=c.name AND t.type=c.type
      WHERE c.type=?
      GROUP BY c.id
      ORDER BY c.sort_order, c.id
    ''', [type.name]);
    return rows.map((row) => MoneyCategory(
      id: row['id'] as int,
      name: row['name'] as String,
      type: TransactionType.values.byName(row['type'] as String),
      colorValue: row['color_value'] as int,
      iconCodePoint: row['icon_code_point'] as int,
      sortOrder: row['sort_order'] as int,
      totalAmount: row['total_amount'] as int,
    )).toList();
  }

  Future<int> saveCategory({
    int? id,
    required String name,
    required TransactionType type,
    required int colorValue,
    required int iconCodePoint,
  }) async {
    final values = <String, Object?>{
      'name': name.trim(), 'type': type.name, 'color_value': colorValue,
      'icon_code_point': iconCodePoint,
    };
    if (id == null) {
      values['sort_order'] = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COALESCE(MAX(sort_order), -1) + 1 FROM money_categories WHERE type=?',
            [type.name],
          )) ?? 0;
      values['created_at'] = DateTime.now().toIso8601String();
      return db.insert('money_categories', values);
    }
    await db.update('money_categories', values, where: 'id=?', whereArgs: [id]);
    return id;
  }

  Future<void> deleteCategory(int id) async {
    await db.delete('money_categories', where: 'id=?', whereArgs: [id]);
  }

  Future<void> reorderCategories(TransactionType type, List<int> ids) async {
    await db.transaction((txn) async {
      for (var index = 0; index < ids.length; index++) {
        await txn.update('money_categories', {'sort_order': index},
            where: 'id=? AND type=?', whereArgs: [ids[index], type.name]);
      }
    });
  }

  /// New installations intentionally start without accounts or transactions.
  /// The onboarding flow guides the user to create the first real account.
  Future<void> seedIfEmpty() async {}

  Future<DashboardSnapshot> dashboard() async {
    final summary = (await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END), 0) income,
        COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0) expense
      FROM transactions
      WHERE strftime('%Y-%m', occurred_at) = strftime('%Y-%m', 'now', 'localtime')
    ''')).first;
    final income = summary['income'] as int;
    final expense = summary['expense'] as int;
    final recentRows = await db.rawQuery('''
      SELECT t.*,
        c.icon_code_point AS category_icon_code_point,
        c.color_value AS category_color_value
      FROM transactions t
      LEFT JOIN money_categories c
        ON c.name=t.category AND c.type=t.type
      ORDER BY t.id DESC
      LIMIT 5
    ''');
    final categories = await db.rawQuery('''
      SELECT category, SUM(amount) total
      FROM transactions
      WHERE type='expense'
        AND strftime('%Y-%m', occurred_at) = strftime('%Y-%m', 'now', 'localtime')
      GROUP BY category
      ORDER BY total DESC
    ''');
    final accountItems = await accounts();
    final balance = accountItems.fold<int>(
      0,
      (total, account) => total + account.currentBalance,
    );
    return DashboardSnapshot(
      balance: balance,
      income: income,
      expense: expense,
      recent: recentRows.map(_transactionFromMap).toList(),
      categoryTotals: {
        for (final row in categories)
          row['category'] as String: row['total'] as int,
      },
    );
  }

  Future<List<MoneyAccount>> accounts() async {
    final rows = await db.rawQuery('''
      SELECT a.*,
        a.opening_balance
        + COALESCE(SUM(CASE WHEN t.type='income' AND t.account_id=a.id THEN t.amount ELSE 0 END), 0)
        - COALESCE(SUM(CASE WHEN t.type='expense' AND t.account_id=a.id THEN t.amount ELSE 0 END), 0)
        - COALESCE(SUM(CASE WHEN t.type='transfer' AND t.account_id=a.id THEN t.amount ELSE 0 END), 0)
        + COALESCE(SUM(CASE WHEN t.type='transfer' AND t.target_account_id=a.id THEN t.amount ELSE 0 END), 0)
        AS current_balance
      FROM accounts a
      LEFT JOIN transactions t ON t.account_id=a.id OR t.target_account_id=a.id
      GROUP BY a.id
      ORDER BY a.sort_order, a.id
    ''');
    return rows
        .map(
          (row) => MoneyAccount(
            id: row['id'] as int,
            name: row['name'] as String,
            type: row['type'] as String,
            openingBalance: row['opening_balance'] as int,
            currentBalance: row['current_balance'] as int,
            accountNumber: row['account_number'] as String?,
            creditLimit: row['credit_limit'] as int,
            goalAmount: row['goal_amount'] as int,
            colorValue: row['color_value'] as int,
            iconCodePoint: row['icon_code_point'] as int,
            sortOrder: row['sort_order'] as int,
          ),
        )
        .toList();
  }

  Future<List<MoneyTransaction>> transactions({
    String query = '',
    TransactionType? type,
  }) async {
    final conditions = <String>[];
    final arguments = <Object?>[];
    if (query.trim().isNotEmpty) {
      conditions.add('(title LIKE ? OR category LIKE ? OR note LIKE ?)');
      final pattern = '%${query.trim()}%';
      arguments.addAll([pattern, pattern, pattern]);
    }
    if (type != null) {
      conditions.add('type = ?');
      arguments.add(type.name);
    }
    final rows = await db.query(
      'transactions',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments,
      orderBy: 'id DESC',
    );
    return rows.map(_transactionFromMap).toList();
  }

  Future<int> saveTransaction({
    int? id,
    required String title,
    required String category,
    required int accountId,
    required TransactionType type,
    required int amount,
    required DateTime occurredAt,
    int? targetAccountId,
    String? note,
    String? receiptImagePath,
    String? locationLabel,
    double? latitude,
    double? longitude,
  }) async {
    final values = <String, Object?>{
      'title': title.trim(),
      'category': category.trim(),
      'account_id': accountId,
      'type': type.name,
      'amount': amount,
      'occurred_at': occurredAt.toIso8601String(),
      'target_account_id': targetAccountId,
      'note': note?.trim(),
      'receipt_image_path': receiptImagePath,
      'location_label': locationLabel?.trim(),
      'latitude': latitude,
      'longitude': longitude,
    };
    if (id == null) {
      values['created_at'] = DateTime.now().toIso8601String();
      return db.insert('transactions', values);
    }
    await db.update('transactions', values, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<void> deleteTransaction(int id) async {
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TransactionTemplate>> transactionTemplates() async {
    final rows = await db.query(
      'transaction_templates',
      orderBy: 'created_at DESC, id DESC',
    );
    return rows
        .map(
          (row) => TransactionTemplate(
            id: row['id'] as int,
            name: row['name'] as String,
            title: row['title'] as String,
            category: row['category'] as String,
            accountId: row['account_id'] as int,
            targetAccountId: row['target_account_id'] as int?,
            type: TransactionType.values.byName(row['type'] as String),
            amount: row['amount'] as int,
            note: row['note'] as String?,
          ),
        )
        .toList();
  }

  Future<int> saveTransactionTemplate({
    int? id,
    required String name,
    required String title,
    required String category,
    required int accountId,
    required TransactionType type,
    required int amount,
    int? targetAccountId,
    String? note,
  }) async {
    final values = <String, Object?>{
      'name': name.trim(),
      'title': title.trim(),
      'category': category,
      'account_id': accountId,
      'target_account_id': targetAccountId,
      'type': type.name,
      'amount': amount,
      'note': note?.trim(),
    };
    if (id == null) {
      values['created_at'] = DateTime.now().toIso8601String();
      return db.insert('transaction_templates', values);
    }
    await db.update(
      'transaction_templates',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<void> deleteTransactionTemplate(int id) async {
    await db.delete('transaction_templates', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> saveAccount({
    int? id,
    required String name,
    required String type,
    required int openingBalance,
    String? accountNumber,
    int creditLimit = 0,
    int goalAmount = 0,
    int colorValue = 0xFF10B981,
    int iconCodePoint = 0xe8f6,
  }) async {
    final values = <String, Object?>{
      'name': name.trim(),
      'type': type,
      'opening_balance': openingBalance,
      'account_number': accountNumber?.trim(),
      'credit_limit': creditLimit,
      'goal_amount': goalAmount,
      'color_value': colorValue,
      'icon_code_point': iconCodePoint,
    };
    if (id == null) {
      values['sort_order'] = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COALESCE(MAX(sort_order), -1) + 1 FROM accounts'),
          ) ?? 0;
      values['created_at'] = DateTime.now().toIso8601String();
      return db.insert('accounts', values);
    }
    await db.update('accounts', values, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<void> reorderAccounts(List<int> ids) async {
    await db.transaction((txn) async {
      for (var index = 0; index < ids.length; index++) {
        await txn.update('accounts', {'sort_order': index}, where: 'id=?', whereArgs: [ids[index]]);
      }
    });
  }

  Future<bool> deleteAccount(int id) async {
    final used = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM transactions WHERE account_id=? OR target_account_id=?',
            [id, id],
          ),
        ) ??
        0;
    if (used > 0) return false;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    return true;
  }

  Future<List<BudgetProgress>> budgets() async {
    final rows = await db.rawQuery('''
      SELECT b.*,
        COALESCE(SUM(CASE WHEN t.type='expense' THEN t.amount ELSE 0 END), 0) spent_amount
      FROM budgets b
      LEFT JOIN transactions t ON t.category=b.category
        AND datetime(t.occurred_at) BETWEEN datetime(b.period_start) AND datetime(b.period_end)
      GROUP BY b.id
      ORDER BY b.period_start DESC, b.name
    ''');
    return rows
        .map(
          (row) => BudgetProgress(
            id: row['id'] as int,
            name: row['name'] as String,
            category: row['category'] as String,
            limitAmount: row['limit_amount'] as int,
            spentAmount: row['spent_amount'] as int,
            periodStart: DateTime.parse(row['period_start'] as String),
            periodEnd: DateTime.parse(row['period_end'] as String),
          ),
        )
        .toList();
  }

  Future<int> saveBudget({
    int? id,
    required String name,
    required String category,
    required int limitAmount,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final values = <String, Object?>{
      'name': name.trim(),
      'category': category,
      'limit_amount': limitAmount,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
    };
    if (id == null) {
      values['created_at'] = DateTime.now().toIso8601String();
      return db.insert('budgets', values);
    }
    await db.update('budgets', values, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<void> deleteBudget(int id) async {
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<ReportSnapshot> report({DateTime? month}) async {
    final selected = month ?? DateTime.now();
    final prefix =
        '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}';
    final items = await transactions();
    final monthItems = items
        .where(
          (item) => item.occurredAt.toIso8601String().startsWith(prefix),
        )
        .toList();
    var income = 0;
    var expense = 0;
    final categories = <String, int>{};
    final weeklyIncome = List<int>.filled(4, 0);
    final weeklyExpense = List<int>.filled(4, 0);
    for (final item in monthItems) {
      final rawWeek = (item.occurredAt.day - 1) ~/ 7;
      final week = rawWeek > 3 ? 3 : rawWeek;
      if (item.type == TransactionType.income) {
        income += item.amount;
        weeklyIncome[week] += item.amount;
      } else if (item.type == TransactionType.expense) {
        expense += item.amount;
        weeklyExpense[week] += item.amount;
        categories[item.category] =
            (categories[item.category] ?? 0) + item.amount;
      }
    }
    return ReportSnapshot(
      income: income,
      expense: expense,
      categoryTotals: categories,
      weeklyIncome: weeklyIncome,
      weeklyExpense: weeklyExpense,
      transactions: monthItems,
    );
  }

  Future<ReportSnapshot> reportRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final items = (await transactions())
        .where((item) => !item.occurredAt.isBefore(start) && item.occurredAt.isBefore(end))
        .toList();
    var income = 0;
    var expense = 0;
    final categories = <String, int>{};
    final segmentIncome = List<int>.filled(4, 0);
    final segmentExpense = List<int>.filled(4, 0);
    final totalDays = math.max(1, end.difference(start).inDays);
    for (final item in items) {
      final segment = math.min(3, item.occurredAt.difference(start).inDays * 4 ~/ totalDays);
      if (item.type == TransactionType.income) {
        income += item.amount;
        segmentIncome[segment] += item.amount;
      } else if (item.type == TransactionType.expense) {
        expense += item.amount;
        segmentExpense[segment] += item.amount;
        categories[item.category] = (categories[item.category] ?? 0) + item.amount;
      }
    }
    return ReportSnapshot(
      income: income,
      expense: expense,
      categoryTotals: categories,
      weeklyIncome: segmentIncome,
      weeklyExpense: segmentExpense,
      transactions: items,
    );
  }

  Future<List<RecurringTransaction>> recurringTransactions() async {
    final rows = await db.rawQuery('''
      SELECT r.*, a.name AS account_name,
        COALESCE(c.color_value, 4279286145) AS category_color_value,
        COALESCE(c.icon_code_point, 58835) AS category_icon_code_point
      FROM recurring_transactions r
      LEFT JOIN accounts a ON a.id=r.account_id
      LEFT JOIN money_categories c ON c.name=r.category AND c.type=r.type
      ORDER BY r.enabled DESC,
        CASE WHEN r.next_run IS NULL THEN 1 ELSE 0 END,
        datetime(r.next_run), r.id DESC
    ''');
    return rows
        .map(
          (row) => RecurringTransaction(
            id: row['id'] as int,
            title: row['title'] as String,
            category: row['category'] as String,
            accountId: row['account_id'] as int,
            type: TransactionType.values.byName(row['type'] as String),
            amount: row['amount'] as int,
            kind: row['kind'] as String? ?? 'scheduled',
            frequency: row['frequency'] as String?,
            intervalDays: row['interval_days'] as int?,
            nextRun: row['next_run'] == null
                ? null
                : DateTime.parse(row['next_run'] as String),
            enabled: (row['enabled'] as int) == 1,
            reminderDays: row['reminder_days'] as int,
            accountName: row['account_name'] as String? ?? '',
            categoryColorValue: row['category_color_value'] as int,
            categoryIconCodePoint: row['category_icon_code_point'] as int,
          ),
        )
        .toList();
  }

  Future<int> saveRecurring({
    int? id,
    required String title,
    required String category,
    required int accountId,
    required TransactionType type,
    required int amount,
    required String kind,
    String? frequency,
    int? intervalDays,
    DateTime? nextRun,
    required bool enabled,
    required int reminderDays,
  }) async {
    final values = <String, Object?>{
      'title': title.trim(),
      'category': category,
      'account_id': accountId,
      'type': type.name,
      'amount': amount,
      'kind': kind,
      'frequency': frequency,
      'interval_days': intervalDays,
      'next_run': nextRun?.toIso8601String(),
      'enabled': enabled ? 1 : 0,
      'reminder_days': reminderDays,
    };
    if (id == null) {
      values['created_at'] = DateTime.now().toIso8601String();
      return db.insert('recurring_transactions', values);
    }
    await db.update(
      'recurring_transactions',
      values,
      where: 'id=?',
      whereArgs: [id],
    );
    return id;
  }

  Future<void> toggleRecurring(int id, bool enabled) async {
    await db.update(
      'recurring_transactions',
      {'enabled': enabled ? 1 : 0},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRecurring(int id) async {
    await db.delete('recurring_transactions', where: 'id=?', whereArgs: [id]);
  }

  Future<int> postDueRecurring() async {
    final now = DateTime.now();
    return db.transaction((txn) async {
      final due = await txn.query(
        'recurring_transactions',
        where: "enabled = 1 AND kind = 'scheduled' AND next_run IS NOT NULL AND datetime(next_run) <= datetime(?)",
        whereArgs: [now.toIso8601String()],
        orderBy: 'datetime(next_run), id',
      );
      var posted = 0;
      for (final item in due) {
        var runAt = DateTime.parse(item['next_run'] as String);
        var safety = 0;
        while (!runAt.isAfter(now) && safety < 120) {
          await txn.insert('transactions', {
            'title': item['title'] as String,
            'category': item['category'] as String,
            'account_id': item['account_id'] as int,
            'type': item['type'] as String,
            'amount': item['amount'] as int,
            'occurred_at': runAt.toIso8601String(),
            'note': 'ပုံမှန်စာရင်းမှ အလိုအလျောက်ထည့်ထားသည်',
            'created_at': DateTime.now().toIso8601String(),
          });
          final frequency = item['frequency'] as String;
          runAt = switch (frequency) {
            'weekly' => runAt.add(const Duration(days: 7)),
            'yearly' => _clampedDate(runAt.year + 1, runAt.month, runAt.day),
            'custom' => runAt.add(
                Duration(days: (item['interval_days'] as int?) ?? 1),
              ),
            _ => _clampedDate(runAt.year, runAt.month + 1, runAt.day),
          };
          posted++;
          safety++;
        }

        // Keep the recurring rule. Only advance its next due date.
        await txn.update(
          'recurring_transactions',
          {'next_run': runAt.toIso8601String()},
          where: 'id = ?',
          whereArgs: [item['id'] as int],
        );
      }
      return posted;
    });
  }

  DateTime _clampedDate(int year, int month, int day) {
    final normalized = DateTime(year, month, 1);
    final lastDay = DateTime(normalized.year, normalized.month + 1, 0).day;
    return DateTime(normalized.year, normalized.month, math.min(day, lastDay));
  }

  Future<void> resetAllData() async {
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('recurring_transactions');
      await txn.delete('transaction_templates');
      await txn.delete('accounts');
      await txn.insert('accounts', {
        'name': 'လက်ငင်းငွေ',
        'type': 'cash',
        'opening_balance': 0,
        'created_at': now,
      });
    });
  }

  MoneyTransaction _transactionFromMap(Map<String, Object?> map) {
    return MoneyTransaction(
      id: map['id'] as int,
      title: map['title'] as String,
      category: map['category'] as String,
      accountId: map['account_id'] as int,
      type: TransactionType.values.byName(map['type'] as String),
      amount: map['amount'] as int,
      occurredAt: DateTime.parse(map['occurred_at'] as String),
      targetAccountId: map['target_account_id'] as int?,
      note: map['note'] as String?,
      receiptImagePath: map['receipt_image_path'] as String?,
      locationLabel: map['location_label'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      categoryIconCodePoint: map['category_icon_code_point'] as int?,
      categoryColorValue: map['category_color_value'] as int?,
    );
  }
}
