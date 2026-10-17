import 'package:flutter/material.dart';

import '../data/local_database.dart';
import '../strings.dart';
import '../theme.dart';
import 'accounts_screen.dart';
import 'data_transfer_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.database,
    required this.onComplete,
  });

  final LocalDatabase database;
  final Future<void> Function() onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = PageController();
  int step = 0;
  bool hasAccount = false;

  @override
  void initState() {
    super.initState();
    _checkAccount();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _checkAccount() async {
    final value = (await widget.database.accounts()).isNotEmpty;
    if (mounted) setState(() => hasAccount = value);
  }

  Future<void> _openAccounts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountsScreen(
          database: widget.database,
          onDataChanged: _checkAccount,
        ),
      ),
    );
    await _checkAccount();
  }

  Future<void> _restoreBackup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DataTransferScreen(
          database: widget.database,
          initialTab: 2,
          onDataChanged: _checkAccount,
        ),
      ),
    );
    await _checkAccount();
  }

  void _next() {
    if (step >= 2) {
      widget.onComplete();
      return;
    }
    controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                child: Row(
                  children: [
                    Image.asset('assets/images/dgzone_money_logo.png', height: 46),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: LText(
                        'DGzone Money',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.emeraldDark,
                        ),
                      ),
                    ),
                    LText('${step + 1}/3', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: LinearProgressIndicator(
                  value: (step + 1) / 3,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.emerald,
                  backgroundColor: AppColors.mintSoft,
                ),
              ),
              Expanded(
                child: PageView(
                  controller: controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (value) => setState(() => step = value),
                  children: [
                    _WelcomeStep(onRestore: _restoreBackup),
                    _AccountStep(
                      hasAccount: hasAccount,
                      onCreateAccount: _openAccounts,
                    ),
                    const _ReadyStep(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                child: Row(
                  children: [
                    if (step > 0)
                      IconButton.filledTonal(
                        onPressed: () => controller.previousPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                        ),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    if (step > 0) const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: step == 1 && !hasAccount ? null : _next,
                        icon: Icon(step == 2 ? Icons.check : Icons.arrow_forward),
                        label: LText(step == 2 ? 'စတင်အသုံးပြုမည်' : 'ရှေ့ဆက်မည်'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onRestore});
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => _StepLayout(
        icon: Icons.auto_awesome,
        title: 'DGzone Money မှ ကြိုဆိုပါတယ်',
        description: 'Sample ငွေစာရင်းမပါဘဲ သန့်ရှင်းတဲ့ ဒေတာနဲ့ စတင်ပါမယ်။ သင့်ရဲ့ တကယ့် Account နဲ့ ငွေစာရင်းတွေကိုပဲ ထည့်သွင်းနိုင်ပါတယ်။',
        children: [
          const _GuideItem(number: '1', title: 'Account အရင်ဖန်တီးပါ', subtitle: 'ငွေသား၊ ဘဏ်၊ Mobile Wallet သို့မဟုတ် Credit Card'),
          const _GuideItem(number: '2', title: 'ဝင်ငွေ/အသုံးစရိတ် ထည့်ပါ', subtitle: 'Calculator နဲ့ Template ကိုသုံးပြီး မြန်မြန်ထည့်နိုင်ပါတယ်'),
          const _GuideItem(number: '3', title: 'Report နဲ့ Backup ကြည့်ပါ', subtitle: 'သုံးစွဲမှုကို စစ်ပြီး ဒေတာကို လုံခြုံစွာသိမ်းပါ'),
          TextButton.icon(onPressed: onRestore, icon: const Icon(Icons.restore), label: const LText('ရှိပြီးသား Backup ပြန်သွင်းမည်')),
        ],
      );
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({required this.hasAccount, required this.onCreateAccount});
  final bool hasAccount;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) => _StepLayout(
        icon: hasAccount ? Icons.check_circle : Icons.account_balance_wallet,
        iconColor: hasAccount ? AppColors.emerald : AppColors.emeraldDark,
        title: hasAccount ? 'ပထမ Account အဆင်သင့်ဖြစ်ပါပြီ' : 'ပထမ Account ဖန်တီးပါ',
        description: hasAccount
            ? 'Account ထည့်ပြီးပါပြီ။ အခု ဝင်ငွေ၊ အသုံးစရိတ်နဲ့ ငွေလွှဲစာရင်းတွေ စတင်ထည့်နိုင်ပါပြီ။'
            : 'လက်ရှိအသုံးပြုနေတဲ့ ငွေသား၊ ဘဏ် သို့မဟုတ် Mobile Wallet တစ်ခုကို အရင်ထည့်ပါ။ မူလလက်ကျန်ကို မှန်ကန်စွာထည့်ထားပါ။',
        children: [
          FilledButton.icon(
            onPressed: onCreateAccount,
            icon: Icon(hasAccount ? Icons.edit_outlined : Icons.add),
            label: LText(hasAccount ? 'Account များကို စစ်ဆေးမည်' : 'Account Management ဖွင့်မည်'),
          ),
          if (!hasAccount)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LText('Account အနည်းဆုံးတစ်ခုထည့်ပြီးမှ ရှေ့ဆက်နိုင်ပါမယ်။', textAlign: TextAlign.center),
            ),
        ],
      );
}

class _ReadyStep extends StatelessWidget {
  const _ReadyStep();

  @override
  Widget build(BuildContext context) => const _StepLayout(
        icon: Icons.rocket_launch,
        title: 'အသုံးပြုရန် အဆင်သင့်ဖြစ်ပါပြီ',
        description: 'အောက်က + ခလုတ်ကနေ ဝင်ငွေ၊ အသုံးစရိတ်နဲ့ ငွေလွှဲစာရင်း ထည့်နိုင်ပါတယ်။ မကြာခဏသုံးတာတွေကို Template အဖြစ်သိမ်းထားပါ။',
        children: [
          _GuideItem(number: '＋', title: 'စာရင်းအသစ်ထည့်ရန်', subtitle: 'Home အောက်ခြေ အစိမ်းရောင် + ခလုတ်ကိုနှိပ်ပါ'),
          _GuideItem(number: '★', title: 'Template သုံးရန်', subtitle: 'မကြာခဏထည့်ရတဲ့စာရင်းတွေကို တစ်ချက်နှိပ်ပြီးဖြည့်ပါ'),
          _GuideItem(number: '☁', title: 'Backup ဖွင့်ရန်', subtitle: 'Settings မှာ Cloud Sync သို့မဟုတ် File Backup လုပ်နိုင်ပါတယ်'),
        ],
      );
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({required this.icon, required this.title, required this.description, required this.children, this.iconColor = AppColors.emerald});
  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 12),
        child: Column(children: [
          CircleAvatar(radius: 52, backgroundColor: AppColors.mintSoft, child: Icon(icon, size: 56, color: iconColor)),
          const SizedBox(height: 22),
          LText(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          LText(description, textAlign: TextAlign.center, style: TextStyle(height: 1.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          ...children,
        ]),
      );
}

class _GuideItem extends StatelessWidget {
  const _GuideItem({required this.number, required this.title, required this.subtitle});
  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: AppColors.mintSoft, child: LText(number, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.emeraldDark))),
          title: LText(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: LText(subtitle),
        ),
      );
}
