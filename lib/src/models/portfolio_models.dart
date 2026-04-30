class ChartPoint {
  final DateTime date;
  final double value;

  ChartPoint(this.date, this.value);

  // Gemini payload-kaga JSON conversion
  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'value': value,
  };
}

// Ippo intha class-ah add panniten. Ithu illama thaan compile aagala.
class ChartSeries {
  final String name;
  final List<ChartPoint> data;
  final int color;
  ChartSeries({required this.name, required this.data, required this.color});
}

class PortfolioEntry {
  String id;
  String ticker;
  String amount;
  PortfolioEntry({required this.id, this.ticker = '', this.amount = ''});
}

class PortfolioDef {
  final String id;
  final String name;
  List<PortfolioEntry> entries;
  PortfolioDef({required this.id, required this.name, required this.entries});
}
