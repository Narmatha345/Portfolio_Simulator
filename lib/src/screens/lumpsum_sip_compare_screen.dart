import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide ChartPoint;
import '../models/portfolio_models.dart';
import '../services/yahoo_finance_service.dart';
import '../widgets/common_ui.dart';

class LumpsumSipCompareScreen extends StatefulWidget {
  const LumpsumSipCompareScreen({super.key});

  @override
  State<LumpsumSipCompareScreen> createState() => _LumpsumSipCompareScreenState();
}

class PortfolioEntry {
  String id;
  String ticker;
  TextEditingController amountController;
  PortfolioEntry({required this.id, this.ticker = '', String amount = ''})
      : amountController = TextEditingController(text: amount);
}

class _LumpsumSipCompareScreenState extends State<LumpsumSipCompareScreen> {
  final YahooFinanceService _service = YahooFinanceService();
  List<PortfolioEntry> _entries = [PortfolioEntry(id: '1', ticker: 'VOO', amount: '1000')];
  
  DateTime _startMonth = DateTime.utc(2025, 05, 01);
  DateTime _endMonth = DateTime.utc(2026, 04, 01);
  
  Map<String, List<ChartPoint>> _priceDataByTicker = {};
  bool _isLoading = false;
  bool _hasResults = false;

  double _calculateXIRR(List<double> cashFlows, List<DateTime> dates) {
    double guess = 0.1;
    for (int i = 0; i < 100; i++) {
      double f = 0; double df = 0;
      for (int j = 0; j < cashFlows.length; j++) {
        double t = dates[j].difference(dates[0]).inDays / 365.25;
        f += cashFlows[j] / pow(1 + guess, t);
        df -= t * cashFlows[j] / pow(1 + guess, t + 1);
      }
      double nextGuess = guess - f / df;
      if ((nextGuess - guess).abs() < 1e-7) return nextGuess;
      guess = nextGuess;
    }
    return guess;
  }

  double _getPriceAtDate(List<ChartPoint> data, DateTime target) {
    return data.firstWhere((p) => p.date.isAfter(target) || p.date.isAtSameMomentAs(target), 
        orElse: () => data.last).value;
  }

  Map<String, dynamic> _computeResults() {
    double lTotalInv = 0, lTotalEnd = 0, sTotalInv = 0, sTotalEnd = 0;
    List<Map<String, dynamic>> lDetails = [], sDetails = [], monthlyBD = [];
    List<DateTime> months = [];
    DateTime curr = DateTime(_startMonth.year, _startMonth.month, 1);
    while (curr.isBefore(_endMonth) || curr.isAtSameMomentAs(_endMonth)) {
      months.add(curr);
      curr = DateTime(curr.year, curr.month + 1, 1);
    }
    final endDT = DateTime(_endMonth.year, _endMonth.month + 1, 0);

    Map<String, double> accUnitsMap = {};
    double cumulativeInvested = 0;

    for (var m in months) {
      for (var entry in _entries) {
        String t = entry.ticker.trim().toUpperCase();
        double totalAmt = double.tryParse(entry.amountController.text) ?? 0;
        if (t.isEmpty || totalAmt <= 0 || !_priceDataByTicker.containsKey(t)) continue;

        var data = _priceDataByTicker[t]!;
        double moAmt = totalAmt / months.length;
        double p = _getPriceAtDate(data, m);
        double uBot = moAmt / p;
        accUnitsMap[t] = (accUnitsMap[t] ?? 0) + uBot;
        cumulativeInvested += moAmt;
        double mEndP = _getPriceAtDate(data, DateTime(m.year, m.month + 1, 0));
        
        double currentPortfolioValue = 0;
        accUnitsMap.forEach((key, units) {
          currentPortfolioValue += units * _getPriceAtDate(_priceDataByTicker[key]!, DateTime(m.year, m.month + 1, 0));
        });

        monthlyBD.add({
          'm': DateFormat('yyyy-MM').format(m), 't': t, 'p': p, 'sip': moAmt,
          'uBot': uBot, 'accU': accUnitsMap[t], 'inv': moAmt, 'cumInv': cumulativeInvested,
          'mEndP': mEndP, 'val': currentPortfolioValue, 'ret': ((currentPortfolioValue - cumulativeInvested) / cumulativeInvested) * 100,
        });
      }
    }

    for (var entry in _entries) {
      String t = entry.ticker.trim().toUpperCase();
      double amt = double.tryParse(entry.amountController.text) ?? 0;
      if (t.isEmpty || amt <= 0 || !_priceDataByTicker.containsKey(t)) continue;
      double lEndP = _getPriceAtDate(_priceDataByTicker[t]!, endDT);
      lTotalInv += amt;
      lTotalEnd += (amt / _getPriceAtDate(_priceDataByTicker[t]!, _startMonth)) * lEndP;
      lDetails.add({'t': t, 'inv': amt, 'u': amt / _getPriceAtDate(_priceDataByTicker[t]!, _startMonth), 'val': (amt / _getPriceAtDate(_priceDataByTicker[t]!, _startMonth)) * lEndP});
      double sUnits = monthlyBD.where((row) => row['t'] == t).fold(0.0, (sum, row) => sum + row['uBot']);
      sTotalInv += amt;
      sTotalEnd += sUnits * lEndP;
      sDetails.add({'t': t, 'inv': amt, 'mo': amt / months.length, 'u': sUnits, 'val': sUnits * lEndP});
    }

    return {
      'lInv': lTotalInv, 'lEnd': lTotalEnd, 'lXirr': _calculateXIRR([-lTotalInv, lTotalEnd], [_startMonth, endDT]),
      'sInv': sTotalInv, 'sEnd': sTotalEnd, 'sXirr': _calculateXIRR([...List.generate(months.length, (_) => -(sTotalInv / months.length)), sTotalEnd], [...months, endDT]),
      'lDetails': lDetails, 'sDetails': sDetails, 'bd': monthlyBD,
    };
  }

  Future<void> _handleCompare() async {
    setState(() { _isLoading = true; _hasResults = false; });
    try {
      bool success = false;
      for (var e in _entries) {
        String ticker = e.ticker.trim().toUpperCase();
        if (ticker.isNotEmpty) {
          var data = await _service.fetchStockData(ticker, 
              startDate: DateFormat('yyyy-MM-dd').format(_startMonth.subtract(const Duration(days: 7))),
              endDate: DateFormat('yyyy-MM-dd').format(_endMonth.add(const Duration(days: 35))));
          if (data.isNotEmpty) { _priceDataByTicker[ticker] = data; success = true; }
        }
      }
      setState(() { _hasResults = success; });
    } catch (_) {} finally { setState(() { _isLoading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final res = _hasResults ? _computeResults() : null;
    final f = NumberFormat("#,##0.00");

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Compare Lumpsum vs SIP", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildHoldingsCard(),
          const SizedBox(height: 24),
          _buildControls(),
          if (_isLoading) const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator(color: Colors.black))),
          if (_hasResults && res != null) ...[
            const SizedBox(height: 40),
            _buildResultsSummary(res, f),
            const SizedBox(height: 40),
            _buildChartSection(), 
            const SizedBox(height: 40),
            const Text("SIP calculation breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            _buildSIPBreakdownTable(res, f),
          ]
        ]),
      ),
    );
  }

  Widget _buildHoldingsCard() => PageCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text("Holdings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    ..._entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 15), child: Wrap(spacing: 20, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      SizedBox(width: 120, child: TextField(onChanged: (v) => e.ticker = v.toUpperCase(), decoration: const InputDecoration(hintText: "Ticker", isDense: true))),
      const Text("Total \$", style: TextStyle(fontWeight: FontWeight.bold)),
      SizedBox(width: 100, child: TextField(controller: e.amountController, decoration: const InputDecoration(isDense: true), keyboardType: TextInputType.number)),
      TextButton(onPressed: () => setState(() => _entries.remove(e)), child: const Text("Remove", style: TextStyle(color: Colors.grey))),
    ]))),
    Center(child: TextButton(onPressed: () => setState(() => _entries.add(PortfolioEntry(id: DateTime.now().toString()))), child: const Text("+ Add stock", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
  ]));

  Widget _buildResultsSummary(Map<String, dynamic> res, NumberFormat f) {
    bool lWin = res['lEnd'] > res['sEnd'];
    return PageCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Results", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        columns: const [DataColumn(label: Text("Scenario")), DataColumn(label: Text("Total Invested (\$)")), DataColumn(label: Text("End Value (\$)")), DataColumn(label: Text("Return (%)")), DataColumn(label: Text("XIRR (%)"))],
        rows: [
          _resRow("Lumpsum (all at start)", res['lInv'], res['lEnd'], (res['lEnd']-res['lInv'])/res['lInv']*100, res['lXirr'], f),
          _resRow("SIP (equal monthly)", res['sInv'], res['sEnd'], (res['sEnd']-res['sInv'])/res['sInv']*100, res['sXirr'], f),
        ],
      )),
      const SizedBox(height: 24),
      RichText(text: TextSpan(style: const TextStyle(color: Colors.black, fontSize: 16), children: [
        const TextSpan(text: "Winner: ", style: TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: lWin ? "Lumpsum " : "SIP ", style: TextStyle(color: lWin ? Colors.indigo : Colors.pink, fontWeight: FontWeight.bold)),
        TextSpan(text: "(+\$${f.format((res['lEnd'] - res['sEnd']).abs())} more)", style: const TextStyle(color: Colors.indigo)),
      ])),
      const SizedBox(height: 32),
      const Text("Lumpsum Breakdown (per stock)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      _detailTable(res['lDetails'], f, false),
      const SizedBox(height: 32),
      const Text("SIP Breakdown (per stock)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      _detailTable(res['sDetails'], f, true),
    ]));
  }

  DataRow _resRow(String s, double inv, double end, double ret, double x, NumberFormat f) => DataRow(cells: [
    DataCell(Text(s)), DataCell(Text(f.format(inv))), DataCell(Text(f.format(end))),
    DataCell(Text("+${ret.toStringAsFixed(2)}%", style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold))),
    DataCell(Text("${(x * 100).toStringAsFixed(2)}%", style: const TextStyle(color: Color(0xFF10B981)))),
  ]);

  Widget _detailTable(List<dynamic> list, NumberFormat f, bool isSip) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
    columns: [const DataColumn(label: Text("Ticker")), const DataColumn(label: Text("Invested (\$)")), if (isSip) const DataColumn(label: Text("\$/mo")), const DataColumn(label: Text("Units")), const DataColumn(label: Text("End Value (\$)")), const DataColumn(label: Text("Return (%)"))],
    rows: list.map<DataRow>((d) => DataRow(cells: [DataCell(Text(d['t'])), DataCell(Text(f.format(d['inv']))), if (isSip) DataCell(Text(f.format(d['mo']))), DataCell(Text(d['u'].toStringAsFixed(6))), DataCell(Text(f.format(d['val']))), DataCell(Text("+${((d['val']-d['inv'])/d['inv']*100).toStringAsFixed(2)}%", style: const TextStyle(color: Color(0xFF10B981))))])).toList(),
  ));

  Widget _buildSIPBreakdownTable(Map<String, dynamic> res, NumberFormat f) => PageCard(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
    columns: const [
      DataColumn(label: Text("Month")), DataColumn(label: Text("Ticker")), 
      DataColumn(label: Text("Price (\$)")), DataColumn(label: Text("SIP Amount (\$)")), 
      DataColumn(label: Text("Units Bought")), DataColumn(label: Text("Accumulated Units")), 
      DataColumn(label: Text("Investment (\$)")), DataColumn(label: Text("Cumulative (\$)")), 
      DataColumn(label: Text("Month-end price (\$)")), DataColumn(label: Text("Value (\$)")), 
      DataColumn(label: Text("Return (%)"))
    ],
    rows: res['bd'].map<DataRow>((r) => DataRow(cells: [
      DataCell(Text(r['m'])), DataCell(Text(r['t'])), DataCell(Text(f.format(r['p']))), DataCell(Text(f.format(r['sip']))), DataCell(Text(r['uBot'].toStringAsFixed(2))), DataCell(Text(r['accU'].toStringAsFixed(2))), DataCell(Text(f.format(r['inv']))), DataCell(Text(f.format(r['cumInv']))), DataCell(Text(f.format(r['mEndP']))), DataCell(Text(f.format(r['val']))),
      DataCell(Text("${r['ret'] >= 0 ? '+' : ''}${r['ret'].toStringAsFixed(2)}%", style: TextStyle(color: r['ret'] >= 0 ? const Color(0xFF10B981) : Colors.red, fontWeight: FontWeight.bold))),
    ])).toList(),
  )));

  Widget _buildChartSection() {
    String t = _entries.first.ticker.toUpperCase();
    if (!_priceDataByTicker.containsKey(t)) return const SizedBox();
    
    return PageCard(child: Column(children: [
      const Text("Portfolio - Price", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 20),
      SizedBox(height: 400, child: SfCartesianChart(
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
        primaryXAxis: DateTimeAxis(
          // FIX: Showing Full Date format in the axis for better tooltip visibility
          dateFormat: DateFormat('dd MMM yyyy'),
          majorGridLines: const MajorGridLines(width: 0),
        ),
        primaryYAxis: NumericAxis(
          numberFormat: NumberFormat.simpleCurrency(decimalDigits: 2),
        ),
        series: <CartesianSeries<ChartPoint, DateTime>>[
          LineSeries(
            dataSource: _priceDataByTicker[t]!, 
            xValueMapper: (ChartPoint d, _) => d.date, 
            yValueMapper: (ChartPoint d, _) => d.value, 
            color: const Color(0xFF007BFF), 
            width: 2.5,
            name: t,
          )
        ],
      )),
    ]));
  }

  Widget _buildControls() => Wrap(spacing: 20, runSpacing: 20, crossAxisAlignment: WrapCrossAlignment.end, children: [
    _buildPicker("Start month", _startMonth, (d) => setState(() => _startMonth = d)),
    _buildPicker("End month", _endMonth, (d) => setState(() => _endMonth = d)),
    ElevatedButton(onPressed: _handleCompare, style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 22), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))), child: const Text("Compare", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
  ]);

  // FIX: Renamed 'd' to 'date' to solve compilation error
  Widget _buildPicker(String label, DateTime date, Function(DateTime) onSelect) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 8),
    InkWell(onTap: () async { DateTime? picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now()); if (picked != null) onSelect(picked); },
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4), color: Colors.white), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(DateFormat('MMMM, yyyy').format(date)), const SizedBox(width: 8), const Icon(Icons.calendar_today, size: 16)]))),
  ]);
}