import 'dart:io';

import 'package:flutter/material.dart';

import '../data/local_database.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../services/cloud_backup_service.dart';
import '../services/security_service.dart';
import '../services/notification_service.dart';
import 'accounts_screen.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'data_transfer_screen.dart';
import 'recurring_screen.dart';
import 'templates_screen.dart';
import 'help_privacy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.database,
    required this.language,
    required this.darkMode,
    required this.onLanguageChanged,
    required this.onDarkModeChanged,
    required this.onCurrencyChanged,
    required this.onDateFormatChanged,
    required this.onDataChanged,
    required this.onSecurityChanged,
  });

  final LocalDatabase database;
  final AppLanguage language;
  final bool darkMode;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<bool> onDarkModeChanged;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<String> onDateFormatChanged;
  final VoidCallback onDataChanged;
  final VoidCallback onSecurityChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppLanguage selectedLanguage;
  late bool selectedDarkMode;
  bool cloudSync = false;
  bool autoBackup = false;
  bool pinLock = false;
  bool biometricLock = false;
  bool notifications = true;
  bool notificationBusy = false;
  String currency = 'MMK';
  String dateFormat = 'dd/MM/yyyy';
  int autoLockMinutes = 1;
  bool cloudBusy = false;
  String cloudEmail = '';
  String lastCloudBackup = '';

  @override
  void initState() {
    super.initState();
    selectedLanguage = widget.language;
    selectedDarkMode = widget.darkMode;
    _load();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      selectedLanguage = widget.language;
    }
    if (oldWidget.darkMode != widget.darkMode) {
      selectedDarkMode = widget.darkMode;
    }
  }

  Future<void> _load() async {
    final values = await Future.wait([
      widget.database.readSetting('cloud_sync'),
      widget.database.readSetting('auto_backup'),
      widget.database.readSetting('pin_lock'),
      widget.database.readSetting('biometric_lock'),
      widget.database.readSetting('notifications'),
      widget.database.readSetting('currency'),
      widget.database.readSetting('date_format'),
      widget.database.readSetting('auto_lock_minutes'),
      widget.database.readSetting('cloud_account_email'),
      widget.database.readSetting('last_cloud_backup_at'),
    ]);
    if (!mounted) return;
    setState(() {
      cloudSync = values[0] == 'true';
      autoBackup = values[1] == 'true';
      pinLock = values[2] == 'true';
      biometricLock = values[3] == 'true';
      notifications = values[4] == 'true';
      currency = values[5] ?? 'MMK';
      dateFormat = values[6] ?? 'dd/MM/yyyy';
      autoLockMinutes = int.tryParse(values[7] ?? '') ?? 1;
      cloudEmail = values[8] ?? '';
      lastCloudBackup = values[9] ?? '';
    });
  }

  Future<void> _toggleCloudSync(bool value) async {
    if (!value) {
      setState(() {
        cloudSync = false;
        autoBackup = false;
      });
      await _saveBool('cloud_sync', false);
      await _saveBool('auto_backup', false);
      return;
    }
    setState(() => cloudBusy = true);
    try {
      final account = await CloudBackupService.instance.connect();
      if (account == null) return;
      await CloudBackupService.instance.upload(widget.database);
      await _saveBool('cloud_sync', true);
      await widget.database.saveSetting('cloud_account_email', account.email);
      if (!mounted) return;
      setState(() {
        cloudSync = true;
        cloudEmail = account.email;
        lastCloudBackup = DateTime.now().toUtc().toIso8601String();
      });
      _message('Cloud ချိတ်ဆက်ပြီး ပထမ Backup သိမ်းပြီးပါပြီ', 'Cloud connected and the first backup was saved');
    } catch (error, stack) {
      debugPrint('DGZ cloud: connect failed: $error\n$stack');
      if (mounted) _cloudError('Cloud ချိတ်ဆက်၍မရပါ', 'Could not connect to cloud', error);
    } finally {
      if (mounted) setState(() => cloudBusy = false);
    }
  }

  Future<void> _toggleAutoBackup(bool value) async {
    if (value && !cloudSync) {
      await _toggleCloudSync(true);
      if (!cloudSync) return;
    }
    await _saveBool('auto_backup', value);
    if (mounted) setState(() => autoBackup = value);
    if (value) {
      await CloudBackupService.instance.runAutomaticBackupIfDue(widget.database);
    }
  }

  Future<void> _backupToCloud() async {
    setState(() => cloudBusy = true);
    try {
      final result = await CloudBackupService.instance.upload(widget.database);
      if (!mounted) return;
      setState(() {
        cloudEmail = CloudBackupService.instance.account?.email ?? cloudEmail;
        lastCloudBackup = result.createdAt?.toIso8601String() ?? DateTime.now().toUtc().toIso8601String();
      });
      _message('Google Drive သို့ Backup သိမ်းပြီးပါပြီ', 'Backup saved to Google Drive');
    } catch (error, stack) {
      debugPrint('DGZ cloud: backup failed: $error\n$stack');
      if (mounted) _cloudError('Cloud Backup မအောင်မြင်ပါ', 'Cloud backup failed', error);
    } finally {
      if (mounted) setState(() => cloudBusy = false);
    }
  }

  Future<void> _restoreFromCloud() async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const LText('Cloud Backup ပြန်သွင်းရန်'),
      content: const LText('လက်ရှိဒေတာကို နောက်ဆုံး Cloud Backup ဖြင့် အစားထိုးမည်။ လက်ရှိဒေတာကို Safety Backup အရင်သိမ်းပေးပါမည်။'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const LText('မလုပ်တော့ပါ')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const LText('ဆက်လုပ်မည်')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => cloudBusy = true);
    try {
      await CloudBackupService.instance.restoreLatest(widget.database);
      widget.onDataChanged();
      if (mounted) _message('Cloud Backup ပြန်သွင်းပြီးပါပြီ', 'Cloud backup restored');
    } catch (error, stack) {
      debugPrint('DGZ cloud: restore failed: $error\n$stack');
      if (mounted) _cloudError('Cloud Backup ပြန်သွင်း၍မရပါ', 'Unable to restore cloud backup', error);
    } finally {
      if (mounted) setState(() => cloudBusy = false);
    }
  }

  void _cloudError(String myanmar, String english, Object error) {
    final text = error.toString();
    final String reason;
    if (text.contains('sign_in_failed') && text.contains(': 10:')) {
      // DEVELOPER_ERROR: no Android OAuth client matches this package + SHA-1.
      reason = 'Google sign-in is not configured for this app build (error 10)';
    } else if (text.contains('sign_in_failed') && text.contains('12500')) {
      reason = 'Google OAuth consent screen is not configured (error 12500)';
    } else if (text.contains('network_error') || error is SocketException) {
      reason = 'No internet connection';
    } else {
      reason = text.length > 160 ? '${text.substring(0, 160)}…' : text;
    }
    _message('$myanmar\n$reason', '$english\n$reason');
  }

  Future<void> _saveBool(String key, bool value) =>
      widget.database.saveSetting(key, value.toString());

  void _message(String myanmar, String english) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(selectedLanguage == AppLanguage.english ? english : myanmar)),
    );
  }

  Future<void> _chooseCurrency() async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const LText('ငွေကြေး'),
        children: [
          for (final item in ['MMK', 'USD', 'THB', 'SGD'])
            RadioListTile<String>(
              value: item,
              groupValue: currency,
              title: LText(item),
              onChanged: (value) => Navigator.pop(dialogContext, value),
            ),
        ],
      ),
    );
    if (result == null) return;
    setState(() => currency = result);
    widget.onCurrencyChanged(result);
  }

  Future<void> _chooseDateFormat() async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const LText('ရက်စွဲပုံစံ'),
        children: [
          for (final item in ['dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd'])
            RadioListTile<String>(
              value: item,
              groupValue: dateFormat,
              title: LText(item),
              onChanged: (value) => Navigator.pop(dialogContext, value),
            ),
        ],
      ),
    );
    if (result == null) return;
    setState(() => dateFormat = result);
    widget.onDateFormatChanged(result);
  }

  Future<void> _chooseAutoLock() async {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const LText('အလိုအလျောက် Lock'),
        children: [
          for (final item in [1, 5, 15, 30])
            RadioListTile<int>(
              value: item,
              groupValue: autoLockMinutes,
              title: LText('$item min'),
              onChanged: (value) => Navigator.pop(dialogContext, value),
            ),
        ],
      ),
    );
    if (result == null) return;
    setState(() => autoLockMinutes = result);
    await widget.database.saveSetting('auto_lock_minutes', '$result');
    widget.onSecurityChanged();
  }

  Future<bool> _changePin() async {
    if (await SecurityService.instance.hasPin) {
      final current = TextEditingController();
      final verified = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const LText('လက်ရှိ PIN အတည်ပြုပါ'),
        content: TextField(controller: current, keyboardType: TextInputType.number,
          obscureText: true, maxLength: 6,
          decoration: InputDecoration(labelText: context.tr('လက်ရှိ PIN'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const LText('မလုပ်တော့ပါ')),
          FilledButton(onPressed: () async {
            final okay = await SecurityService.instance.verifyPin(current.text);
            if (dialogContext.mounted) Navigator.pop(dialogContext, okay);
          }, child: const LText('အတည်ပြုမည်')),
        ],
      ));
      current.dispose();
      if (verified != true) {
        if (mounted) _message('လက်ရှိ PIN မမှန်ပါ', 'Current PIN is incorrect');
        return false;
      }
    }
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    String error = '';
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
          title: const LText('PIN ပြောင်းရန်'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: controller, keyboardType: TextInputType.number,
              obscureText: true, maxLength: 6,
              decoration: InputDecoration(labelText: context.tr('4–6 digit PIN'))),
            TextField(controller: confirmController, keyboardType: TextInputType.number,
              obscureText: true, maxLength: 6,
              decoration: InputDecoration(labelText: context.tr('PIN ထပ်မံအတည်ပြုပါ'))),
            if (error.isNotEmpty) LText(error, style: const TextStyle(color: AppColors.coral)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const LText('မလုပ်တော့ပါ')),
            FilledButton(onPressed: () {
              final value = controller.text;
              if (!RegExp(r'^\d{4,6}$').hasMatch(value)) {
                setDialogState(() => error = 'PIN ကို ဂဏန်း ၄ လုံးမှ ၆ လုံးထည့်ပါ');
              } else if (value != confirmController.text) {
                setDialogState(() => error = 'PIN နှစ်ခု မတူပါ');
              } else {
                Navigator.pop(dialogContext, value);
              }
            }, child: const LText('သိမ်းမည်')),
          ],
        )),
    );
    controller.dispose();
    confirmController.dispose();
    if (pin == null) return false;
    await SecurityService.instance.setPin(pin);
    await widget.database.saveSetting('app_pin', '');
    if (mounted) _message('PIN ပြောင်းပြီးပါပြီ', 'PIN changed');
    widget.onSecurityChanged();
    return true;
  }

  Future<void> _togglePinLock(bool value) async {
    if (value) {
      final hasPin = await SecurityService.instance.hasPin;
      if (!hasPin && !await _changePin()) return;
    } else {
      await widget.database.saveSetting('biometric_lock', 'false');
      if (mounted) setState(() => biometricLock = false);
    }
    await _saveBool('pin_lock', value);
    if (mounted) setState(() => pinLock = value);
    widget.onSecurityChanged();
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      if (!pinLock) {
        _message('Fingerprint မဖွင့်မီ PIN Lock ကိုအရင်ဖွင့်ပါ', 'Enable PIN lock before biometrics');
        return;
      }
      if (!await SecurityService.instance.canUseBiometrics()) {
        _message('ဤဖုန်းတွင် Fingerprint / Face Lock မရနိုင်ပါ', 'Biometrics are unavailable on this device');
        return;
      }
      if (!await SecurityService.instance.authenticateBiometric()) return;
    }
    await _saveBool('biometric_lock', value);
    if (mounted) setState(() => biometricLock = value);
    widget.onSecurityChanged();
  }

  Future<void> _toggleNotifications(bool value) async {
    if (notificationBusy) return;
    final previous = notifications;
    setState(() {
      notificationBusy = true;
      notifications = value;
    });
    try {
      if (value && !await NotificationService.instance.requestPermission()) {
        if (mounted) {
          setState(() => notifications = false);
          _message(
            'ဖုန်း Settings မှ DGzone Money အတွက် Notification ခွင့်ပြုပါ',
            'Allow notifications for DGzone Money in phone Settings',
          );
        }
        await _saveBool('notifications', false);
        return;
      }
      // Persist the choice before rebuilding reminders. Scheduling is
      // best-effort and must not incorrectly roll this switch back.
      await _saveBool('notifications', value);
      await NotificationService.instance.syncRecurring(widget.database);
      if (mounted) {
        _message(
          value ? 'အကြောင်းကြားချက် ဖွင့်ပြီးပါပြီ' : 'အကြောင်းကြားချက် ပိတ်ပြီးပါပြီ',
          value ? 'Notifications enabled' : 'Notifications disabled',
        );
      }
    } catch (error, stack) {
      debugPrint('DGZ notifications: toggle failed: $error\n$stack');
      if (mounted) {
        setState(() => notifications = previous);
        _message(
          'အကြောင်းကြားချက် ပြောင်း၍မရပါ။ ထပ်စမ်းပါ',
          'Could not change notifications. Please try again',
        );
      }
    } finally {
      if (mounted) setState(() => notificationBusy = false);
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      await NotificationService.instance.scheduleTest();
      if (mounted) {
        _message(
          'စက္ကန့် ၁၀ အတွင်း စမ်းသပ် အကြောင်းကြားချက် ရောက်ပါမည်',
          'A test notification will arrive in about 10 seconds',
        );
      }
    } catch (error, stack) {
      debugPrint('DGZ notifications: test failed: $error\n$stack');
      if (mounted) {
        _message(
          'စမ်းသပ် အကြောင်းကြားချက် မအောင်မြင်ပါ: $error',
          'Test notification failed: $error',
        );
      }
    }
  }

  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('ဒေတာများ ပြန်လည်ရှင်းရန်'),
        content: LText(context.tr(
          'ငွေစာရင်း၊ အကောင့်၊ ဘတ်ဂျက်၊ ပုံမှန်စာရင်းနှင့် Template အားလုံး အပြီးတိုင်ပျက်သွားပါမည်။',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const LText('မလုပ်တော့ပါ')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const LText('ဆက်လုပ်မည်')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final finalConfirmation = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('နောက်ဆုံးအတည်ပြုချက်'),
        content: const LText('ဒေတာအားလုံးကို ဖျက်ရန် သေချာပါသလား?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const LText('မဖျက်ပါ')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const LText('အားလုံးဖျက်မည်')),
        ],
      ),
    );
    if (finalConfirmation != true) return;
    await widget.database.resetAllData();
    await SecurityService.instance.clearPin();
    await widget.database.saveSetting('pin_lock', 'false');
    await widget.database.saveSetting('biometric_lock', 'false');
    await widget.database.saveSetting('notifications', 'false');
    await NotificationService.instance.syncRecurring(widget.database);
    if (mounted) setState(() {
      pinLock = false;
      biometricLock = false;
      notifications = false;
    });
    widget.onSecurityChanged();
    widget.onDataChanged();
    if (mounted) _message('ဒေတာအားလုံး ရှင်းပြီးပါပြီ', 'All data has been reset');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const LText('ဆက်တင်')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.mintSoft,
                child: Icon(
                  Icons.person,
                  size: 32,
                  color: AppColors.emeraldDark,
                ),
              ),
              title: const LText(
                'DGzone အသုံးပြုသူ',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const LText('ဖုန်းအတွင်း Local account'),
              trailing: LText(cloudEmail.isEmpty ? 'Cloud မချိတ်ရသေး' : cloudEmail,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          _sectionTitle('ဘာသာစကား'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<AppLanguage>(
                segments: const [
                  ButtonSegment(value: AppLanguage.myanmar, label: LText('မြန်မာ')),
                  ButtonSegment(value: AppLanguage.english, label: LText('English')),
                ],
                selected: {selectedLanguage},
                onSelectionChanged: (values) {
                  final language = values.first;
                  setState(() => selectedLanguage = language);
                  widget.onLanguageChanged(language);
                  _message('ဘာသာစကား ပြောင်းပြီးပါပြီ', 'Language changed');
                },
              ),
            ),
          ),
          _sectionTitle('အထွေထွေ နှင့် Cloud'),
          _card([
            _switch(Icons.cloud_outlined, 'Cloud Sync', cloudSync, cloudBusy ? null : _toggleCloudSync),
            _switch(Icons.sync, 'အလိုအလျောက် Backup', autoBackup, cloudBusy ? null : _toggleAutoBackup),
            _action(Icons.cloud_upload_outlined, 'Cloud Backup ယခုပြုလုပ်ရန်', cloudBusy ? null : _backupToCloud,
              value: lastCloudBackup.isEmpty ? null : _shortDate(lastCloudBackup)),
            _action(Icons.cloud_download_outlined, 'Cloud Backup ပြန်သွင်းရန်', cloudBusy ? null : _restoreFromCloud),
            _action(Icons.save_alt, 'ဖိုင် Backup / Restore', () => _openDataTransfer(2)),
            _action(Icons.file_upload_outlined, 'CSV / Excel တင်သွင်းရန်', () => _openDataTransfer(0)),
            _action(Icons.download_outlined, 'ဒေတာထုတ်ယူရန်', () => _openDataTransfer(1)),
          ]),
          _sectionTitle('လုံခြုံရေး'),
          _card([
            _switch(Icons.lock_outline, 'PIN Lock', pinLock, _togglePinLock),
            _switch(Icons.fingerprint, 'Fingerprint / Face Lock', biometricLock, _toggleBiometric),
            _action(Icons.password, 'PIN ပြောင်းရန်', _changePin),
            _action(Icons.timer_outlined, 'အလိုအလျောက် Lock', _chooseAutoLock, value: '$autoLockMinutes min'),
          ]),
          _sectionTitle('ရုပ်ပုံနှင့် အသုံးပြုမှု'),
          _card([
            _switch(Icons.dark_mode_outlined, 'Dark Mode', selectedDarkMode, (value) {
              setState(() => selectedDarkMode = value);
              widget.onDarkModeChanged(value);
            }),
            _action(Icons.payments_outlined, 'ငွေကြေး', _chooseCurrency, value: currency),
            _action(Icons.calendar_month_outlined, 'ရက်စွဲပုံစံ', _chooseDateFormat, value: dateFormat),
            _switch(
              Icons.notifications_outlined,
              'အကြောင်းကြားချက်',
              notifications,
              notificationBusy ? null : _toggleNotifications,
            ),
            if (notifications)
              _action(Icons.notification_add_outlined, 'စမ်းသပ် အကြောင်းကြားချက် ပို့ရန်', _sendTestNotification),
          ]),
          _sectionTitle('စာရင်းစီမံခန့်ခွဲမှု'),
          _card([
            _action(Icons.category_outlined, 'အမျိုးအစားများ', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoriesScreen(database: widget.database)))),
            _action(Icons.account_balance_wallet_outlined, 'အကောင့်များ', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountsScreen(database: widget.database, onDataChanged: widget.onDataChanged)))),
            _action(Icons.donut_large, 'ဘတ်ဂျက်', () => Navigator.push(context, MaterialPageRoute(builder: (_) => BudgetsScreen(database: widget.database, onDataChanged: widget.onDataChanged)))),
            _action(Icons.notifications_active_outlined, 'ပုံမှန်စာရင်း', () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecurringScreen(database: widget.database, onDataChanged: widget.onDataChanged)))),
            _action(Icons.bookmarks_outlined, 'Template Management', () => Navigator.push(context, MaterialPageRoute(builder: (_) => TemplatesScreen(database: widget.database, initialType: TransactionType.expense)))),
          ]),
          _sectionTitle('အကူအညီနှင့် အခြား'),
          _card([
            _action(Icons.help_outline, 'အကူအညီ', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpPrivacyScreen(page: InformationPage.help)))),
            _action(Icons.shield_outlined, 'ကိုယ်ရေးအချက်အလက် မူဝါဒ', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpPrivacyScreen(page: InformationPage.privacy)))),
            _action(Icons.info_outline, 'App အကြောင်း', () => showAboutDialog(context: context, applicationName: 'DGzone Money', applicationVersion: '0.10.13')),
          ]),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
              title: LText('ဒေတာအားလုံး ပြန်လည်ရှင်းမည်', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _resetData,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 18, 8, 7),
    child: LText(title, style: Theme.of(context).textTheme.titleLarge),
  );

  void _openDataTransfer(int tab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DataTransferScreen(
          database: widget.database,
          initialTab: tab,
          onDataChanged: widget.onDataChanged,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => Card(
    child: Column(children: [
      for (var i = 0; i < children.length; i++) ...[
        children[i],
        if (i != children.length - 1) const Divider(height: 1),
      ],
    ]),
  );

  Widget _icon(IconData icon) => CircleAvatar(
    backgroundColor: AppColors.mintSoft,
    child: Icon(icon, color: AppColors.emeraldDark),
  );

  String _shortDate(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _switch(IconData icon, String title, bool value, ValueChanged<bool>? onChanged) =>
      SwitchListTile(secondary: _icon(icon), title: LText(title), value: value, onChanged: onChanged);

  Widget _action(IconData icon, String title, VoidCallback? onTap, {String? value}) => ListTile(
    leading: _icon(icon), title: LText(title),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      if (value != null)
        LText(
          value,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      const Icon(Icons.chevron_right),
    ]),
    onTap: onTap,
  );
}
