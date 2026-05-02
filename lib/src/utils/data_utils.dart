import '../models/portfolio_models.dart';

class DataUtils {
  static List<ChartPoint> fillMissingNavDates(List<ChartPoint> data) {
    if (data.isEmpty) return [];
    final sorted = List<ChartPoint>.from(data)..sort((a, b) => a.date.compareTo(b.date));
    List<ChartPoint> filled = [];
    int i = 0;
    DateTime current = DateTime.utc(sorted[0].date.year, sorted[0].date.month, sorted[0].date.day);
    DateTime lastDate = DateTime.utc(sorted.last.date.year, sorted.last.date.month, sorted.last.date.day);
    
    while (!current.isAfter(lastDate)) {
      if (i < sorted.length && _isSameDay(current, sorted[i].date)) {
        // Exact match with trading day
        filled.add(ChartPoint(current, sorted[i].value));
        i++;
      } else if (i > 0) {
        // Gap - use the previous trading day's price (backward fill)
        filled.add(ChartPoint(current, sorted[i - 1].value));
      } else {
        // Before first trading day (shouldn't happen in normal use)
        filled.add(ChartPoint(current, sorted[i].value));
      }
      current = DateTime.utc(current.year, current.month, current.day + 1);
    }
    return filled;
  }
  
  static bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}