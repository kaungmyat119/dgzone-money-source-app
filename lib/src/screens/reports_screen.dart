import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../data/local_database.dart';
import '../models.dart';
import '../services/export_service.dart';
import '../strings.dart';
import '../theme.dart';

enum ReportPeriod { month, threeMonths, sixMonths, year }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.database});
  final LocalDatabase database;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final exporter = const ExportService();
  ReportPeriod period = ReportPeriod.month;
  DateTime anchor = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<ReportSnapshot> future;
  bool exporting = false;

  @override
  void initState() { super.initState(); _reload(); }

  int get monthCount => switch (period) { ReportPeriod.month => 1, ReportPeriod.threeMonths => 3, ReportPeriod.sixMonths => 6, ReportPeriod.year => 12 };
  DateTime get start => DateTime(anchor.year, anchor.month - monthCount + 1);
  DateTime get end => DateTime(anchor.year, anchor.month + 1);

  void _reload() { future = widget.database.reportRange(start: start, end: end); }
  void _changePeriod(ReportPeriod value) { setState(() { period = value; _reload(); }); }
  void _move(int direction) { setState(() { anchor = DateTime(anchor.year, anchor.month + direction * monthCount); _reload(); }); }

  String rangeLabel(BuildContext context) {
    if (monthCount == 1) return context.appDate(anchor);
    return '${context.appDate(start)} – ${context.appDate(DateTime(end.year, end.month - 1))}';
  }

  Future<void> export(String type, ReportSnapshot report) async {
    setState(() => exporting = true);
    try {
      final preferences = AppPreferencesScope.of(context);
      final file = type == 'pdf'
          ? await exporter.pdfFile(report, currency: preferences.currency, dateFormat: preferences.dateFormat)
          : await exporter.excelFile(report, currency: preferences.currency, dateFormat: preferences.dateFormat);
      await exporter.share(file);
    } finally { if (mounted) setState(() => exporting = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const LText('အစီရင်ခံစာ'), actions: [IconButton(onPressed: exporting ? null : _shareCurrentReport, icon: const Icon(Icons.ios_share))]),
    body: FutureBuilder<ReportSnapshot>(future: future, builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final report = snapshot.data!;
      return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        _periodSelector(), const SizedBox(height: 10), _rangeSelector(), const SizedBox(height: 10),
        _summaryCard(report), const SizedBox(height: 12), _BarChartCard(report: report, period: period),
        const SizedBox(height: 12), _CategoryBreakdown(report: report), const SizedBox(height: 12),
        _Insights(report: report), const SizedBox(height: 12),
        if (exporting) const LinearProgressIndicator(),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: exporting ? null : () => export('pdf', report), icon: const Icon(Icons.picture_as_pdf_outlined), label: const LText('PDF ထုတ်မည်'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: exporting ? null : () => export('excel', report), icon: const Icon(Icons.table_chart_outlined), label: const LText('Excel ထုတ်မည်'))),
        ]),
      ]);
    }),
  );

  Future<void> _shareCurrentReport() async {
    final report = await future;
    if (!mounted) return;
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const LText('PDF ထုတ်မည်'), onTap: () => Navigator.pop(sheetContext, 'pdf')),
          ListTile(leading: const Icon(Icons.table_chart_outlined), title: const LText('Excel ထုတ်မည်'), onTap: () => Navigator.pop(sheetContext, 'excel')),
        ]),
      ),
    );
    if (type != null) await export(type, report);
  }

  Widget _periodSelector() => SegmentedButton<ReportPeriod>(
    segments: const [
      ButtonSegment(value: ReportPeriod.month, label: LText('လ')),
      ButtonSegment(value: ReportPeriod.threeMonths, label: LText('၃ လ')),
      ButtonSegment(value: ReportPeriod.sixMonths, label: LText('၆ လ')),
      ButtonSegment(value: ReportPeriod.year, label: LText('နှစ်')),
    ], selected: {period}, onSelectionChanged: (value) => _changePeriod(value.first),
  );

  Widget _rangeSelector() => Card(child: Row(children: [
    IconButton(onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left, size: 32)),
    Expanded(child: Center(child: LText(rangeLabel(context), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)))),
    IconButton(onPressed: () => _move(1), icon: const Icon(Icons.chevron_right, size: 32)),
  ]));

  Widget _summaryCard(ReportSnapshot report) {
    final previous = report.income == 0 ? 0 : ((report.saving / report.income) * 100).round();
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Row(children: [
        Expanded(child: _Summary(icon: Icons.arrow_upward, label: 'ဝင်ငွေ', value: report.income, color: AppColors.emerald)),
        const SizedBox(width: 8),
        Expanded(child: _Summary(icon: Icons.arrow_downward, label: 'အသုံးစရိတ်', value: report.expense, color: AppColors.coral)),
        const SizedBox(width: 8),
        Expanded(child: _Summary(icon: Icons.savings, label: 'စုဆောင်းငွေ', value: report.saving, color: AppColors.emeraldDark)),
      ]),
      const SizedBox(height: 10),
      Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.mintSoft, borderRadius: BorderRadius.circular(14)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.trending_up, color: AppColors.emerald), const SizedBox(width: 8), LText('စုဆောင်းနှုန်း ${previous >= 0 ? '+' : ''}$previous%', style: const TextStyle(fontWeight: FontWeight.w800)),
      ])),
    ])));
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon; final String label; final int value; final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: .15), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 5), Flexible(child: LText(label, maxLines: 1))]),
    const SizedBox(height: 7), LText(context.money(value, compact: true), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
  ]));
}

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({required this.report, required this.period});
  final ReportSnapshot report; final ReportPeriod period;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: LText(period == ReportPeriod.month ? 'ဝင်ငွေနှင့် အသုံးစရိတ်' : 'ကာလအလိုက် ဝင်ငွေနှင့် အသုံးစရိတ်', style: Theme.of(context).textTheme.titleMedium)), const Icon(Icons.circle, size: 10, color: AppColors.emerald), const SizedBox(width: 4), const LText('ဝင်ငွေ'), const SizedBox(width: 10), const Icon(Icons.circle, size: 10, color: AppColors.coral), const SizedBox(width: 4), const LText('အသုံးစရိတ်')]),
    const SizedBox(height: 12), SizedBox(height: 210, child: CustomPaint(painter: _BarPainter(report.weeklyIncome, report.weeklyExpense), child: const SizedBox.expand())),
  ])));
}

class _BarPainter extends CustomPainter {
  const _BarPainter(this.income, this.expense);
  final List<int> income; final List<int> expense;
  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = [...income, ...expense].fold<int>(1, (a, b) => math.max(a, b));
    final grid = Paint()..color = const Color(0xFFE1E7E4)..strokeWidth = 1;
    for (var line = 0; line <= 3; line++) { final y = 8 + (size.height - 32) * line / 3; canvas.drawLine(Offset(0, y), Offset(size.width, y), grid); }
    final group = size.width / 4; final paint = Paint();
    for (var i = 0; i < 4; i++) {
      final x = group * i + group / 2; final ih = income[i] / maxValue * (size.height - 45); final eh = expense[i] / maxValue * (size.height - 45);
      paint.color = AppColors.emerald; canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 21, size.height - 25 - ih, 18, ih), const Radius.circular(5)), paint);
      paint.color = AppColors.coral; canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 3, size.height - 25 - eh, 18, eh), const Radius.circular(5)), paint);
      final text = TextPainter(text: TextSpan(text: '${i + 1}', style: const TextStyle(color: Colors.black54, fontSize: 11)), textDirection: TextDirection.ltr)..layout(); text.paint(canvas, Offset(x - text.width / 2, size.height - 18));
    }
  }
  @override bool shouldRepaint(covariant _BarPainter oldDelegate) => true;
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.report});
  final ReportSnapshot report;
  static const colors = [AppColors.coral, AppColors.emerald, AppColors.amber, Colors.blue, Colors.blueGrey, Colors.purple];
  @override
  Widget build(BuildContext context) {
    final entries = report.categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LText('အသုံးစရိတ်ခွဲခြမ်းမှု', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 12),
      if (entries.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(30), child: LText('အသုံးစရိတ်မရှိသေးပါ')))
      else Row(children: [
        SizedBox(width: 145, height: 145, child: Stack(alignment: Alignment.center, children: [CustomPaint(size: const Size.square(145), painter: _DonutPainter(entries.map((e) => e.value).toList(), colors)), Column(mainAxisSize: MainAxisSize.min, children: [const LText('စုစုပေါင်း'), LText(context.money(report.expense, compact: true), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))])])),
        const SizedBox(width: 14), Expanded(child: Column(children: [for (var i = 0; i < math.min(5, entries.length); i++) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Icon(Icons.circle, color: colors[i % colors.length], size: 11), const SizedBox(width: 7), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [LText(entries[i].key, maxLines: 1, overflow: TextOverflow.ellipsis), LText(context.money(entries[i].value), style: const TextStyle(color: Colors.black54, fontSize: 12))])), LText('${(entries[i].value * 100 / math.max(1, report.expense)).round()}%')]))])),
      ]),
    ])));
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.values, this.colors); final List<int> values; final List<Color> colors;
  @override void paint(Canvas canvas, Size size) { final total = values.fold<int>(0, (a, b) => a + b); var start = -math.pi / 2; final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 26; for (var i = 0; i < values.length; i++) { final sweep = values[i] / math.max(1, total) * math.pi * 2; paint.color = colors[i % colors.length]; canvas.drawArc(Rect.fromLTWH(18, 18, size.width - 36, size.height - 36), start, sweep - .025, false, paint); start += sweep; } }
  @override bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}

class _Insights extends StatelessWidget {
  const _Insights({required this.report}); final ReportSnapshot report;
  @override Widget build(BuildContext context) { final savingRate = report.income == 0 ? 0 : (report.saving * 100 / report.income).round(); final top = report.categoryTotals.entries.isEmpty ? null : (report.categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first; return Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const CircleAvatar(backgroundColor: Color(0xFFFFF0C7), child: Icon(Icons.lightbulb, color: AppColors.amber)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [LText('ငွေကြေးသုံးသပ်ချက်', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 7), LText('✓ စုဆောင်းနှုန်း $savingRate% ရှိသည်။'), if (top != null) LText('✓ အများဆုံးအသုံးစရိတ်မှာ ${top.key} ဖြစ်သည်။')]))]))); }
}
