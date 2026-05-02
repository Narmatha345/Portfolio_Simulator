import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide ChartPoint;
import '../providers/sip_portfolio_provider.dart';
import '../widgets/common_ui.dart';
import '../models/portfolio_models.dart';

class StockSipScreen extends StatelessWidget {
  const StockSipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SipPortfolioProvider>(context);
    final f = NumberFormat("#,##0.00");

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("SIP (stocks)", 
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Color(0xFF111827))),
                  const SizedBox(height: 8),
                  const Text("Monthly investments across a date range. Interaction shows details.", 
                    style: TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
                  const SizedBox(height: 35),
                  
                  PageCard(
                    child: Column(
                      children: [
                        LayoutBuilder(builder: (ctx, cons) {
                          bool isMobile = cons.maxWidth < 800; 
                          return Flex(
                            direction: isMobile ? Axis.vertical : Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: isMobile ? 0 : 1, child: _buildInputSection(provider, 0, const Color(0xFF6366F1))),
                              if (!isMobile) const SizedBox(width: 32),
                              if (isMobile) const SizedBox(height: 30),
                              Expanded(flex: isMobile ? 0 : 1, child: _buildInputSection(provider, 1, const Color(0xFFEC4899))),
                            ],
                          );
                        }),
                        const SizedBox(height: 40),
                        _buildFixedDateRow(context, provider),
                      ],
                    ),
                  ),

                  if (provider.isLoading) 
                    const Center(child: Padding(padding: EdgeInsets.all(80), child: CircularProgressIndicator(color: Colors.black))),

                  if (!provider.isLoading && provider.portfolioValueData.isNotEmpty) ...[
                    const SizedBox(height: 45),
                    _buildSummarySection("Portfolio A", provider.summaryA, f),
                    const SizedBox(height: 45),
                    _buildSummarySection("Portfolio B", provider.summaryB, f),
                    const SizedBox(height: 45),
                    _buildChartCard("Portfolio Value (Compare)", provider.portfolioValueData, true),
                    _buildChartCard("Portfolio - Normalized (Base = 100) - Compare", provider.normalizedValueData, false),
                    _buildBreakdownTable("Portfolio A", provider.breakdownA, f),
                    _buildBreakdownTable("Portfolio B", provider.breakdownB, f),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFixedDateRow(BuildContext context, SipPortfolioProvider provider) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        _buildCalendarPicker(context, "Start month", provider.startMonth, (d) => provider.startMonth = d),
        _buildCalendarPicker(context, "End month", provider.endMonth, (d) => provider.endMonth = d),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: ElevatedButton(
            onPressed: provider.isLoading ? null : provider.handlePlot, 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ), 
            child: const Text("Plot", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarPicker(BuildContext context, String label, DateTime date, Function(DateTime) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            DateTime? picked = await showDatePicker(
              context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now()
            );
            if (picked != null) onSelect(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)), 
              borderRadius: BorderRadius.circular(6), 
              color: Colors.white
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat('MMM, yyyy').format(date), style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildInputSection(SipPortfolioProvider provider, int idx, Color color) {
    final p = provider.portfolios[idx];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 4, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 10), Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))]),
      const SizedBox(height: 18),
      ...p.entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
        Expanded(flex: 3, child: TextField(
          decoration: InputDecoration(hintText: "Ticker", filled: true, fillColor: const Color(0xFFF9FAFB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB)))), 
          onChanged: (v) => provider.updateEntry(idx, e.id, 'ticker', v),
        )),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("\$/mo", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))),
        Expanded(flex: 2, child: TextField(
          decoration: InputDecoration(hintText: "Amt", filled: true, fillColor: const Color(0xFFF9FAFB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB)))), 
          keyboardType: TextInputType.number, 
          onChanged: (v) => provider.updateEntry(idx, e.id, 'amount', v),
        )),
        const SizedBox(width: 4),
        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF9CA3AF), size: 22), onPressed: () => provider.removeRow(idx, e.id)),
      ]))),
      TextButton.icon(
        onPressed: () => provider.addRow(idx), 
        icon: const Icon(Icons.add, size: 18, color: Colors.black),
        label: const Text("Add stock", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
      ),
    ]);
  }

  Widget _buildSummarySection(String title, List<SipSummaryRow> rows, NumberFormat f) {
    if (rows.isEmpty) return const SizedBox.shrink();
    double totalInv = rows.fold(0, (sum, item) => sum + item.invested);
    double totalVal = rows.fold(0, (sum, item) => sum + item.endValue);
    double totalRet = totalInv > 0 ? ((totalVal - totalInv) / totalInv) * 100 : 0;
    double portfolioXirr = rows.isNotEmpty ? rows[0].xirr : 0; // Portfolio XIRR stored in first row

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
            border: TableBorder.all(color: const Color(0xFFE5E7EB), width: 1, borderRadius: BorderRadius.circular(4)),
            columns: const [
              DataColumn(label: Text("Ticker")),
              DataColumn(label: Text("Invested (\$")),
              DataColumn(label: Text("Units")),
              DataColumn(label: Text("End Value (\$")),
              DataColumn(label: Text("Return (%)")),
            ],
            rows: rows.map((r) => DataRow(cells: [
              DataCell(Text(r.ticker, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(f.format(r.invested))),
              DataCell(Text(r.units.toStringAsFixed(2))),
              DataCell(Text(f.format(r.endValue))),
              DataCell(Text("${r.returnPct >= 0 ? '+' : ''}${r.returnPct.toStringAsFixed(2)}%", 
                style: TextStyle(color: r.returnPct >= 0 ? const Color(0xFF16A34A) : Colors.red, fontWeight: FontWeight.bold))),
            ])).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Text.rich(TextSpan(text: "Total invested: ", style: const TextStyle(fontSize: 14.5, color: Color(0xFF374151)), children: [
          TextSpan(text: "\$${f.format(totalInv)}", style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: "  ·  Total value: "),
          TextSpan(text: "\$${f.format(totalVal)} ", style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: "(${totalRet >= 0 ? '+' : ''}${totalRet.toStringAsFixed(2)}%)", style: TextStyle(color: totalRet >= 0 ? const Color(0xFF16A34A) : Colors.red, fontWeight: FontWeight.bold)),
          const TextSpan(text: "  ·  XIRR: "),
          TextSpan(text: "${portfolioXirr.toStringAsFixed(2)}%", style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
        ])),
      ],
    );
  }

  Widget _buildBreakdownTable(String title, List<SipBreakdownRow> rows, NumberFormat f) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        const SizedBox(height: 55),
        Text("$title – SIP Calculation Breakdown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Color(0xFF111827))),
        const SizedBox(height: 10),
        const Text(
          "Per ticker: Price (\$) = on SIP date (1st of month); Month-end price (\$) = on last calendar day of month. Value (\$) is the portfolio total.",
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal, 
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
            border: TableBorder.all(color: const Color(0xFFE5E7EB), width: 1, borderRadius: BorderRadius.circular(4)),
            columnSpacing: 18,
            columns: const [
              DataColumn(label: Text("Month")),
              DataColumn(label: Text("Ticker")),
              DataColumn(label: Text("Price (\$)")),
              DataColumn(label: Text("SIP Amt (\$")),
              DataColumn(label: Text("Units Bought")),
              DataColumn(label: Text("Accum. Units")),
              DataColumn(label: Text("Investment (\$")),
              DataColumn(label: Text("Cumulative (\$")),
              DataColumn(label: Text("Month-end Price")),
              DataColumn(label: Text("Value (\$")),
              DataColumn(label: Text("Return %")),
            ],
            rows: rows.map((r) => DataRow(cells: [
              DataCell(Text(r.month)),
              DataCell(Text(r.ticker, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(f.format(r.buyPrice))),
              DataCell(Text(f.format(r.sipAmount))),
              DataCell(Text(r.unitsBought.toStringAsFixed(2))),
              DataCell(Text(r.accumulatedUnits.toStringAsFixed(2))),
              DataCell(Text(f.format(r.investment))),
              DataCell(Text(f.format(r.cumulativeInvested))),
              DataCell(Text(f.format(r.monthEndPrice))),
              DataCell(Text(f.format(r.value))),
              DataCell(Text(
                "${(r.returnPct ?? 0) >= 0 ? '+' : ''}${r.returnPct?.toStringAsFixed(2)}%", 
                style: TextStyle(color: (r.returnPct ?? 0) >= 0 ? const Color(0xFF16A34A) : Colors.red, fontWeight: FontWeight.bold)
              )),
            ])).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(String title, Map<String, List<ChartPoint>> data, bool isCurrency) {
    return PageCard(
      margin: const EdgeInsets.only(bottom: 35), 
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF111827))),
        const SizedBox(height: 25),
        SizedBox(height: 380, child: SfCartesianChart(
          primaryXAxis: DateTimeAxis(
            // FIX: Forcing Day, Month, Year format in trackball header natives
            dateFormat: DateFormat('dd MMM yyyy'), 
            majorGridLines: const MajorGridLines(width: 0.5, dashArray: [5, 5])
          ),
          primaryYAxis: NumericAxis(
            numberFormat: isCurrency ? NumberFormat.simpleCurrency(decimalDigits: 2) : NumberFormat.decimalPattern(), 
            majorGridLines: const MajorGridLines(width: 0.5, dashArray: [5, 5])
          ),
          trackballBehavior: TrackballBehavior(
            enable: true, 
            activationMode: ActivationMode.singleTap, 
            tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
            tooltipSettings: const InteractiveTooltip(
              enable: true,
              color: Color(0xFF1F2937),
              textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          series: data.entries.map((e) => LineSeries<ChartPoint, DateTime>(
            name: e.key == 'A' ? "Portfolio A" : "Portfolio B", dataSource: e.value,
            xValueMapper: (p, _) => p.date, yValueMapper: (p, _) => p.value,
            color: e.key == 'A' ? const Color(0xFF6366F1) : const Color(0xFFEC4899),
            width: 2.5,
          )).toList(),
        )),
      ])
    );
  }
}