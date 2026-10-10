import 'dart:async';

import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'src/app.dart';
import 'src/data/local_database.dart';
import 'src/services/cloud_backup_service.dart';
import 'src/services/notification_service.dart';
import 'src/strings.dart';

const backgroundMaintenanceTask = 'dgzone_background_maintenance';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final database = LocalDatabase.instance;
      await database.open().timeout(const Duration(seconds: 20));
      await database.postDueRecurring().timeout(const Duration(seconds: 20));
      await NotificationService.instance
          .initialize()
          .timeout(const Duration(seconds: 15));
      await NotificationService.instance
          .syncRecurring(database)
          .timeout(const Duration(seconds: 30));
      await CloudBackupService.instance
          .runAutomaticBackupIfDue(database)
          .timeout(const Duration(minutes: 2));
      return true;
    } catch (_) {
      return false;
    }
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _StartupApp());
}

class _StartupApp extends StatefulWidget {
  const _StartupApp();

  @override
  State<_StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<_StartupApp> {
  LocalDatabase? _database;
  AppLanguage _language = AppLanguage.myanmar;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (mounted) {
      setState(() {
        _error = null;
        _database = null;
      });
    }

    try {
      final database = LocalDatabase.instance;
      await database.open().timeout(const Duration(seconds: 20));
      final savedLanguage = await database
          .readSetting('language')
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      final language = AppLanguage.values.firstWhere(
        (value) => value.name == savedLanguage,
        orElse: () => AppLanguage.myanmar,
      );
      if (!mounted) return;
      setState(() {
        _database = database;
        _language = language;
      });
      unawaited(_initializeBackgroundServices(database));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _initializeBackgroundServices(LocalDatabase database) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    try {
      await Workmanager()
          .initialize(callbackDispatcher)
          .timeout(const Duration(seconds: 15));
      await Workmanager()
          .registerPeriodicTask(
            'dgzone-maintenance',
            backgroundMaintenanceTask,
            frequency: const Duration(hours: 6),
            existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Optional background work must never block app startup.
    }
    try {
      await NotificationService.instance
          .initialize()
          .timeout(const Duration(seconds: 15));
      await database.postDueRecurring().timeout(const Duration(seconds: 20));
      await NotificationService.instance
          .syncRecurring(database)
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      // The app remains usable even when notification setup is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final database = _database;
    if (database != null) {
      return DgzoneMoneyApp(
        database: database,
        initialLanguage: _language,
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: _error == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image(
                          image: AssetImage(
                            'assets/images/dgzone_money_logo.png',
                          ),
                          width: 112,
                          height: 112,
                        ),
                        SizedBox(height: 24),
                        CircularProgressIndicator(),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 56,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'App data ကို ဖွင့်၍ မရသေးပါ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ဒေတာမဖျက်ဘဲ ထပ်မံကြိုးစားနိုင်ပါသည်။',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('ထပ်မံကြိုးစားမည်'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
