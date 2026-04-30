import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/portfolio_models.dart';
import '../services/yahoo_finance_service.dart';
import '../widgets/common_ui.dart';
import '../widgets/stock_price_chart.dart';
class NetworthGoldScreen extends StatefulWidget {

  const NetworthGoldScreen({super.key});
  @override

  State<NetworthGoldScreen> createState() => _NetworthGoldScreenState();

}

class GoldHoldingRow {

  String id;

  String ticker;

  TextEditingController unitsController;

  GoldHoldingRow({required this.id, this.ticker = '', String units = ''})

      : unitsController = TextEditingController(text: units);

}

class _NetworthGoldScreenState extends State<NetworthGoldScreen> {

  final YahooFinanceService _service = YahooFinanceService();

  final List<GoldHoldingRow> _rows = [GoldHoldingRow(id: '1', ticker: 'AAPL', units: '10')];

  DateTime _startDate = DateTime.utc(2025, 04, 30);

  DateTime _endDate = DateTime.utc(2026, 04, 30);

  bool _isLoading = false;

  String? _error;

  List<ChartPoint> _goldInUSD = [];

  List<ChartPoint> _portfolioInGold = [];

  Map<String, List<ChartPoint>> _stockPricesUSD = {};

  String _formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _handleLoadGoldView() async {

    setState(() {

      _isLoading = true;

      _error = null;

      _goldInUSD = [];

      _portfolioInGold = [];

      _stockPricesUSD = {};

    });

    try {

      // 1. Fetch Gold Data

      var gldData = await _service.fetchStockData('GLD',

        startDate: DateFormat('yyyy-MM-dd').format(_startDate),

        endDate: DateFormat('yyyy-MM-dd').format(_endDate)

      );

      if (gldData.isEmpty) throw "Could not fetch Gold (GLD) data.";
      // 2. Fetch Stock Data

      Map<String, List<ChartPoint>> rawStockData = {};

      for (var row in _rows) {

        String t = row.ticker.trim().toUpperCase();

        if (t.isNotEmpty && !rawStockData.containsKey(t)) {

          var data = await _service.fetchStockData(t,

            startDate: DateFormat('yyyy-MM-dd').format(_startDate),

            endDate: DateFormat('yyyy-MM-dd').format(_endDate)

          );

          if (data.isNotEmpty) rawStockData[t] = data;

        }

      }
      if (rawStockData.isEmpty) throw "Add at least one valid ticker.";

      // 3. SAFE DATE ALIGNMENT (Fix for RangeError)

      Map<String, double> gldMap = { for (var e in gldData) _formatDate(e.date) : e.value };

      // Ippo overlap aagura dates-ah mattum correct-ah filter panrom

      Set<String> commonDateSet = gldMap.keys.toSet();

      for (var series in rawStockData.values) {

        var seriesDates = series.map((p) => _formatDate(p.date)).toSet();

        commonDateSet = commonDateSet.intersection(seriesDates);

      }

      List<String> sortedCommonDates = commonDateSet.toList()..sort();
      if (sortedCommonDates.length < 2) throw "Not enough overlapping data between stocks and Gold.";
      List<ChartPoint> convertedPortfolio = [];

      Map<String, List<ChartPoint>> alignedStockPrices = {};

      for (var dateStr in sortedCommonDates) {

        DateTime currentDate = DateTime.parse(dateStr);

        double totalPortfolioUSD = 0;

        double currentGoldPrice = gldMap[dateStr]!;

        for (var row in _rows) {

          String t = row.ticker.trim().toUpperCase();

          double units = double.tryParse(row.unitsController.text) ?? 0;

          if (rawStockData.containsKey(t)) {

            // Safe search for the point on that specific date

            try {

              var pricePoint = rawStockData[t]!.firstWhere((p) => _formatDate(p.date) == dateStr);

              totalPortfolioUSD += (pricePoint.value * units);

              alignedStockPrices.putIfAbsent(t, () => []).add(ChartPoint(currentDate, pricePoint.value));

            } catch (e) {

              // Date match aagala na skip panrom

              continue;

            }

          }

        }

        convertedPortfolio.add(ChartPoint(currentDate, totalPortfolioUSD / currentGoldPrice));

      }

      setState(() {

        _goldInUSD = gldData.where((p) => sortedCommonDates.contains(_formatDate(p.date))).toList();

        _stockPricesUSD = alignedStockPrices;

        _portfolioInGold = convertedPortfolio;

      });

    } catch (e) {

      setState(() => _error = e.toString());

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

                title: "Net worth in GOLD",

                description: "Convert your portfolio into GOLD units using GLD ETF price as the benchmark."

              ),

              PageCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                const Text("Holdings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

                const SizedBox(height: 16),

                ..._rows.map((row) => _buildHoldingInput(row)),

                TextButton(

                  onPressed: () => setState(() => _rows.add(GoldHoldingRow(id: DateTime.now().toString()))),

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

              if (_portfolioInGold.isNotEmpty) ...[

                const SizedBox(height: 40),

                StockPriceChart(seriesMap: _stockPricesUSD, chartTitle: "Stock Prices (USD)"),

                const SizedBox(height: 32),

                StockPriceChart(data: _goldInUSD, chartTitle: "Gold Price (GLD)", ticker: "GLD"),

                const SizedBox(height: 32),

                StockPriceChart(

                  data: _portfolioInGold,

                  chartTitle: "Portfolio in GOLD",

                  ticker: "Gold Units",

                ),

              ]

            ]),

          ),

          if (_isLoading) const LoadingOverlay(active: true),

        ],

      ),

    );

  }

  Widget _buildHoldingInput(GoldHoldingRow row) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 12),

      child: Wrap(spacing: 20, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.end, children: [

        SizedBox(width: 140, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          const Text("Ticker", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),

          TextField(onChanged: (v) => row.ticker = v.toUpperCase(), decoration: const InputDecoration(hintText: "AAPL")),

        ])),

        SizedBox(width: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          const Text("Units", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),

          TextField(controller: row.unitsController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "10")),

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

        onPressed: _handleLoadGoldView,

        style: ElevatedButton.styleFrom(

          backgroundColor: Colors.black,

          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))

        ),

        child: const Text("Load GOLD View", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

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