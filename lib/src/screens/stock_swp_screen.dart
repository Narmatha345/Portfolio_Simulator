import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide ChartPoint;
import '../providers/swp_portfolio_provider.dart';
import '../widgets/common_ui.dart';
import '../models/swp_models.dart';
import '../models/portfolio_models.dart';

class StockSwpScreen extends StatelessWidget {
  const StockSwpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwpPortfolioProvider>(context);
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
                  const Text("SWP (stocks)", 
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Color(0xFF111827))),
                  const SizedBox(height: 8),
                  const Text("Systematic withdrawals comparison. Enter tickers and corpus, pick two strategies.", 
                    style: TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
                  const SizedBox(height: 35),
                  
                  PageCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Portfolio (shared)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    ...provider.corpusEntries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
                      Expanded(flex: 3, child: TextField(
                        decoration: const InputDecoration(hintText: "Ticker", filled: true, fillColor: Color(0xFFF9FAFB)), 
                        onChanged: (v) => provider.updateCorpus(e.id, 'ticker', v)
                      )),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("Corpus (\$)", style: TextStyle(fontSize: 12))),
                      Expanded(flex: 2, child: TextField(
                        decoration: const InputDecoration(hintText: "Amount", filled: true, fillColor: Color(0xFFF9FAFB)), 
                        keyboardType: TextInputType.number, 
                        onChanged: (v) => provider.updateCorpus(e.id, 'amount', v)
                      )),
                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.grey), onPressed: () => provider.removeCorpusRow(e.id)),
                    ]))),
                    TextButton.icon(onPressed: provider.addCorpusRow, icon: const Icon(Icons.add, size: 18), label: const Text("Add ticker", style: TextStyle(fontWeight: FontWeight.bold))),
                    const Divider(height: 40),
                    _buildDateRow(context, provider),
                  ])),

                  const SizedBox(height: 30),

                  LayoutBuilder(builder: (ctx, cons) => Flex(
                    direction: cons.maxWidth < 800 ? Axis.vertical : Axis.horizontal, 
                    children: [
                      Expanded(flex: cons.maxWidth < 800 ? 0 : 1, child: _buildStrategyBox("Strategy A", provider.strategyA, const Color(0xFF6366F1), provider)),
                      const SizedBox(width: 24, height: 24),
                      Expanded(flex: cons.maxWidth < 800 ? 0 : 1, child: _buildStrategyBox("Strategy B", provider.strategyB, const Color(0xFFEC4899), provider)),
                    ]
                  )),

                  const SizedBox(height: 35),
                  ElevatedButton(
                    onPressed: provider.isLoading ? null : provider.handleSimulate, 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))), 
                    child: const Text("Simulate", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  ),

                  if (provider.isLoading) const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator(color: Colors.black))),

                  if (!provider.isLoading && provider.swpPortfolioValueData.isNotEmpty) ...[
                    _buildChart("Portfolio Value (Compare)", provider.swpPortfolioValueData, true),
                    _buildChart("Withdrawal per Month (Compare)", provider.swpWithdrawalData, true),
                    _buildBreakdownTable(provider, f),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(BuildContext context, SwpPortfolioProvider p) {
    return Wrap(spacing: 20, runSpacing: 20, children: [
      _buildPicker(context, "Start month", p.startMonth, (d) => p.startMonth = d),
      _buildPicker(context, "End month", p.endMonth, (d) => p.endMonth = d),
    ]);
  }

  Widget _buildPicker(BuildContext context, String l, DateTime d, Function(DateTime) onS) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      InkWell(
        onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: d, firstDate: DateTime(2000), lastDate: DateTime.now()); if (p != null) onS(p); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), 
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(6), color: Colors.white), 
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text(DateFormat('MMM, yyyy').format(d)), const SizedBox(width: 8), const Icon(Icons.calendar_today, size: 14, color: Color(0xFF6B7280))])
        )
      ),
    ]);
  }

  Widget _buildStrategyBox(String n, WithdrawalStrategy s, Color c, SwpPortfolioProvider p) {
    return Container(
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: c, width: 4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        const Text("Withdrawal type", style: TextStyle(fontSize: 12, color: Colors.grey)),
        DropdownButton<WithdrawalType>(
          value: s.type, 
          isExpanded: true, 
          items: const [
            DropdownMenuItem(value: WithdrawalType.fixed, child: Text("Fixed \$/month")), 
            DropdownMenuItem(value: WithdrawalType.fixedGrowth, child: Text("Fixed \$ + growth %/month")), 
            DropdownMenuItem(value: WithdrawalType.percent, child: Text("% of portfolio/month"))
          ], 
          onChanged: (v) { if (v != null) { s.type = v; p.notifyListeners(); } }
        ),
        const SizedBox(height: 16),
        Text(s.type == WithdrawalType.percent ? "Withdraw (%/month)" : "Amount (\$/month) at start", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        TextField(
          keyboardType: TextInputType.number, 
          decoration: const InputDecoration(filled: true, fillColor: Colors.white), 
          onChanged: (v) { s.amount = double.tryParse(v) ?? 0; }
        ),
        if (s.type == WithdrawalType.fixedGrowth) ...[
          const SizedBox(height: 16),
          const Text("Monthly growth (%)", style: TextStyle(fontSize: 12, color: Colors.grey)),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(filled: true, fillColor: Colors.white),
            onChanged: (v) { s.growthPct = double.tryParse(v) ?? 0; },
          ),
        ]
      ])
    );
  }

  Widget _buildChart(String t, Map<String, List<ChartPoint>> d, bool cur) {
    return PageCard(
      margin: const EdgeInsets.only(top: 40), 
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 25),
        SizedBox(height: 350, child: SfCartesianChart(
          primaryXAxis: DateTimeAxis(
            // FIX: Forcing Day, Month, Year format in trackball header natives
            dateFormat: DateFormat('dd MMM yyyy'), 
            majorGridLines: const MajorGridLines(width: 0),
          ),
          primaryYAxis: NumericAxis(
            // FIX: Removed .compactCurrency, using full decimal format
            numberFormat: cur ? NumberFormat.simpleCurrency(decimalDigits: 2) : NumberFormat.decimalPattern(),
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
          series: d.entries.map((e) => LineSeries<ChartPoint, DateTime>(
            name: e.key,
            dataSource: e.value, 
            xValueMapper: (ChartPoint x, _) => x.date, 
            yValueMapper: (ChartPoint x, _) => x.value,
            color: e.key.contains('A') ? const Color(0xFF6366F1) : const Color(0xFFEC4899),
            width: 2,
          )).toList()
        )),
      ])
    );
  }

  Widget _buildBreakdownTable(SwpPortfolioProvider p, NumberFormat f) {
    if (p.breakdownRows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 50),
        const Text("SWP Withdrawal Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal, 
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
            border: TableBorder.all(color: const Color(0xFFE5E7EB), width: 1, borderRadius: BorderRadius.circular(4)),
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text("Month")), 
              DataColumn(label: Text("A Value (\$")), 
              DataColumn(label: Text("A Withdraw (\$")), 
              DataColumn(label: Text("A Cumul. (\$")), 
              DataColumn(label: Text("B Value (\$")), 
              DataColumn(label: Text("B Withdraw (\$")), 
              DataColumn(label: Text("B Cumul. (\$")), 
            ], 
            rows: p.breakdownRows.map((r) => DataRow(cells: [
              DataCell(Text(DateFormat('yyyy-MM').format(r.date))), 
              DataCell(Text(f.format(r.strategyAValue))), 
              DataCell(Text(f.format(r.strategyAWithdrawal), style: const TextStyle(color: Color(0xFF6366F1)))), 
              DataCell(Text(f.format(r.strategyACumulative), style: const TextStyle(fontWeight: FontWeight.bold))), 
              DataCell(Text(f.format(r.strategyBValue))), 
              DataCell(Text(f.format(r.strategyBWithdrawal), style: const TextStyle(color: Color(0xFFEC4899)))), 
              DataCell(Text(f.format(r.strategyBCumulative), style: const TextStyle(fontWeight: FontWeight.bold))), 
            ])).toList()
          )
        ),
        _buildMonthPriceTable(p, f),
      ],
    );
  }

  Widget _buildMonthPriceTable(SwpPortfolioProvider p, NumberFormat f) {
    if (p.monthPriceRows.isEmpty) return const SizedBox.shrink();
    
    // Get all unique tickers
    Set<String> allTickers = {};
    for (var row in p.monthPriceRows) {
      allTickers.addAll(row.prices.keys);
    }
    List<String> sortedTickers = allTickers.toList()..sort();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Text("Month-End Prices (Used for Calculation)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        const SizedBox(height: 10),
        const Text("Shows the price and trading date used for each ticker at month-end", style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal, 
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
            border: TableBorder.all(color: const Color(0xFFE5E7EB), width: 1, borderRadius: BorderRadius.circular(4)),
            columnSpacing: 20,
            columns: [
              const DataColumn(label: Text("Month")),
              ...sortedTickers.map((ticker) => DataColumn(label: Text(ticker))).toList(),
            ],
            rows: p.monthPriceRows.map((row) => DataRow(cells: [
              DataCell(Text(DateFormat('yyyy-MM').format(row.month))),
              ...sortedTickers.map((ticker) {
                if (!row.prices.containsKey(ticker)) {
                  return DataCell(Text("—", style: TextStyle(color: Colors.grey[400])));
                }
                double price = row.prices[ticker]!;
                DateTime tradingDate = row.tradingDates[ticker]!;
                String tradingDateStr = DateFormat('yyyy-MM-dd').format(tradingDate);
                return DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(f.format(price), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(tradingDateStr, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                );
              }).toList(),
            ])).toList()
          )
        ),
      ],
    );
  }
}