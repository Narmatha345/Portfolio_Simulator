import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/portfolio_models.dart';
import '../services/yahoo_finance_service.dart';
import '../utils/data_utils.dart';

class SummaryRow {
  final String ticker;
  final double investment;
  final double units;
  final double endValue;
  final double returnPct;
  final double xirr;
  SummaryRow({
    required this.ticker, 
    required this.investment, 
    required this.units, 
    required this.endValue, 
    required this.returnPct, 
    required this.xirr
  });
}

class PortfolioProvider extends ChangeNotifier {
  final YahooFinanceService _service = YahooFinanceService();
  bool isLoading = false;

  Map<String, List<ChartPoint>> priceData = {};
  Map<String, List<ChartPoint>> normalizedSingleData = {};
  Map<String, List<ChartPoint>> portfolioValueData = {};
  Map<String, List<ChartPoint>> normalizedCompareData = {};
  List<SummaryRow> summaryA = [];
  List<SummaryRow> summaryB = [];

  // FORCE Midnight UTC for consistency
  DateTime _startDate = DateTime.utc(DateTime.now().year - 1, DateTime.now().month, DateTime.now().day);
  DateTime _endDate = DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;

  set startDate(DateTime date) { 
    _startDate = DateTime.utc(date.year, date.month, date.day); 
    notifyListeners(); 
  }
  set endDate(DateTime date) { 
    _endDate = DateTime.utc(date.year, date.month, date.day); 
    notifyListeners(); 
  }

  List<PortfolioDef> portfolios = [
    PortfolioDef(id: 'A', name: 'Portfolio A', entries: [PortfolioEntry(id: '1')]),
    PortfolioDef(id: 'B', name: 'Portfolio B', entries: [PortfolioEntry(id: '2')]),
  ];

  void updateEntry(int pIdx, String entryId, String field, String value) {
    try {
      final entry = portfolios[pIdx].entries.firstWhere((e) => e.id == entryId);
      if (field == 'ticker') entry.ticker = value.toUpperCase();
      if (field == 'amount') entry.amount = value;
      notifyListeners();
    } catch (e) { debugPrint("Entry not found: $e"); }
  }

  void addRow(int pIdx) {
    portfolios[pIdx].entries.add(PortfolioEntry(id: DateTime.now().toString()));
    notifyListeners();
  }

  void removeRow(int pIdx, String id) {
    if (portfolios[pIdx].entries.length > 1) {
      portfolios[pIdx].entries.removeWhere((e) => e.id == id);
      notifyListeners();
    }
  }

  void _calculateAnalytics() {
    summaryA.clear();
    summaryB.clear();
    normalizedSingleData.clear();
    portfolioValueData.clear();
    normalizedCompareData.clear();

    for (int i = 0; i < portfolios.length; i++) {
      String pKey = (i == 0) ? 'A' : 'B';
      List<SummaryRow> currentSummary = (i == 0) ? summaryA : summaryB;
      List<ChartPoint> combinedPortfolioValue = [];

      for (var entry in portfolios[i].entries) {
        if (priceData.containsKey(entry.ticker) && entry.amount.isNotEmpty) {
          var data = priceData[entry.ticker]!;
          if (data.isEmpty) continue;

          double investment = double.tryParse(entry.amount) ?? 0.0;
          double startPrice = data.first.value;
          double endPrice = data.last.value;
          double units = investment / startPrice;
          double currentEndValue = units * endPrice;

          // Days difference calculation using UTC dates
          double days = _endDate.difference(_startDate).inDays.toDouble();
          if (days <= 0) days = 1;
          double years = days / 365.25;
          double xirrValue = (math.pow(currentEndValue / investment, 1 / years) - 1) * 100;

          currentSummary.add(SummaryRow(
            ticker: entry.ticker,
            investment: investment,
            units: units,
            endValue: currentEndValue,
            returnPct: ((endPrice / startPrice) - 1) * 100,
            xirr: xirrValue,
          ));

          // Ensure Single Stock dates are Pure UTC
          normalizedSingleData[entry.ticker] = data.map((p) => 
            ChartPoint(DateTime.utc(p.date.year, p.date.month, p.date.day), (p.value / startPrice) * 100)
          ).toList();

          for (int d = 0; d < data.length; d++) {
            DateTime utcDate = DateTime.utc(data[d].date.year, data[d].date.month, data[d].date.day);
            double dailyVal = data[d].value * units;
            
            if (combinedPortfolioValue.length <= d) {
              combinedPortfolioValue.add(ChartPoint(utcDate, dailyVal));
            } else {
              combinedPortfolioValue[d] = ChartPoint(utcDate, combinedPortfolioValue[d].value + dailyVal);
            }
          }
        }
      }
      
      if (combinedPortfolioValue.isNotEmpty) {
        portfolioValueData[pKey] = combinedPortfolioValue;
        double pStartVal = combinedPortfolioValue.first.value;
        normalizedCompareData[pKey] = combinedPortfolioValue.map((p) => 
          ChartPoint(DateTime.utc(p.date.year, p.date.month, p.date.day), (p.value / pStartVal) * 100)
        ).toList();
      }
    }
  }

  Future<void> handlePlot() async {
    isLoading = true;
    notifyListeners();
    try {
      priceData.clear();
      String startStr = _startDate.toIso8601String().split('T')[0];
      String endStr = _endDate.toIso8601String().split('T')[0];

      for (var p in portfolios) {
        for (var e in p.entries) {
          if (e.ticker.isNotEmpty) {
            final raw = await _service.fetchStockData(e.ticker, startDate: startStr, endDate: endStr);
            if (raw.isNotEmpty) {
              // --- CRITICAL FIX: Force all point dates to Midnight UTC ---
              List<ChartPoint> filled = DataUtils.fillMissingNavDates(raw);
              priceData[e.ticker] = filled.map((pt) => 
                ChartPoint(DateTime.utc(pt.date.year, pt.date.month, pt.date.day), pt.value)
              ).toList();
            }
          }
        }
      }
      _calculateAnalytics();
    } catch (e) {
      debugPrint("Error in handlePlot: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}