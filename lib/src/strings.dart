import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum AppLanguage { myanmar, english }

class AppPreferencesScope extends InheritedWidget {
  const AppPreferencesScope({
    super.key,
    required this.currency,
    required this.dateFormat,
    required super.child,
  });

  final String currency;
  final String dateFormat;

  static AppPreferencesScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppPreferencesScope>() ??
      const AppPreferencesScope(
        currency: 'MMK',
        dateFormat: 'dd/MM/yyyy',
        child: SizedBox.shrink(),
      );

  @override
  bool updateShouldNotify(AppPreferencesScope oldWidget) =>
      currency != oldWidget.currency || dateFormat != oldWidget.dateFormat;
}

class AppLanguageScope extends InheritedWidget {
  const AppLanguageScope({super.key, required this.language, required super.child});
  final AppLanguage language;

  static AppLanguage of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLanguageScope>()?.language ??
      AppLanguage.myanmar;

  @override
  bool updateShouldNotify(AppLanguageScope oldWidget) =>
      language != oldWidget.language;
}

class AppStrings {
  const AppStrings(this.language);
  final AppLanguage language;

  static AppStrings of(BuildContext context) => AppStrings(AppLanguageScope.of(context));

  static const _en = <String, String>{
    'လက်ရှိလက်ကျန်': 'Current balance', 'ဝင်ငွေ': 'Income',
    'အသုံးစရိတ်': 'Expense', 'ငွေလွှဲ': 'Transfer', 'ဘတ်ဂျက်': 'Budget',
    'ယခုလ အသုံးစရိတ်': 'Spending this month',
    'နောက်ဆုံးစာရင်းများ': 'Recent transactions', 'အားလုံးကြည့်ရန်': 'See all',
    'ပင်မ': 'Home', 'စာရင်း': 'Transactions', 'အစီရင်ခံစာ': 'Reports',
    'ဆက်တင်': 'Settings', 'အကောင့်များ': 'Accounts',
    'အကောင့်အသစ်': 'New account', 'အကောင့်ပြင်ရန်': 'Edit account',
    'အကောင့်အမည်': 'Account name', 'အကောင့်အမျိုးအစား': 'Account type',
    'ငွေသား': 'Cash', 'ဘဏ်အကောင့်': 'Bank account', 'စုဆောင်းငွေ': 'Savings',
    'စုစုပေါင်းလက်ကျန်': 'Total balance', 'ကျွန်ုပ်၏အကောင့်များ': 'My accounts',
    'ပိုင်ဆိုင်မှုစုစုပေါင်း': 'Total assets', 'ပေးရန်ငွေ': 'Liabilities',
    'လက်ကျန်ညှိ': 'Adjust balance',
    'လက်ကျန်ညှိရန်': 'Adjust balance', 'လက်ကျန်တိုးမည်': 'Increase balance',
    'လက်ကျန်လျှော့မည်': 'Decrease balance', 'လက်ကျန်ညှိမည်': 'Apply adjustment',
    'အကောင့်အသစ်ထည့်ရန်': 'Add a new account',
    'အကောင့်နံပါတ် (နောက်ဆုံး ၄ လုံး)': 'Account number (last 4 digits)',
    'ချေးငွေ/ကတ် Limit': 'Loan / card limit',
    'စုဆောင်းရန် ရည်မှန်းချက်': 'Savings goal', 'ချေးငွေ': 'Loan',
    'အကောင့်အချင်းချင်း ငွေလွှဲရန်': 'Transfer between accounts',
    'မူလလက်ကျန်': 'Opening balance', 'သိမ်းမည်': 'Save', 'ပြင်မည်': 'Edit',
    'ဖျက်မည်': 'Delete', 'မဖျက်ပါ': 'Cancel', 'အမည်ထည့်ပါ': 'Enter a name',
    'မှန်ကန်သောငွေပမာဏထည့်ပါ': 'Enter a valid amount',
    'စာရင်းအသစ်ထည့်ရန်': 'Add transaction', 'စာရင်းပြင်ရန်': 'Edit transaction',
    'ငွေပမာဏ': 'Amount', 'ကျပ်': 'MMK', 'အကြောင်းအရာ': 'Title',
    'အကြောင်းအရာထည့်ပါ': 'Enter a title', 'အမျိုးအစား': 'Category',
    'အကောင့်': 'Account', 'လက်ခံမည့်အကောင့်': 'Destination account',
    'လက်ခံမည့်အကောင့်ရွေးပါ': 'Select a destination account', 'ရက်စွဲ': 'Date',
    'မှတ်ချက် (မဖြည့်လည်းရသည်)': 'Note (optional)',
    'Location (မဖြည့်လည်းရသည်)': 'Location (optional)',
    'လိပ်စာရေးပါ သို့မဟုတ် လက်ရှိနေရာယူပါ': 'Enter an address or use current location',
    'လက်ရှိ Location ယူမည်': 'Use current location', 'ပြေစာပုံ ထည့်မည်': 'Add receipt photo',
    'Camera သို့မဟုတ် Gallery': 'Camera or Gallery', 'ကင်မရာဖြင့် ရိုက်မည်': 'Take a photo',
    'Gallery မှ ရွေးမည်': 'Choose from gallery', 'ပုံပြောင်းမည်': 'Change photo',
    'ဖယ်ရှားမည်': 'Remove', 'ပြေစာပုံ ဖွင့်၍မရပါ': 'Unable to open receipt photo',
    'အသုံးပြုမည်': 'Use amount', 'Template အသုံးပြုမည်': 'Use template',
    'သိမ်းထားသောစာရင်းကို ရွေးချယ်ရန်': 'Choose a saved template',
    'Template သိမ်းရန်': 'Save as template', 'Template အဖြစ်သိမ်းရန်': 'Save as template',
    'Template အမည်': 'Template name', 'Template အသစ်': 'New template',
    'Template ပြင်ရန်': 'Edit template', 'Template ရှာရန်': 'Search templates',
    'Template မရှိသေးပါ': 'No templates yet', 'Template အသစ်ထည့်မည်': 'Add template',
    'Template သိမ်းမည်': 'Save template', 'အသစ်ထည့်မည်': 'Add new',
    'ငွေစာရင်းများ': 'Transactions', 'စာရင်းရှာရန်': 'Search transactions',
    'အားလုံး': 'All', 'စာရင်းမရှိသေးပါ': 'No transactions yet',
    'စာရင်းဖျက်မည်လား?': 'Delete transaction?',
    'ပုံမှန်စာရင်း': 'Recurring transactions',
    'ပုံမှန်စာရင်းနှင့် Reminder': 'Recurring transactions & reminders',
    'အကြွေးရရန်': 'Receivable', 'အကြွေးပေးရန်': 'Payable',
    'ယခုလ အလိုအလျောက်စာရင်း': 'This month’s automatic transactions',
    'ဝင်ငွေစုစုပေါင်း': 'Total recurring income',
    'ထွက်ငွေစုစုပေါင်း': 'Total recurring expenses',
    'လာမည့်ငွေပေးချေမှုများ': 'Upcoming payments',
    'ဤအမျိုးအစားတွင် စာရင်းမရှိသေးပါ': 'No items in this section',
    'အကြွေးစာရင်း အနှစ်ချုပ်': 'Recurring summary',
    'ရရန်': 'Receivable', 'ပေးရန်': 'Payable',
    'ရက်ရောက်စာရင်းများ ယခုသွင်းမည်': 'Post due transactions now',
    'လစာ၊ အိမ်လခ၊ ဖုန်းဘေလ်နှင့် လစဉ်ပေးချေမှုများကို အလိုအလျောက်မှတ်တမ်းတင်နိုင်သည်':
        'Automatically record salary, rent, phone bills and monthly payments',
    'ပုံမှန်စာရင်းအသစ်': 'New recurring transaction',
    'ပိတ်ထားသည်': 'Disabled', 'ယနေ့': 'Today',
    'ပုံမှန်စာရင်းနှင့် သတိပေးချက်': 'Recurring & reminders',
    'ပုံမှန်စာရင်း မရှိသေးပါ': 'No recurring transactions yet',
    'အပတ်စဉ်': 'Weekly', 'လစဉ်': 'Monthly', 'နှစ်စဉ်': 'Yearly',
    'ထပ်လုပ်မည့်ကာလ': 'Repeat interval',
    'နောက်တစ်ကြိမ် စာရင်းသွင်းမည့်ရက်': 'Next transaction date',
    'သတိပေးမည့်ရက်': 'Reminder', 'အသုံးပြုထားမည်': 'Enabled', 'မကြာမီ': 'Due soon',
    'ဘတ်ဂျက်အသစ်': 'New budget', 'ဘတ်ဂျက်ပြင်ရန်': 'Edit budget',
    'ဘတ်ဂျက်အမည်': 'Budget name', 'သတ်မှတ်ငွေ': 'Budget limit',
    'Report ထုတ်ရန်': 'Export report', 'အသုံးစရိတ်အမျိုးအစားများ': 'Expense categories',
    'ဘာသာစကား': 'Language', 'မြန်မာ': 'Myanmar',
    'ဘာသာစကား ပြောင်းပြီးပါပြီ': 'Language changed',
    'ဒေတာသိမ်းဆည်းမှု': 'Data storage',
    'အင်တာနက်မရှိလည်း အသုံးပြုနိုင်သည်': 'Works without internet',
    'ဒေတာအားလုံး ပြန်လည်ရှင်းမည်': 'Reset all data',
    'ဒေတာများ ပြန်လည်ရှင်းရန်': 'Reset data', 'နောက်ဆုံးအတည်ပြုချက်': 'Final confirmation',
    'မလုပ်တော့ပါ': 'Cancel', 'ဆက်လုပ်မည်': 'Continue', 'အားလုံးဖျက်မည်': 'Delete everything',
    'စားသောက်စရိတ်': 'Food & dining', 'သယ်ယူပို့ဆောင်ရေး': 'Transportation',
    'အိမ်အသုံးစရိတ်': 'Household', 'ဖုန်းနှင့်အင်တာနက်': 'Phone & internet',
    'ကျန်းမာရေး': 'Health', 'အခြား': 'Other', 'လစာ': 'Salary',
    'စီးပွားရေး': 'Business', 'အပိုဝင်ငွေ': 'Other income',
    'အထွေထွေ နှင့် Cloud': 'General & cloud', 'Cloud Sync': 'Cloud sync',
    'အလိုအလျောက် Backup': 'Automatic backup', 'Backup ပြုလုပ်ရန်': 'Create backup',
    'Backup ပြန်သွင်းရန်': 'Restore backup', 'CSV / Excel တင်သွင်းရန်': 'Import CSV / Excel',
    'ဒေတာထုတ်ယူရန်': 'Export data', 'လုံခြုံရေး': 'Security', 'PIN Lock': 'PIN lock',
    'Fingerprint / Face Lock': 'Fingerprint / Face lock', 'PIN ပြောင်းရန်': 'Change PIN',
    'အလိုအလျောက် Lock': 'Auto lock', 'ရုပ်ပုံနှင့် အသုံးပြုမှု': 'Appearance & preferences',
    'PIN ထပ်မံအတည်ပြုပါ': 'Confirm PIN',
    'PIN ကို ဂဏန်း ၄ လုံးမှ ၆ လုံးထည့်ပါ': 'Enter a 4–6 digit PIN',
    'PIN နှစ်ခု မတူပါ': 'PINs do not match',
    'Fingerprint မဖွင့်မီ PIN Lock ကိုအရင်ဖွင့်ပါ':
        'Enable PIN lock before biometrics',
    'ဤဖုန်းတွင် Fingerprint / Face Lock မရနိုင်ပါ':
        'Biometrics are unavailable on this device',
    'လက်ရှိ PIN အတည်ပြုပါ': 'Verify current PIN',
    'လက်ရှိ PIN': 'Current PIN', 'အတည်ပြုမည်': 'Verify',
    'လက်ရှိ PIN မမှန်ပါ': 'Current PIN is incorrect',
    'App ဖွင့်ရန် PIN ထည့်ပါ': 'Enter PIN to unlock',
    'ကြိုးစားမှုများလွန်းပါသည်': 'Too many attempts',
    'PIN မှားနေပါသည်': 'Incorrect PIN',
    'Notification ခွင့်ပြုချက်မရပါ': 'Notification permission was not granted',
    'ငွေကြေး': 'Currency', 'ရက်စွဲပုံစံ': 'Date format', 'အကြောင်းကြားချက်': 'Notifications',
    'စမ်းသပ် အကြောင်းကြားချက် ပို့ရန်': 'Send test notification',
    'အကူအညီနှင့် အခြား': 'Help & more', 'အကူအညီ': 'Help',
    'ကိုယ်ရေးအချက်အလက် မူဝါဒ': 'Privacy policy', 'App အကြောင်း': 'About app',
    '၁။ Account စတင်ထည့်ရန်': '1. Create an account',
    'Settings > အကောင့်များ မှာ ငွေသား၊ ဘဏ်၊ Mobile Wallet သို့မဟုတ် Credit Card ကို အရင်ထည့်ပါ။':
        'Go to Settings > Accounts and add cash, a bank account, mobile wallet or credit card first.',
    '၂။ ငွေစာရင်းထည့်ရန်': '2. Add a transaction',
    'အောက်ခြေ + ခလုတ်ကိုနှိပ်ပြီး ဝင်ငွေ၊ အသုံးစရိတ် သို့မဟုတ် ငွေလွှဲကို ရွေးပါ။ Amount နေရာမှာ Calculator ကိုသုံးနိုင်ပါတယ်။':
        'Tap the + button and choose income, expense or transfer. You can use the calculator for the amount.',
    '၃။ Template အသုံးပြုရန်': '3. Use templates',
    'မကြာခဏထည့်ရတဲ့စာရင်းကို Template အဖြစ်သိမ်းပြီး နောက်တစ်ကြိမ် တစ်ချက်နှိပ်၍ ပြန်ဖြည့်နိုင်ပါတယ်။':
        'Save frequent transactions as templates and fill them again with one tap.',
    '၄။ Backup ပြုလုပ်ရန်': '4. Create a backup',
    'Settings မှ Cloud Backup သို့မဟုတ် File Backup ကိုအသုံးပြုပါ။ အရေးကြီးဒေတာမပြင်မီ Backup တစ်ခုထားသင့်ပါတယ်။':
        'Use Cloud Backup or File Backup in Settings. Keep a backup before making major data changes.',
    '၅။ Security': '5. Security',
    'PIN Lock ကိုဖွင့်ပြီး PIN သတ်မှတ်ပါ။ ဖုန်းကထောက်ပံ့ပါက Fingerprint / Face Lock ကိုပါ ဖွင့်နိုင်ပါတယ်။':
        'Enable PIN lock and set a PIN. You can also enable fingerprint or face unlock when supported.',
    'Cloud Sync မဖွင့်ထားပါက ငွေစာရင်းနှင့် Setting များကို ဤဖုန်းအတွင်း Local database တွင်သာ သိမ်းပါသည်။':
        'When Cloud Sync is off, transactions and settings remain only in the local database on this device.',
    'Cloud Backup': 'Cloud backup',
    'Cloud Sync ဖွင့်ထားပါက သင်ရွေးချယ်ထားသော Google account ၏ App သီးသန့် Google Drive နေရာသို့ Backup ဖိုင်ပို့ပါသည်။':
        'When Cloud Sync is enabled, backups are uploaded to the app-private Google Drive area of your selected account.',
    'ပုံနှင့် Location': 'Photos and location',
    'ပြေစာပုံနှင့် Location ကို သင်ကိုယ်တိုင်ထည့်သည့်အခါမှသာ ငွေစာရင်းနှင့်တွဲ၍ သိမ်းပါသည်။':
        'Receipt photos and locations are stored with a transaction only when you add them.',
    'PIN နှင့် Biometric': 'PIN and biometrics',
    'PIN ကို plain text အဖြစ်မသိမ်းဘဲ encrypted storage ထဲတွင် salted hash အဖြစ်သိမ်းပါသည်။ Biometric စစ်ဆေးမှုကို ဖုန်း၏ လုံခြုံရေးစနစ်က ကိုင်တွယ်ပါသည်။':
        'The PIN is stored as a salted hash in encrypted storage. Biometric verification is handled by the device security system.',
    'ဒေတာဖျက်ခြင်း': 'Deleting data',
    'Settings > ဒေတာအားလုံး ပြန်လည်ရှင်းမည် ကိုအသုံးပြုပါက Local ငွေစာရင်းနှင့် လုံခြုံရေး setting များကို ဖျက်ပစ်ပါသည်။':
        'Settings > Reset all data deletes local transactions and security settings.',
    'DGzone Money မှ ကြိုဆိုပါတယ်': 'Welcome to DGzone Money',
    'Sample ငွေစာရင်းမပါဘဲ သန့်ရှင်းတဲ့ ဒေတာနဲ့ စတင်ပါမယ်။ သင့်ရဲ့ တကယ့် Account နဲ့ ငွေစာရင်းတွေကိုပဲ ထည့်သွင်းနိုင်ပါတယ်။':
        'Start with clean data and no sample transactions. Add only your real accounts and transactions.',
    'Account အရင်ဖန်တီးပါ': 'Create an account first',
    'ငွေသား၊ ဘဏ်၊ Mobile Wallet သို့မဟုတ် Credit Card':
        'Cash, bank, mobile wallet or credit card',
    'ဝင်ငွေ/အသုံးစရိတ် ထည့်ပါ': 'Add income and expenses',
    'Calculator နဲ့ Template ကိုသုံးပြီး မြန်မြန်ထည့်နိုင်ပါတယ်':
        'Use the calculator and templates for faster entry',
    'Report နဲ့ Backup ကြည့်ပါ': 'Review reports and backups',
    'သုံးစွဲမှုကို စစ်ပြီး ဒေတာကို လုံခြုံစွာသိမ်းပါ':
        'Review spending and keep your data safe',
    'ရှိပြီးသား Backup ပြန်သွင်းမည်': 'Restore an existing backup',
    'ပထမ Account ဖန်တီးပါ': 'Create your first account',
    'ပထမ Account အဆင်သင့်ဖြစ်ပါပြီ': 'Your first account is ready',
    'Account Management ဖွင့်မည်': 'Open account management',
    'Account များကို စစ်ဆေးမည်': 'Review accounts',
    'Account အနည်းဆုံးတစ်ခုထည့်ပြီးမှ ရှေ့ဆက်နိုင်ပါမယ်။':
        'Add at least one account before continuing.',
    'အသုံးပြုရန် အဆင်သင့်ဖြစ်ပါပြီ': 'You are ready to begin',
    'Template သုံးရန်': 'Use templates', 'Backup ဖွင့်ရန်': 'Enable backup',
    'စတင်အသုံးပြုမည်': 'Start using the app', 'ရှေ့ဆက်မည်': 'Continue',
    'စာရင်းမထည့်မီ Account အနည်းဆုံးတစ်ခု ဖန်တီးပါ':
        'Create at least one account before adding a transaction',
    'မကြာမီရရှိမည်': 'Coming soon', 'စာရင်းစီမံခန့်ခွဲမှု': 'Management',
    'DGzone အသုံးပြုသူ': 'DGzone User',
    'ဖုန်းအတွင်း Local account': 'Local account on this device',
    'Cloud မချိတ်ရသေး': 'Cloud not connected', 'Dark Mode': 'Dark mode',
    'Cloud Backup ယခုပြုလုပ်ရန်': 'Back up to cloud now',
    'Cloud Backup ပြန်သွင်းရန်': 'Restore cloud backup',
    'ဖိုင် Backup / Restore': 'File backup / restore',
    'လက်ရှိဒေတာကို နောက်ဆုံး Cloud Backup ဖြင့် အစားထိုးမည်။ လက်ရှိဒေတာကို Safety Backup အရင်သိမ်းပေးပါမည်။':
        'Current data will be replaced with the latest cloud backup. A safety backup will be created first.',
    'စာရင်းနှင့် ပြေစာပုံများပါဝင်သော DGzone Backup':
        'DGzone backup including transactions and receipt photos',
    'Cloud Sync မဖွင့်ထားပါက ဒေတာကို ဖုန်းအတွင်းသာ သိမ်းပါသည်။ ဖွင့်ထားပါက App သီးသန့် Google Drive နေရာတွင် Backup သိမ်းပါသည်။':
        'Data stays on this device unless Cloud Sync is enabled. Cloud backups are stored in the app-private Google Drive area.',
    'Template Management': 'Template management', 'ပြေစာပုံ': 'Receipt photo',
    'စာရင်းသိမ်းရန်': 'Save transaction',
    'ဥပမာ - ဆီဖိုး၊ နေ့လယ်စာ': 'Example — fuel, lunch',
    'ရက်ရောက်စာရင်းသွင်းရန်': 'Post due transactions',
    '4–6 digit PIN': '4–6 digit PIN',
    'ဒေတာ တင်သွင်း/ထုတ်ယူရန်': 'Import / Export data',
    'ဖိုင်ရွေး': 'Choose file', 'Column တွဲ': 'Map columns',
    'စစ်ဆေး': 'Review', 'ပြီးမြောက်': 'Complete',
    'CSV / Excel ဖိုင်ရွေးပါ': 'Choose a CSV / Excel file',
    'ဖိုင်ရွေးရန်': 'Choose file', 'Column များတွဲပေးရန်': 'Map columns',
    'ဖိုင်ထဲက Column ကို App Field နှင့် တွဲပါ':
        'Match file columns to app fields',
    'Column ရွေးပါ': 'Choose column', 'စာရင်းအမျိုးအစား': 'Transaction type',
    'ကဏ္ဍ': 'Category', 'ထည့်သွင်းမည့်အကောင့်': 'Import to account',
    'တူညီသောစာရင်းများ မထည့်ရန်': 'Skip duplicate transactions',
    'ယခုလ ငွေစာရင်းများကို လိုချင်သောဖိုင်ပုံစံဖြင့်ထုတ်ယူပါ':
        'Export this month’s transactions in your preferred format',
    'Backup ဖိုင်အသစ်ထုတ်ရန်': 'Create a new backup',
    'DGzone Money JSON Backup': 'DGzone Money JSON backup',
    'လက်ရှိဒေတာကို Backup ဖြင့် အစားထိုးမည်':
        'Replace current data with the backup',
    'Backup ပြန်သွင်းပြီးပါပြီ': 'Backup restored',
    'Backup ဖိုင်မမှန်ပါ': 'Invalid backup file',
    'ဖိုင်ကို ဖတ်၍မရပါ': 'Unable to read the file',
    'ဖိုင်နှင့် အကောင့်ရွေးပါ': 'Choose a file and account',
    'အမျိုးအစားများ': 'Categories',
    'အမျိုးအစားရှာရန်': 'Search categories',
    'အစီအစဉ်အလိုက် အမျိုးအစားများ': 'Ordered categories',
    'အမျိုးအစား မရှိသေးပါ': 'No categories yet',
    'အမျိုးအစားအသစ်': 'New category',
    'အမျိုးအစားပြင်ရန်': 'Edit category',
    'အမျိုးအစားအမည်': 'Category name', 'အရောင်ရွေးပါ': 'Choose a color',
    'Icon ရွေးပါ': 'Choose an icon',
    'နေ့စဉ်': 'Daily', 'သွားလာ': 'Transport', 'အိမ်': 'Home',
    'ငွေကြေး/ဘဏ်': 'Finance / banking', 'ကျန်းမာ/ပညာ': 'Health / education',
    'ဖျော်ဖြေ': 'Entertainment', 'လုပ်ငန်း': 'Business',
    'အမျိုးအစား ဖျက်မည်လား?': 'Delete category?',
    'အနည်းဆုံး အမျိုးအစားတစ်ခု ချန်ထားရပါမည်':
        'At least one category must remain',
    'စာရင်းစစ်ထုတ်ရန်': 'Filter transactions',
    'လ': 'Month', '၃ လ': '3 months', '၆ လ': '6 months', 'နှစ်': 'Year',
    'စုဆောင်းနှုန်း': 'Savings rate',
    'ကာလအလိုက် ဝင်ငွေနှင့် အသုံးစရိတ်': 'Income and expenses by period',
    'အသုံးစရိတ်မရှိသေးပါ': 'No expenses yet',
    'ငွေကြေးသုံးသပ်ချက်': 'Financial insights',
    'PDF ထုတ်မည်': 'Export PDF', 'Excel ထုတ်မည်': 'Export Excel',
    'ဒေတာအားလုံးကို ဖျက်ရန် သေချာပါသလား?':
        'Are you sure you want to delete all data?',
    'ငွေစာရင်း၊ အကောင့်၊ ဘတ်ဂျက်၊ ပုံမှန်စာရင်းနှင့် Template အားလုံး အပြီးတိုင်ပျက်သွားပါမည်။':
        'All transactions, accounts, budgets, recurring items and templates will be permanently deleted.',
  };

  String translate(String text) {
    if (language == AppLanguage.myanmar) return text;
    final exact = _en[text];
    if (exact != null) return exact;
    if (text.endsWith(' ကျပ်')) return '${text.substring(0, text.length - 5)} MMK';
    const daysLeft = ' ရက်လို';
    const overdue = ' ရက်ကျော်';
    const itemCount = ' ခု';
    const nextPrefix = 'နောက်တစ်ခု — ';
    const retrySuffix = ' စက္ကန့်ကြာမှ ပြန်ကြိုးစားပါ';
    if (text.endsWith(retrySuffix)) {
      return 'Try again in ${text.substring(0, text.length - retrySuffix.length)} seconds';
    }
    if (text.endsWith(daysLeft)) {
      return '${text.substring(0, text.length - daysLeft.length)} days left';
    }
    if (text.endsWith(overdue)) {
      return '${text.substring(0, text.length - overdue.length)} days overdue';
    }
    if (text.endsWith(itemCount)) {
      return '${text.substring(0, text.length - itemCount.length)} items';
    }
    if (text.startsWith(nextPrefix)) {
      return 'Next — ${text.substring(nextPrefix.length)}';
    }
    return text;
  }

  String get(String key) {
    const my = {
      'balance': 'လက်ရှိလက်ကျန်', 'income': 'ဝင်ငွေ', 'expense': 'အသုံးစရိတ်',
      'transfer': 'ငွေလွှဲ', 'budget': 'ဘတ်ဂျက်', 'monthly': 'ယခုလ အသုံးစရိတ်',
      'recent': 'နောက်ဆုံးစာရင်းများ', 'seeAll': 'အားလုံးကြည့်ရန်',
      'home': 'ပင်မ', 'transactions': 'စာရင်း', 'reports': 'အစီရင်ခံစာ',
      'settings': 'ဆက်တင်',
    };
    return translate(my[key] ?? key);
  }
}

extension AppTranslationContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);
  String tr(String text) => strings.translate(text);
  String money(num value, {bool compact = false}) {
    final preferences = AppPreferencesScope.of(this);
    final formatted = compact
        ? NumberFormat.compact().format(value)
        : NumberFormat('#,##0').format(value);
    return '$formatted ${preferences.currency}';
  }

  String appDate(DateTime value, {String? fallbackPattern}) {
    final pattern = fallbackPattern ?? AppPreferencesScope.of(this).dateFormat;
    return DateFormat(pattern).format(value);
  }
}

class LText extends Text {
  const LText(super.data, {super.key, super.style, super.strutStyle, super.textAlign,
    super.textDirection, super.locale, super.softWrap, super.overflow,
    super.textScaler, super.maxLines, super.semanticsLabel, super.textWidthBasis,
    super.textHeightBehavior, super.selectionColor});

  @override
  Widget build(BuildContext context) => Text(
    AppStrings.of(context).translate(data ?? ''), style: style, strutStyle: strutStyle,
    textAlign: textAlign, textDirection: textDirection, locale: locale,
    softWrap: softWrap, overflow: overflow, textScaler: textScaler,
    maxLines: maxLines, semanticsLabel: semanticsLabel,
    textWidthBasis: textWidthBasis, textHeightBehavior: textHeightBehavior,
    selectionColor: selectionColor,
  );
}
