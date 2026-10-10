import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/local_database.dart';
import '../models.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Yangon'));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    final ios = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
    return android ?? ios ?? true;
  }

  Future<void> syncRecurring(LocalDatabase database) async {
    await initialize();
    await _plugin.cancelAll();
    final enabled = await database.readSetting('notifications') == 'true';
    if (!enabled) {
      return;
    }
    final items = await database.recurringTransactions();
    final currency = await database.readSetting('currency') ?? 'MMK';
    for (final item in items) {
      if (item.enabled) await _schedule(item, currency);
    }
  }

  Future<void> _schedule(RecurringTransaction item, String currency) async {
    final due = DateTime(item.nextRun.year, item.nextRun.month, item.nextRun.day, 9);
    final reminder = due.subtract(Duration(days: item.reminderDays));
    final now = DateTime.now();
    final when = reminder.isAfter(now) ? reminder : due.isAfter(now) ? due : null;
    if (when == null) return;
    final direction = item.type == TransactionType.income ? 'ဝင်ငွေ' : 'ပေးချေရန်';
    await _plugin.zonedSchedule(
      _id(item.id),
      'DGzone Money Reminder',
      '${item.title} • $direction • ${item.amount} $currency',
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'recurring_reminders',
          'Recurring reminders',
          channelDescription: 'Upcoming income and payment reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'recurring',
    );
  }

  int _id(int recurringId) => 100000 + recurringId;
}
