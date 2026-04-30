import '../models/portfolio_models.dart';

const String usdCashTicker = 'USD:CASH';

class NetWorthLogic {
  // Holdings-ah ticker variya merge panna
  static List<Map<String, dynamic>> mergeHoldings(List<Map<String, dynamic>> raw) {
    Map<String, double> merged = {};
    for (var h in raw) {
      String t = h['ticker'].toString().toUpperCase();
      double u = double.tryParse(h['units'].toString()) ?? 0;
      merged[t] = (merged[t] ?? 0) + u;
    }
    return merged.entries.map((e) => {'ticker': e.key, 'units': e.value}).toList();
  }

  // Total Portfolio Net Worth compute panna
  static List<ChartPoint> buildNetWorthSeries(
    List<Map<String, dynamic>> holdings,
    Map<String, List<ChartPoint>> perTickerData,
    DateTime start,
    DateTime end,
  ) {
    List<ChartPoint> result = [];
    if (holdings.isEmpty) return result;

    // Common dates candidate (using the first real ticker)
    String? firstTicker = holdings.firstWhere((h) => h['ticker'] != usdCashTicker, orElse: () => {})['ticker'];
    if (firstTicker == null || !perTickerData.containsKey(firstTicker)) return result;

    for (var point in perTickerData[firstTicker]!) {
      double totalVal = 0;
      for (var h in holdings) {
        String t = h['ticker'];
        double u = h['units'];
        if (t == usdCashTicker) {
          totalVal += u;
        } else if (perTickerData.containsKey(t)) {
          var data = perTickerData[t]!;
          var match = data.firstWhere((p) => p.date.isAtSameMomentAs(point.date), orElse: () => point);
          totalVal += u * match.value;
        }
      }
      result.add(ChartPoint(point.date, totalVal));
    }
    return result;
  }
}