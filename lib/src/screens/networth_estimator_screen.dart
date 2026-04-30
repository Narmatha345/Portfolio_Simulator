import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide ChartPoint;
import '../models/portfolio_models.dart';
import '../services/yahoo_finance_service.dart';
import '../widgets/common_ui.dart';
import '../widgets/stock_price_chart.dart';

class NetworthEstimatorScreen extends StatefulWidget {
  const NetworthEstimatorScreen({super.key});

  @override
  State<NetworthEstimatorScreen> createState() => _NetworthEstimatorScreenState();
}

class HoldingRow {
  String id;
  String ticker;
  TextEditingController unitsController;
  HoldingRow({required this.id, this.ticker = '', String units = ''})
      : unitsController = TextEditingController(text: units);
}

class _NetworthEstimatorScreenState extends State<NetworthEstimatorScreen> {
  final YahooFinanceService _service = YahooFinanceService();
  final List<HoldingRow> _rows = [HoldingRow(id: '1', ticker: 'AAPL', units: '11')];
  
  DateTime _startDate = DateTime.utc(2025, 04, 30);
  DateTime _endDate = DateTime.utc(2026, 04, 30);

  bool _isLoading = false;
  String? _error;

  List<ChartPoint> _totalNetWorth = [];
  Map<String, List<ChartPoint>> _byTickerSeries = {};
  Map<String, List<ChartPoint>> _normalizedSeries = {};

  void _processData(Map<String, List<ChartPoint>> rawPrices) {
    _byTickerSeries.clear();
    _totalNetWorth.clear();
    _normalizedSeries.clear();

    if (rawPrices.isEmpty) return;

    // Get a common list of dates from any ticker that has data
    final firstTickerWithData = rawPrices.keys.firstWhere((k) => rawPrices[k]!.isNotEmpty);
    final commonDates = rawPrices[firstTickerWithData]!.map((p) => p.date).toList();

    for (var date in commonDates) {
      double dayTotal = 0;
      for (var row in _rows) {
        String t = row.ticker.trim().toUpperCase();
        double u = double.tryParse(row.unitsController.text) ?? 0;
        
        // SAFE CHECK: Ensuring ticker data exists in rawPrices before accessing
        if (t.isNotEmpty && u > 0 && rawPrices.containsKey(t) && rawPrices[t]!.isNotEmpty) {
          // Finding price for exact date or closest one
          final pricePoint = rawPrices[t]!.firstWhere(
            (p) => p.date.isAtSameMomentAs(date) || p.date.isAfter(date),
            orElse: () => rawPrices[t]!.last
          );
          
          double val = u * pricePoint.value;
          dayTotal += val;

          _byTickerSeries.putIfAbsent(t, () => []).add(ChartPoint(date, val));
        }
      }
      _totalNetWorth.add(ChartPoint(date, dayTotal));
    }

    // Performance Indexed to 100 logic
    _byTickerSeries.forEach((ticker, data) {
      if (data.isNotEmpty) {
        double startVal = data.first.value;
        if (startVal != 0) {
          _normalizedSeries[ticker] = data.map((p) => ChartPoint(p.date, (p.value / startVal) * 100)).toList();
        }
      }
    });
  }

  Future<void> _handleLoadChart() async {
    setState(() { 
      _isLoading = true; 
      _error = null; 
      _totalNetWorth = [];
      _byTickerSeries = {};
      _normalizedSeries = {};
    });

    try {
      Map<String, List<ChartPoint>> rawPrices = {};
      for (var row in _rows) {
        String t = row.ticker.trim().toUpperCase();
        if (t.isNotEmpty && !rawPrices.containsKey(t)) {
          // Adjusting start date to fetch a bit earlier for padding
          var data = await _service.fetchStockData(t, 
            startDate: DateFormat('yyyy-MM-dd').format(_startDate.subtract(const Duration(days: 7))),
            endDate: DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 7)))
          );
          if (data.isNotEmpty) {
            rawPrices[t] = data;
          }
        }
      }
      
      if (rawPrices.isEmpty) {
        setState(() => _error = "Could not find price data for these tickers.");
      } else {
        _processData(rawPrices);
        setState(() {}); // Trigger UI update after processing
      }
    } catch (e) {
      setState(() => _error = "Failed to load charts: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const PageIntro(
                title: "Net worth estimator", 
                description: "Enter stock tickers and share counts. Load charts to see total net worth, holding value, composition, and relative performance."
              ),

              PageCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Holdings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                ..._rows.map((row) => _buildHoldingInput(row)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _rows.add(HoldingRow(id: DateTime.now().toString()))),
                  child: const Text("+ Add holding", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
                _buildDateControls(),
              ])),

              if (_error != null) 
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20), 
                  child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                ),

              if (_totalNetWorth.isNotEmpty) ...[
                const SizedBox(height: 40),
                StockPriceChart(data: _totalNetWorth, chartTitle: "Portfolio net worth", ticker: "Net worth"),
                const SizedBox(height: 32),
                StockPriceChart(seriesMap: _byTickerSeries, chartTitle: "Value by holding (USD)"),
                const SizedBox(height: 32),
                StockPriceChart(seriesMap: _byTickerSeries, chartTitle: "Portfolio composition (stacked value)", isStacked: true),
                const SizedBox(height: 32),
                StockPriceChart(seriesMap: _normalizedSeries, chartTitle: "Relative performance (indexed to 100)"),
              ]
            ]),
          ),
          if (_isLoading) const LoadingOverlay(active: true),
        ],
      ),
    );
  }

  Widget _buildHoldingInput(HoldingRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(spacing: 20, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.end, children: [
        SizedBox(width: 140, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Ticker", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          TextField(onChanged: (v) => row.ticker = v.toUpperCase(), decoration: const InputDecoration(hintText: "AAPL")),
        ])),
        SizedBox(width: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Units / \$", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          TextField(controller: row.unitsController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "10.5")),
        ])),
        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.grey), onPressed: () => setState(() => _rows.remove(row))),
      ]),
    );
  }

  Widget _buildDateControls() {
    return Wrap(spacing: 20, runSpacing: 20, crossAxisAlignment: WrapCrossAlignment.end, children: [
      _buildDatePicker("Start date", _startDate, (d) => setState(() => _startDate = d)),
      _buildDatePicker("End date", _endDate, (d) => setState(() => _endDate = d)),
      ElevatedButton(
        onPressed: _handleLoadChart,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black, 
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
        ),
        child: const Text("Load chart", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  Widget _buildDatePicker(String label, DateTime date, Function(DateTime) onSelect) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      InkWell(
        onTap: () async {
          DateTime? p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
          if (p != null) onSelect(p);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: Colors.white),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text(DateFormat('dd-MM-yyyy').format(date)), const SizedBox(width: 8), const Icon(Icons.calendar_today, size: 16)]),
        ),
      ),
    ]);
  }
}