import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide ChartPoint;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart'; 
import '../models/portfolio_models.dart';
import '../services/yahoo_finance_service.dart';
import '../services/gemini_service.dart'; 
import '../widgets/common_ui.dart';
import '../widgets/stock_price_chart.dart';

class NetworthEstimatorCopyScreen extends StatefulWidget {
  const NetworthEstimatorCopyScreen({super.key});

  @override
  State<NetworthEstimatorCopyScreen> createState() => _NetworthEstimatorCopyScreenState();
}

class HoldingRow {
  String id;
  String ticker;
  TextEditingController unitsController;
  HoldingRow({required this.id, this.ticker = '', String units = ''})
      : unitsController = TextEditingController(text: units);
}

class _NetworthEstimatorCopyScreenState extends State<NetworthEstimatorCopyScreen> {
  final YahooFinanceService _service = YahooFinanceService();
  final GeminiService _geminiService = GeminiService(); 
  final List<HoldingRow> _rows = [HoldingRow(id: '1', ticker: 'MSFT', units: '11')];
  
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _showApiKey = false;
  String? _geminiResponse;

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

    final firstTickerWithData = rawPrices.keys.firstWhere((k) => rawPrices[k]!.isNotEmpty);
    final commonDates = rawPrices[firstTickerWithData]!.map((p) => p.date).toList()..sort();

    if (commonDates.isEmpty) return;

    // FIX: Normalization base price selection (React Logic Match)
    // Stock price-ah dhaan base-ah (100) veikkanum, Net worth value-ah illa.
    Map<String, double> basePrices = {};
    for (var ticker in rawPrices.keys) {
      if (rawPrices[ticker]!.isNotEmpty) {
        // Range-oda first available price-ah base-ah yedukirom
        basePrices[ticker] = rawPrices[ticker]!.first.value;
      }
    }

    for (var date in commonDates) {
      double dayTotal = 0;
      for (var row in _rows) {
        String t = row.ticker.trim().toUpperCase();
        double u = double.tryParse(row.unitsController.text) ?? 0;
        
        if (t.isNotEmpty && rawPrices.containsKey(t)) {
          final pricePoint = rawPrices[t]!.firstWhere(
            (p) => p.date.isAtSameMomentAs(date),
            orElse: () => rawPrices[t]!.firstWhere((p) => p.date.isAfter(date), orElse: () => rawPrices[t]!.last)
          );
          
          double currentPrice = pricePoint.value;
          double val = u * currentPrice;
          dayTotal += val;
          
          _byTickerSeries.putIfAbsent(t, () => []).add(ChartPoint(date, val));

          // FIX: RELATIVE PERFORMANCE (Indexed to 100)
          // Formula: (Current Price / Starting Price) * 100
          if (basePrices.containsKey(t) && basePrices[t] != 0) {
            double normalizedValue = (currentPrice / basePrices[t]!) * 100;
            _normalizedSeries.putIfAbsent(t, () => []).add(ChartPoint(date, normalizedValue));
          }
        }
      }
      _totalNetWorth.add(ChartPoint(date, dayTotal));
    }
  }

  Future<void> _handleSend() async {
    if (_promptController.text.trim().isEmpty) {
      setState(() => _error = "Enter a Gemini prompt before sending.");
      return;
    }

    setState(() { 
      _isLoading = true; 
      _error = null; 
      _geminiResponse = null;
    });

    try {
      Map<String, List<ChartPoint>> rawPrices = {};
      for (var row in _rows) {
        String t = row.ticker.trim().toUpperCase();
        if (t.isNotEmpty && !rawPrices.containsKey(t)) {
          var data = await _service.fetchStockData(t, 
            startDate: DateFormat('yyyy-MM-dd').format(_startDate),
            endDate: DateFormat('yyyy-MM-dd').format(_endDate)
          );
          if (data.isNotEmpty) rawPrices[t] = data;
        }
      }
      
      if (rawPrices.isEmpty) {
        setState(() => _error = "Could not find price data for these tickers.");
      } else {
        _processData(rawPrices);
        
        final payload = {
          'holdings': _rows.map((r) => {'ticker': r.ticker, 'units': r.unitsController.text}).toList(),
          'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
          'endDate': DateFormat('yyyy-MM-dd').format(_endDate),
          'netWorthSeries': _totalNetWorth,
        };

        final result = await _geminiService.sendNetworthDataToGemini(
          promptText: _promptController.text.trim(),
          networthData: payload,
          userApiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
        );

        setState(() => _geminiResponse = result);
      }
    } catch (e) {
      setState(() => _error = "Error: ${e.toString()}");
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
                _buildGeminiInputs(), 
                const SizedBox(height: 24),
                _buildDateControls(),
              ])),

              if (_error != null) 
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20), 
                  child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                ),

              if (_geminiResponse != null) _buildAiResponseCard(),

              if (_totalNetWorth.isNotEmpty) ...[
                const SizedBox(height: 40),
                StockPriceChart(data: _totalNetWorth, chartTitle: "Portfolio net worth", ticker: "Net worth"),
                const SizedBox(height: 32),
                StockPriceChart(seriesMap: _byTickerSeries, chartTitle: "Value by holding (USD)"),
                const SizedBox(height: 32),
                StockPriceChart(seriesMap: _byTickerSeries, chartTitle: "Portfolio composition (stacked value)", isStacked: true),
                const SizedBox(height: 32),
                StockPriceChart(seriesMap: _normalizedSeries, chartTitle: "Relative performance (indexed to 100)"),
              ],

              if (_totalNetWorth.isEmpty && !_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text("Enter holdings and dates, then click Send.", style: TextStyle(color: Colors.grey)),
                ),
            ]),
          ),
          if (_isLoading) const LoadingOverlay(active: true),
        ],
      ),
    );
  }

  Widget _buildGeminiInputs() {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        SizedBox(
          width: 300,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Gemini prompt", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(hintText: "Ask Gemini about this portfolio", contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            ),
          ]),
        ),
        SizedBox(
          width: 250,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(text: const TextSpan(style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold), children: [
              TextSpan(text: "Gemini API key "),
              TextSpan(text: "(optional — overrides env key)", style: TextStyle(fontWeight: FontWeight.normal, color: Colors.grey, fontSize: 10)),
            ])),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              obscureText: !_showApiKey,
              decoration: InputDecoration(
                hintText: "AIzaSy...",
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: IconButton(
                  icon: Icon(_showApiKey ? Icons.visibility : Icons.visibility_off, size: 18),
                  onPressed: () => setState(() => _showApiKey = !_showApiKey),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildAiResponseCard() {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)),
        gradient: const LinearGradient(colors: [Color(0xFFF8FAFF), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE0E7FF))), color: Color(0x0A4F46E5)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)])),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            const Text("AI ANALYSIS", style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Markdown(
            data: _geminiResponse!,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ),
      ]),
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
        onPressed: _handleSend, 
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black, 
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
        ),
        child: const Text("Send", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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