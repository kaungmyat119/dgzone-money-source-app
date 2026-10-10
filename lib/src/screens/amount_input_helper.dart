import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'amount_calculator_screen.dart';

Future<void> openAmountCalculator(
  BuildContext context,
  TextEditingController controller, {
  bool allowZero = false,
}) async {
  final current = int.tryParse(controller.text.replaceAll(',', '')) ?? 0;
  final amount = await Navigator.push<int>(
    context,
    MaterialPageRoute(
      builder: (_) => AmountCalculatorScreen(
        initialAmount: current,
        allowZero: allowZero,
      ),
    ),
  );
  if (amount != null) {
    controller.text = NumberFormat('#,##0').format(amount);
  }
}
