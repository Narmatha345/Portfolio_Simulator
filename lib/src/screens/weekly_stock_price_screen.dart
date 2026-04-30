import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide ChartPoint;
import '../models/portfolio_models.dart';
import '../services/yahoo_finance_service.dart';
import '../widgets/common_ui.dart';

class WeeklyStockPriceScreen extends StatefulWidget {
  const WeeklyStockPriceScreen({super.key});

  @override
  State<WeeklyStockPriceScreen> createState() => _WeeklyStockPriceScreenState();
}

enum ViewType { weekly, monthly }

class _WeeklyStockPriceScreenState extends State<WeeklyStockPriceScreen> {
  final YahooFinanceService _service = YahooFinanceService();
  final TextEditingController _tickerController = TextEditingController(text: 'AAPL');
  
  DateTime _startDate = DateTime.utc(2025, 04, 30);
  DateTime _endDate = DateTime.utc(2026, 03, 30);
  ViewType _viewType = ViewType.weekly;

  List<ChartPoint> _priceData = [];
  bool _isLoading = false;
  String? _error;

  // Accurate aggregation logic matching Yahoo Finance daily values
  List<Map<String, dynamic>> get _aggregatedData {
    if (_priceData.isEmpty) return [];

    Map<String, List<ChartPoint>> grouped = {};
    for (var p in _priceData) {
      String key;
      if (_viewType == ViewType.weekly) {
        int daysToSubtract = p.date.weekday - 1;
        DateTime monday = DateTime.utc(p.date.year, p.date.month, p.date.day).subtract(Duration(days: daysToSubtract));
        key = DateFormat('yyyy-MM-dd').format(monday);
      } else {
        key = DateFormat('yyyy-MM').format(p.date);
      }
      grouped.putIfAbsent(key, () => []).add(p);
    }

    List<Map<String, dynamic>> results = [];
    grouped.forEach((key, points) {
      // Direct high/low values within the grouping
      double highVal = points.map((e) => e.value).reduce((a, b) => a > b ? a : b);
      double lowVal = points.map((e) => e.value).reduce((a, b) => a < b ? a : b);
      
      results.add({
        'date': DateTime.parse(_viewType == ViewType.weekly ? key : "$key-01"),
        'high': highVal,
        'low': lowVal,
      });
    });

    results.sort((a, b) => a['date'].compareTo(b['date']));
    return results;
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _service.fetchStockData(
        _tickerController.text.trim().toUpperCase(),
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
      );
      setState(() => _priceData = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aggregated = _aggregatedData;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                Text("View ${_viewType.name} high and low prices for a stock", 
                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 20),
                
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: const Border(left: BorderSide(color: Color(0xFF007BFF), width: 4)),
                  ),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildInputLabelRow("Ticker", SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _tickerController,
                          decoration: const InputDecoration(filled: true, fillColor: Color(0xFFF9FAFB)),
                        ),
                      )),
                      _buildDatePickerRow("Start Date", _startDate, (d) => setState(() => _startDate = d)),
                      _buildDatePickerRow("End Date", _endDate, (d) => setState(() => _endDate = d)),
                      
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("View Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<ViewType>(
                                value: ViewType.weekly,
                                groupValue: _viewType,
                                onChanged: (v) => setState(() => _viewType = v!),
                                activeColor: Colors.black,
                              ),
                              const Text("Weekly"),
                              Radio<ViewType>(
                                value: ViewType.monthly,
                                groupValue: _viewType,
                                onChanged: (v) => setState(() => _viewType = v!),
                                activeColor: Colors.black,
                              ),
                              const Text("Monthly"),
                            ],
                          )
                        ],
                      ),
                      
                      ElevatedButton(
                        onPressed: _isLoading ? null : _fetchData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text("Plot", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                if (_isLoading) const Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator(color: Colors.black)),

                if (aggregated.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  PageCard(
                    child: Column(
                      children: [
                        Text("${_tickerController.text.toUpperCase()} - ${_viewType.name[0].toUpperCase()}${_viewType.name.substring(1)} High/Low", 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 500,
                          child: SfCartesianChart(
                            legend: const Legend(isVisible: true, position: LegendPosition.bottom),
                            trackballBehavior: TrackballBehavior(
                              enable: true,
                              activationMode: ActivationMode.singleTap,
                              tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
                              // SAFE FIX: Using standard tooltip settings to avoid property crashes
                              tooltipSettings: const InteractiveTooltip(
                                enable: true,
                                color: Color(0xFF1F2937),
                                textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            primaryXAxis: DateTimeAxis(
                              // KEY: Forcing the date month year format in the trackball header natively
                              dateFormat: DateFormat('dd MMM yyyy'),
                              majorGridLines: const MajorGridLines(width: 0),
                            ),
                            primaryYAxis: NumericAxis(
                              numberFormat: NumberFormat.simpleCurrency(),
                              majorGridLines: const MajorGridLines(width: 0.5, dashArray: [5, 5]),
                            ),
                            series: <CartesianSeries<Map<String, dynamic>, DateTime>>[
                              LineSeries(
                                name: 'High',
                                dataSource: aggregated,
                                xValueMapper: (d, _) => d['date'],
                                yValueMapper: (d, _) => d['high'],
                                color: Colors.red,
                                width: 2,
                                markerSettings: const MarkerSettings(isVisible: false),
                              ),
                              LineSeries(
                                name: 'Low',
                                dataSource: aggregated,
                                xValueMapper: (d, _) => d['date'],
                                yValueMapper: (d, _) => d['low'],
                                color: Colors.green,
                                width: 2,
                                markerSettings: const MarkerSettings(isVisible: false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabelRow(String label, Widget child) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(width: 12),
        child,
      ],
    );
  }

  Widget _buildDatePickerRow(String label, DateTime date, Function(DateTime) onSelect) {
    return _buildInputLabelRow(label, InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
        if (picked != null) onSelect(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4), color: Colors.white),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(DateFormat('dd-MM-yyyy').format(date)),
            const SizedBox(width: 10),
            const Icon(Icons.calendar_today, size: 16),
          ],
        ),
      ),
    ));
  }
}