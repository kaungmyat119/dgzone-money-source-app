import 'dart:async';

import 'package:flutter/material.dart';

import 'data/local_database.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/app_lock_screen.dart';
import 'strings.dart';
import 'theme.dart';
import 'services/cloud_backup_service.dart';
import 'services/security_service.dart';
import 'services/notification_service.dart';

class DgzoneMoneyApp extends StatefulWidget {
  const DgzoneMoneyApp({
    super.key,
    required this.database,
    required this.initialLanguage,
  });
  final LocalDatabase database;
  final AppLanguage initialLanguage;

  @override
  State<DgzoneMoneyApp> createState() => _DgzoneMoneyAppState();
}

class _DgzoneMoneyAppState extends State<DgzoneMoneyApp>
    with WidgetsBindingObserver {
  late AppLanguage language;
  bool darkMode = false;
  String currency = 'MMK';
  String dateFormat = 'dd/MM/yyyy';
  int revision = 0;
  bool? onboardingComplete;
  bool securityReady = false;
  bool lockEnabled = false;
  bool biometricEnabled = false;
  bool locked = false;
  int autoLockMinutes = 1;
  DateTime? backgroundedAt;
  bool privacyCovered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    language = widget.initialLanguage;
    _loadAppearance();
    _loadOnboarding();
    _loadSecurity(initial: true);
    unawaited(CloudBackupService.instance.runAutomaticBackupIfDue(widget.database));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadSecurity({bool initial = false}) async {
    try {
      final legacyPin = await widget.database.readSetting('app_pin');
      if ((legacyPin ?? '').isNotEmpty &&
          !await SecurityService.instance.hasPin
              .timeout(const Duration(seconds: 5), onTimeout: () => false) &&
          RegExp(r'^\d{4,6}$').hasMatch(legacyPin!)) {
        await SecurityService.instance
            .setPin(legacyPin)
            .timeout(const Duration(seconds: 5));
        await widget.database.saveSetting('app_pin', '');
      }
      final values = await Future.wait([
        widget.database.readSetting('pin_lock'),
        widget.database.readSetting('biometric_lock'),
        widget.database.readSetting('auto_lock_minutes'),
        SecurityService.instance.hasPin
            .timeout(const Duration(seconds: 5), onTimeout: () => false),
      ]).timeout(const Duration(seconds: 10));
      final enabled = values[0] == 'true' && values[3] == true;
      if (!mounted) return;
      setState(() {
        lockEnabled = enabled;
        biometricEnabled = values[1] == 'true';
        autoLockMinutes = int.tryParse(values[2]?.toString() ?? '') ?? 1;
        if (initial && enabled) locked = true;
        if (!enabled) locked = false;
      });
    } catch (_) {
      // Never leave the whole app behind an endless loading overlay.
    } finally {
      if (mounted) setState(() => securityReady = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` is also emitted for temporary system UI (biometric prompts,
    // permissions and some route transitions). Covering the app for that state
    // can leave the privacy screen visible even though the app never left.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      backgroundedAt ??= DateTime.now();
      if (mounted && !privacyCovered) {
        setState(() => privacyCovered = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      final leftAt = backgroundedAt;
      backgroundedAt = null;
      unawaited(_handleResume(leftAt));
    }
  }

  Future<void> _handleResume(DateTime? leftAt) async {
    if (!mounted) return;
    final shouldLock = lockEnabled &&
        leftAt != null &&
        DateTime.now().difference(leftAt).inMinutes >= autoLockMinutes;

    // Restore the visible UI immediately. Optional maintenance must never keep
    // the user trapped behind the privacy cover.
    setState(() {
      if (shouldLock) locked = true;
      privacyCovered = false;
    });

    try {
      await _loadSecurity().timeout(const Duration(seconds: 12));
    } catch (_) {
      // Existing in-memory security settings remain usable.
    }
    try {
      final posted = await widget.database
          .postDueRecurring()
          .timeout(const Duration(seconds: 20));
      await NotificationService.instance
          .syncRecurring(widget.database)
          .timeout(const Duration(seconds: 30));
      if (posted > 0 && mounted) {
        setState(() => revision++);
      }
    } catch (error, stack) {
      debugPrint('DGZ resume maintenance failed: $error\n$stack');
      // Recurring/notification maintenance is optional during resume.
    }
    unawaited(
      CloudBackupService.instance.runAutomaticBackupIfDue(widget.database),
    );
  }

  void _unlockApp() {
    if (!mounted) return;
    backgroundedAt = null;
    setState(() {
      locked = false;
      privacyCovered = false;
    });
  }

  Widget _privacyScreen(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/dgzone_money_logo.png', width: 96, height: 96),
            const SizedBox(height: 16),
            const Text(
              'DGzone Money',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _securityLoadingScreen(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _loadOnboarding() async {
    final saved = await widget.database.readSetting('onboarding_completed');
    final hasAccounts = (await widget.database.accounts()).isNotEmpty;
    final complete = saved == 'true' || hasAccounts;
    if (saved == null && hasAccounts) {
      await widget.database.saveSetting('onboarding_completed', 'true');
    }
    if (mounted) setState(() => onboardingComplete = complete);
  }

  Future<void> _completeOnboarding() async {
    await widget.database.saveSetting('onboarding_completed', 'true');
    if (mounted) setState(() {
      onboardingComplete = true;
      revision++;
    });
  }

  Future<void> _loadAppearance() async {
    final values = await Future.wait([
      widget.database.readSetting('dark_mode'),
      widget.database.readSetting('currency'),
      widget.database.readSetting('date_format'),
    ]);
    if (mounted) setState(() {
      darkMode = values[0] == 'true';
      currency = values[1] ?? 'MMK';
      dateFormat = values[2] ?? 'dd/MM/yyyy';
    });
  }

  void changeLanguage(AppLanguage value) {
    setState(() => language = value);
    widget.database.saveSetting('language', value.name);
  }

  void changeDarkMode(bool value) {
    setState(() => darkMode = value);
    widget.database.saveSetting('dark_mode', value.toString());
  }

  void changeCurrency(String value) {
    setState(() => currency = value);
    widget.database.saveSetting('currency', value);
  }

  void changeDateFormat(String value) {
    setState(() => dateFormat = value);
    widget.database.saveSetting('date_format', value);
  }

  @override
  Widget build(BuildContext context) {
    return AppLanguageScope(
      language: language,
      child: AppPreferencesScope(
        currency: currency,
        dateFormat: dateFormat,
        child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DGzone Money',
        theme: buildTheme(),
        darkTheme: buildTheme(brightness: Brightness.dark),
        themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => Stack(
          children: [
            if (child != null) child,
            if (!securityReady)
              Positioned.fill(child: _securityLoadingScreen(context))
            else if (privacyCovered)
              Positioned.fill(child: _privacyScreen(context))
            else if (lockEnabled && locked)
              Positioned.fill(
                child: AppLockScreen(
                  allowBiometric: biometricEnabled,
                  onUnlocked: _unlockApp,
                ),
              ),
          ],
        ),
        home: onboardingComplete == null
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : onboardingComplete == false
            ? OnboardingScreen(
                database: widget.database,
                onComplete: _completeOnboarding,
              )
            : DashboardScreen(
          key: ValueKey(revision),
          database: widget.database,
          language: language,
          darkMode: darkMode,
          onLanguageChanged: changeLanguage,
          onDarkModeChanged: changeDarkMode,
          onCurrencyChanged: changeCurrency,
          onDateFormatChanged: changeDateFormat,
          onSecurityChanged: _loadSecurity,
          onDataChanged: () {
            setState(() => revision++);
            unawaited(CloudBackupService.instance.syncIfEnabled(widget.database));
            unawaited(NotificationService.instance.syncRecurring(widget.database));
          },
        ),
        ),
      ),
    );
  }
}
