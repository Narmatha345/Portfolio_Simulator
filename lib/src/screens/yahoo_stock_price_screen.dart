import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide ChartPoint;
import 'package:universal_html/html.dart' as html; 
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // Mobile download fix
import '../models/portfolio_models.dart';
import '../services/yahoo_finance_service.dart';
import '../widgets/common_ui.dart';

class YahooStockPriceScreen extends StatefulWidget {
  const YahooStockPriceScreen({super.key});

  @override
  State<YahooStockPriceScreen> createState() => _YahooStockPriceScreenState();
}

class _YahooStockPriceScreenState extends State<YahooStockPriceScreen> {
  final YahooFinanceService _service = YahooFinanceService();
  final TextEditingController _tickerController = TextEditingController(text: 'AAPL');

  DateTime _startDate = DateTime.utc(2025, 04, 30);
  DateTime _endDate = DateTime.utc(2026, 04, 30);

  List<ChartPoint> _priceData = [];
  bool _isLoading = false;
  String? _error;

  // --- CSV Download & Share Logic ---
  Future<void> _downloadCSV() async {
    if (_priceData.isEmpty) return;
    String ticker = _tickerController.text.toUpperCase();
    String csv = 'Date,Adj Close\n';
    
    for (var p in _priceData) {
      csv += '${DateFormat('yyyy-MM-dd').format(p.date)},${p.value.toStringAsFixed(2)}\n';
    }

    if (kIsWeb) {
      final bytes = html.Blob([csv], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(bytes);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "${ticker}_prices.csv")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      try {
        final directory = await getTemporaryDirectory(); 
        final filePath = '${directory.path}/${ticker}_prices.csv';
        final file = File(filePath);
        await file.writeAsString(csv);
        
        await Share.shareXFiles([XFile(filePath)], text: '$ticker Stock Prices CSV');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to process file")),
          );
        }
      }
    }
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _service.fetchStockData(
        _tickerController.text.trim().toUpperCase(),
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
      );
      data.sort((a, b) => a.date.compareTo(b.date));
      setState(() => _priceData = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat("#,##0.00");

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Yahoo stock prices", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 35),
                PageCard(
                  child: Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      _buildInputCol("Ticker", TextField(
                        controller: _tickerController,
                        decoration: const InputDecoration(filled: true, fillColor: Color(0xFFF1F5F9)),
                      )),
                      _buildDatePickerCol("Start date", _startDate, (d) => setState(() => _startDate = d)),
                      _buildDatePickerCol("End date", _endDate, (d) => setState(() => _endDate = d)),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _fetchData,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20)),
                        child: const Text("Fetch", style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: _priceData.isEmpty ? null : _downloadCSV,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20)),
                        child: const Text("Download CSV"),
                      ),
                    ],
                  ),
                ),
                if (_isLoading) const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator())),
                if (_priceData.isNotEmpty) ...[
                  const SizedBox(height: 35),
                  _buildChart(),
                  const SizedBox(height: 35),
                  _buildTable(f),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    return PageCard(
      child: Column(
        children: [
          Text("${_tickerController.text.toUpperCase()} - Price", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 400,
            child: SfCartesianChart(
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
                // FIX: Forcing Day, Month, and Year format natively in the trackball tooltip
                dateFormat: DateFormat('dd MMM yyyy'),
                majorGridLines: const MajorGridLines(width: 0),
              ),
              primaryYAxis: NumericAxis(
                numberFormat: NumberFormat.simpleCurrency(decimalDigits: 2),
              ),
              series: <CartesianSeries<ChartPoint, DateTime>>[
                LineSeries<ChartPoint, DateTime>(
                  dataSource: _priceData,
                  xValueMapper: (p, _) => p.date,
                  yValueMapper: (p, _) => p.value,
                  color: const Color(0xFF007BFF),
                  width: 2.5,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(NumberFormat f) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFF1F5F9)), borderRadius: BorderRadius.circular(8)),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        columns: const [DataColumn(label: Text("Date")), DataColumn(label: Text("Adj Close"))],
        rows: _priceData.map((p) => DataRow(cells: [
          DataCell(Text(DateFormat('dd-MM-yyyy').format(p.date))),
          DataCell(Text(f.format(p.value))),
        ])).toList(),
      ),
    );
  }

  Widget _buildInputCol(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    const SizedBox(height: 8),
    SizedBox(width: 150, child: child),
  ]);

  Widget _buildDatePickerCol(String label, DateTime date, Function(DateTime) onSelect) => _buildInputCol(label, InkWell(
    onTap: () async {
      DateTime? picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
      if (picked != null) onSelect(picked);
    },
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Text(DateFormat('dd-MM-yyyy').format(date)), const SizedBox(width: 8), const Icon(Icons.calendar_today, size: 16)]),
    ),
  ));
}