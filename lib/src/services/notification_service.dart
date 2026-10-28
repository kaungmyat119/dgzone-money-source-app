import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// The default `latest` dataset omits Asia/Yangon; `latest_all` includes it.
import 'package:timezone/data/latest_all.dart' as tz_data;
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
        // Always trust the current OS state first. Some Android/OEM versions
        // return false from a repeated permission request even though the user
        // has already enabled notifications in the phone's App settings.
        final enabledBefore = await androidPlugin.areNotificationsEnabled();
        if (enabledBefore == true) return true;

        final requested = await androidPlugin.requestNotificationsPermission();
        final enabledAfter = await androidPlugin.areNotificationsEnabled();
        return enabledAfter ?? requested ?? true;
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
    } catch (error) {
      // A stale notification must not prevent the setting from being changed.
      debugPrint('DGZ notifications: cancelAll failed: $error');
    }
    final enabled = await database.readSetting('notifications') == 'true';
    if (!enabled) {
      debugPrint('DGZ notifications: disabled in settings');
      return;
    }
    final items = await database.recurringTransactions();
    final currency = await database.readSetting('currency') ?? 'MMK';
    var scheduled = 0;
    for (final item in items) {
      if (!item.enabled) continue;
      try {
        if (await _schedule(item, currency)) scheduled++;
      } catch (error) {
        // Keep scheduling the remaining reminders. One device-rejected
        // reminder must not disable notifications globally.
        debugPrint('DGZ notifications: schedule #${item.id} failed: $error');
      }
    }
    debugPrint('DGZ notifications: scheduled $scheduled of ${items.length} recurring items');
  }

  Future<bool> _schedule(RecurringTransaction item, String currency) async {
    final nextRun = item.nextRun;
    if (nextRun == null) return false;
    final due = DateTime(nextRun.year, nextRun.month, nextRun.day, 9);
    final reminder = due.subtract(Duration(days: item.reminderDays));
    final now = DateTime.now();
    final when = reminder.isAfter(now) ? reminder : due.isAfter(now) ? due : null;
    if (when == null) {
      debugPrint('DGZ notifications: #${item.id} skipped, due $due already passed');
      return false;
    }
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
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'recurring',
    );
    debugPrint('DGZ notifications: #${item.id} scheduled for $when');
    return true;
  }

  /// Schedules a notification 10 seconds ahead through the same
  /// zonedSchedule path real reminders use.
  Future<void> scheduleTest() async {
    await initialize();
    final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
    await _plugin.zonedSchedule(
      _testId,
      'DGzone Money',
      'Notifications are working',
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'test',
    );
    debugPrint('DGZ notifications: test scheduled for $when');
  }

  static const _testId = 99999;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'recurring_reminders',
      'Recurring reminders',
      channelDescription: 'Upcoming income and payment reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  int _id(int recurringId) => 100000 + recurringId;
}
