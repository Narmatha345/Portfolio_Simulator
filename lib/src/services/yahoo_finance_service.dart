import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/portfolio_models.dart';

class YahooFinanceService {
  Future<List<ChartPoint>> fetchStockData(String symbol, {String? startDate, String? endDate}) async {
    // 1. Force parsing to UTC to ensure clean start/end points
    final startDT = DateTime.parse(startDate!).toUtc();
    final endDT = DateTime.parse(endDate!).toUtc();

    final p1 = startDT.millisecondsSinceEpoch ~/ 1000;
    // Cover the full last day
    final p2 = endDT.add(const Duration(hours: 23, minutes: 59)).millisecondsSinceEpoch ~/ 1000;
    
    final yahooUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&period1=$p1&period2=$p2';
    final proxyUrl = 'https://cors-proxy-lake-omega.vercel.app/api/proxy?url=${Uri.encodeComponent(yahooUrl)}';
    
    final response = await http.get(Uri.parse(proxyUrl));
    if (response.statusCode != 200) throw Exception('Ticker $symbol not found');

    final data = json.decode(response.body);
    final chartResult = data['chart']['result']?[0];
    if (chartResult == null) return [];

    final List timestamps = chartResult['timestamp'] ?? [];
    final List adjClose = chartResult['indicators']['adjclose'][0]['adjclose'] ?? [];
    final List highPrices = chartResult['indicators']['quote'][0]['high'] ?? [];
    final List lowPrices = chartResult['indicators']['quote'][0]['low'] ?? [];

    List<ChartPoint> points = [];
    for (int i = 0; i < timestamps.length; i++) {
      if (adjClose[i] != null) {
        // 2. CRITICAL FIX: Convert Yahoo timestamp to UTC DateTime
        final DateTime rawDate = DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000, isUtc: true);

        // 3. FORCE ALIGNMENT: Strip hours/mins/secs and lock to pure Midnight UTC
        // Idhu thaan Saturday night-ah Saturday morning-ney vechirukkum (Shift aagaathu)
        final DateTime syncDate = DateTime.utc(rawDate.year, rawDate.month, rawDate.day);

        points.add(ChartPoint(
          syncDate,
          (adjClose[i] as num).toDouble(),
          high: highPrices[i] != null ? (highPrices[i] as num).toDouble() : null,
          low: lowPrices[i] != null ? (lowPrices[i] as num).toDouble() : null,
        ));
      }
    }
    return points;
  }
}