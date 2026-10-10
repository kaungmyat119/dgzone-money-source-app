import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';

enum InformationPage { help, privacy }

class HelpPrivacyScreen extends StatelessWidget {
  const HelpPrivacyScreen({super.key, required this.page});
  final InformationPage page;

  @override
  Widget build(BuildContext context) {
    final help = page == InformationPage.help;
    final sections = help ? _helpSections : _privacySections;
    return Scaffold(
      appBar: AppBar(title: LText(help ? 'အကူအညီ' : 'ကိုယ်ရေးအချက်အလက် မူဝါဒ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(help ? Icons.help_outline : Icons.shield_outlined, size: 54, color: AppColors.emerald),
          const SizedBox(height: 12),
          for (final section in sections)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  LText(section.$1, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  LText(section.$2, style: const TextStyle(height: 1.55)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  static const _helpSections = [
    ('၁။ Account စတင်ထည့်ရန်', 'Settings > အကောင့်များ မှာ ငွေသား၊ ဘဏ်၊ Mobile Wallet သို့မဟုတ် Credit Card ကို အရင်ထည့်ပါ။'),
    ('၂။ ငွေစာရင်းထည့်ရန်', 'အောက်ခြေ + ခလုတ်ကိုနှိပ်ပြီး ဝင်ငွေ၊ အသုံးစရိတ် သို့မဟုတ် ငွေလွှဲကို ရွေးပါ။ Amount နေရာမှာ Calculator ကိုသုံးနိုင်ပါတယ်။'),
    ('၃။ Template အသုံးပြုရန်', 'မကြာခဏထည့်ရတဲ့စာရင်းကို Template အဖြစ်သိမ်းပြီး နောက်တစ်ကြိမ် တစ်ချက်နှိပ်၍ ပြန်ဖြည့်နိုင်ပါတယ်။'),
    ('၄။ Backup ပြုလုပ်ရန်', 'Settings မှ Cloud Backup သို့မဟုတ် File Backup ကိုအသုံးပြုပါ။ အရေးကြီးဒေတာမပြင်မီ Backup တစ်ခုထားသင့်ပါတယ်။'),
    ('၅။ Security', 'PIN Lock ကိုဖွင့်ပြီး PIN သတ်မှတ်ပါ။ ဖုန်းကထောက်ပံ့ပါက Fingerprint / Face Lock ကိုပါ ဖွင့်နိုင်ပါတယ်။'),
  ];

  static const _privacySections = [
    ('ဒေတာသိမ်းဆည်းမှု', 'Cloud Sync မဖွင့်ထားပါက ငွေစာရင်းနှင့် Setting များကို ဤဖုန်းအတွင်း Local database တွင်သာ သိမ်းပါသည်။'),
    ('Cloud Backup', 'Cloud Sync ဖွင့်ထားပါက သင်ရွေးချယ်ထားသော Google account ၏ App သီးသန့် Google Drive နေရာသို့ Backup ဖိုင်ပို့ပါသည်။'),
    ('ပုံနှင့် Location', 'ပြေစာပုံနှင့် Location ကို သင်ကိုယ်တိုင်ထည့်သည့်အခါမှသာ ငွေစာရင်းနှင့်တွဲ၍ သိမ်းပါသည်။'),
    ('PIN နှင့် Biometric', 'PIN ကို plain text အဖြစ်မသိမ်းဘဲ encrypted storage ထဲတွင် salted hash အဖြစ်သိမ်းပါသည်။ Biometric စစ်ဆေးမှုကို ဖုန်း၏ လုံခြုံရေးစနစ်က ကိုင်တွယ်ပါသည်။'),
    ('ဒေတာဖျက်ခြင်း', 'Settings > ဒေတာအားလုံး ပြန်လည်ရှင်းမည် ကိုအသုံးပြုပါက Local ငွေစာရင်းနှင့် လုံခြုံရေး setting များကို ဖျက်ပစ်ပါသည်။'),
  ];
}
