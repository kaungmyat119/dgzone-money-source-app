import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import '../strings.dart';

class AmountCalculatorScreen extends StatefulWidget {
  const AmountCalculatorScreen({
    super.key,
    this.initialAmount = 0,
    this.allowZero = false,
  });

  final int initialAmount;
  final bool allowZero;

  @override
  State<AmountCalculatorScreen> createState() => _AmountCalculatorScreenState();
}

class _AmountCalculatorScreenState extends State<AmountCalculatorScreen> {
  late String display;
  int? storedValue;
  String? operation;
  bool replaceDisplay = false;

  @override
  void initState() {
    super.initState();
    display = widget.initialAmount > 0 ? widget.initialAmount.toString() : '0';
  }

  int get value => int.tryParse(display) ?? 0;

  void inputDigit(String digit) {
    setState(() {
      if (replaceDisplay || display == '0') {
        display = digit;
        replaceDisplay = false;
      } else if (display.length < 12) {
        display += digit;
      }
    });
  }

  void quickAmount(int amount) {
    setState(() {
      display = amount.toString();
      replaceDisplay = true;
    });
  }

  void chooseOperation(String nextOperation) {
    if (operation != null && !replaceDisplay) calculate();
    setState(() {
      storedValue = value;
      operation = nextOperation;
      replaceDisplay = true;
    });
  }

  void calculate() {
    final first = storedValue;
    final op = operation;
    if (first == null || op == null) return;
    final second = value;
    final result = switch (op) {
      '+' => first + second,
      '−' => first - second,
      '×' => first * second,
      '÷' => second == 0 ? first : first ~/ second,
      _ => second,
    };
    setState(() {
      display = result.clamp(0, 999999999999).toString();
      storedValue = null;
      operation = null;
      replaceDisplay = true;
    });
  }

  void clear({bool all = false}) {
    setState(() {
      display = '0';
      if (all) {
        storedValue = null;
        operation = null;
      }
      replaceDisplay = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat('#,##0').format(value);
    return Scaffold(
      appBar: AppBar(
        title: const LText('Calculator'),
        actions: [
          IconButton(
            tooltip: context.tr('အသုံးပြုမည်'),
            onPressed: value > 0 || widget.allowZero
                ? () => Navigator.pop(context, value)
                : null,
            icon: const Icon(Icons.check, size: 32),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            color: Colors.white,
            child: LText(
              '$formatted ${AppPreferencesScope.of(context).currency}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              childAspectRatio: 1.15,
              children: [
                for (final amount in [10, 25, 50])
                  _key('$amount', () => quickAmount(amount), light: true),
                _key('AC', () => clear(all: true), light: true),
                for (final amount in [100, 150, 200])
                  _key('$amount', () => quickAmount(amount), light: true),
                _key('C', clear, light: true),
                _key('7', () => inputDigit('7')),
                _key('8', () => inputDigit('8')),
                _key('9', () => inputDigit('9')),
                _key('÷', () => chooseOperation('÷'), operator: true),
                _key('4', () => inputDigit('4')),
                _key('5', () => inputDigit('5')),
                _key('6', () => inputDigit('6')),
                _key('×', () => chooseOperation('×'), operator: true),
                _key('1', () => inputDigit('1')),
                _key('2', () => inputDigit('2')),
                _key('3', () => inputDigit('3')),
                _key('−', () => chooseOperation('−'), operator: true),
                _key('0', () => inputDigit('0')),
                _key('00', () {
                  inputDigit('0');
                  inputDigit('0');
                }),
                _key('=', calculate),
                _key('+', () => chooseOperation('+'), operator: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _key(
    String label,
    VoidCallback onTap, {
    bool light = false,
    bool operator = false,
  }) {
    final selected = operator && operation == label;
    return Material(
      color: light
          ? const Color(0xFFF0F1F1)
          : selected
              ? AppColors.emerald
              : operator
                  ? const Color(0xFF626262)
                  : const Color(0xFF414141),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: LText(
            label,
            style: TextStyle(
              color: light ? Colors.black87 : Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
