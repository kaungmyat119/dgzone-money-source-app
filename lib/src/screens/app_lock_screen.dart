import 'dart:async';

import 'package:flutter/material.dart';

import '../services/security_service.dart';
import '../strings.dart';
import '../theme.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.allowBiometric, required this.onUnlocked});
  final bool allowBiometric;
  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String pin = '';
  String message = '';
  int failures = 0;
  DateTime? blockedUntil;
  Timer? timer;
  int expectedPinLength = 6;

  bool get blocked => blockedUntil?.isAfter(DateTime.now()) == true;

  @override
  void initState() {
    super.initState();
    SecurityService.instance.pinLength.then((value) {
      if (mounted && value != null) setState(() => expectedPinLength = value);
    });
    if (widget.allowBiometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _digit(String value) async {
    if (blocked || pin.length >= expectedPinLength) return;
    setState(() { pin += value; message = ''; });
    if (pin.length < expectedPinLength) return;
    if (await SecurityService.instance.verifyPin(pin)) {
      widget.onUnlocked();
    } else {
      _failed();
    }
  }

  void _failed() {
    failures++;
    if (failures >= 5) {
      blockedUntil = DateTime.now().add(const Duration(seconds: 30));
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (!blocked) timer?.cancel();
        setState(() {});
      });
    }
    setState(() {
      pin = '';
      message = failures >= 5 ? 'ကြိုးစားမှုများလွန်းပါသည်' : 'PIN မှားနေပါသည်';
    });
  }

  Future<void> _biometric() async {
    if (blocked || !widget.allowBiometric) return;
    if (await SecurityService.instance.authenticateBiometric()) {
      widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    final seconds = blocked
        ? blockedUntil!.difference(DateTime.now()).inSeconds + 1
        : 0;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(children: [
          const Spacer(),
          Image.asset('assets/images/dgzone_money_logo.png', height: 84),
          const SizedBox(height: 12),
          const LText('DGzone Money', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.emeraldDark)),
          const SizedBox(height: 22),
          LText(blocked ? '$seconds စက္ကန့်ကြာမှ ပြန်ကြိုးစားပါ' : 'App ဖွင့်ရန် PIN ထည့်ပါ', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(expectedPinLength, (index) => Container(
            width: 14, height: 14, margin: const EdgeInsets.all(7),
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: index < pin.length ? AppColors.emerald : AppColors.mintSoft,
              border: Border.all(color: AppColors.emerald)),
          ))),
          SizedBox(height: 24, child: LText(message, style: const TextStyle(color: AppColors.coral))),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 18,
              childAspectRatio: 1.35,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final digit in ['1','2','3','4','5','6','7','8','9']) _key(digit, () => _digit(digit)),
                _key('', widget.allowBiometric ? _biometric : null, icon: widget.allowBiometric ? Icons.fingerprint : null),
                _key('0', () => _digit('0')),
                _key('', pin.isEmpty ? null : () => setState(() => pin = pin.substring(0, pin.length - 1)), icon: Icons.backspace_outlined),
              ],
            ),
          ),
          const Spacer(),
        ]),
      ),
    );
  }

  Widget _key(String text, VoidCallback? onTap, {IconData? icon}) => InkWell(
    borderRadius: BorderRadius.circular(40), onTap: blocked ? null : onTap,
    child: Container(
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.mintSoft),
      alignment: Alignment.center,
      child: icon == null
          ? LText(text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))
          : Icon(icon, size: 30, color: AppColors.emeraldDark),
    ),
  );
}
