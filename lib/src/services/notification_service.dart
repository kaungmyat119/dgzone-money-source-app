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
    try {
      await initialize();
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final requested = await androidPlugin.requestNotificationsPermission();
        if (requested == false) return false;
        // Older Android versions can return null because runtime permission is
        // not required. The OS status is authoritative when it is available.
        return await androidPlugin.areNotificationsEnabled() ?? requested ?? true;
      }

      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        return await iosPlugin.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return true;
    } catch (_) {
      // Treat a platform-channel failure as unavailable permission. This lets
      // Settings show the useful permission message instead of a generic error.
      return false;
    }
  }

  Future<void> syncRecurring(LocalDatabase database) async {
    await initialize();
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // A stale notification must not prevent the setting from being changed.
    }
    final enabled = await database.readSetting('notifications') == 'true';
    if (!enabled) {
      return;
    }
    final items = await database.recurringTransactions();
    final currency = await database.readSetting('currency') ?? 'MMK';
    for (final item in items) {
      if (!item.enabled) continue;
      try {
        await _schedule(item, currency);
      } catch (_) {
        // Keep scheduling the remaining reminders. One device-rejected
        // reminder must not disable notifications globally.
      }
    }
  }

  Future<void> _schedule(RecurringTransaction item, String currency) async {
    final nextRun = item.nextRun;
    if (nextRun == null) return;
    final due = DateTime(nextRun.year, nextRun.month, nextRun.day, 9);
    final reminder = due.subtract(Duration(days: item.reminderDays));
    final now = DateTime.now();
    final when = reminder.isAfter(now) ? reminder : due.isAfter(now) ? due : null;
    if (when == null) return;
    final direction = switch (item.kind) {
      'receivable' => 'အကြွေးရရန်',
      'payable' => 'အကြွေးပေးရန်',
      _ => item.type == TransactionType.income ? 'ဝင်ငွေ' : 'ပေးချေရန်',
    };
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
