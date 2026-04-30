import '../models/portfolio_models.dart';

class DataUtils {
  static List<ChartPoint> fillMissingNavDates(List<ChartPoint> data) {
    if (data.isEmpty) return [];
    final sorted = List<ChartPoint>.from(data)..sort((a, b) => a.date.compareTo(b.date));
    List<ChartPoint> filled = [];
    int i = 0;
    DateTime current = sorted[0].date;
    while (!current.isAfter(sorted.last.date)) {
      if (i < sorted.length && _isSameDay(current, sorted[i].date)) {
        filled.add(ChartPoint(current, sorted[i].value));
        i++;
      } else {
        if (i > 0) filled.add(ChartPoint(current, sorted[i-1].value)); 
        else filled.add(ChartPoint(current, sorted[i].value));
      }
      current = current.add(const Duration(days: 1));
    }
    return filled;
  }
  static bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}