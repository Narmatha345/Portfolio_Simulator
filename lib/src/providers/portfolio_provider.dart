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

class SyntheticTickerData {
  final double rate;
  SyntheticTickerData({required this.rate});
}

class PortfolioProvider extends ChangeNotifier {
  final YahooFinanceService _service = YahooFinanceService();
  bool isLoading = false;

  Map<String, List<ChartPoint>> priceData = {};
  Map<String, List<ChartPoint>> normalizedSingleData = {};
  Map<String, List<ChartPoint>> portfolioValueData = {};
  Map<String, List<ChartPoint>> normalizedCompareData = {};
  Map<String, List<ChartPoint>> originalTradingDays = {}; // Trading days only (from Yahoo Finance)
  List<SummaryRow> summaryA = [];
  List<SummaryRow> summaryB = [];
  double totalXirrA = 0;
  double totalXirrB = 0;

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

  /// Adjust end date to last day of month if it's invalid
  /// For example: Apr 31 → Apr 30, Jun 31 → Jun 30
  DateTime _adjustEndDateToMonthEnd(DateTime date) {
    // Try to create a date for the first day of next month, then subtract 1 day
    final nextMonth = date.month == 12 
        ? DateTime(date.year + 1, 1, 1)
        : DateTime(date.year, date.month + 1, 1);
    final lastDayOfMonth = nextMonth.subtract(Duration(days: 1));
    
    // If the selected date is after the last day of that month, use last day
    if (date.day > lastDayOfMonth.day) {
      return DateTime(date.year, date.month, lastDayOfMonth.day);
    }
    return date;
  }

  /// Format DateTime to YYYY-MM-DD string
  String _dateToString(DateTime date) {
    return date.toIso8601String().split('T')[0];
  }

  /// Parse synthetic ticker: ~12 = 12% XIRR, ~12.5 = 12.5%, ~TARGET_RATE = 12%.
  SyntheticTickerData? _parseSyntheticTicker(String ticker) {
    final t = ticker.trim().toUpperCase();
    if (!t.startsWith('~')) return null;
    
    if (t == '~TARGET_RATE') return SyntheticTickerData(rate: 0.12);
    
    final match = RegExp(r'^~TARGET_RATE:(\d+(?:\.\d+)?)$').firstMatch(t);
    if (match != null) {
      final rate = double.tryParse(match.group(1)!) ?? 0.12;
      return SyntheticTickerData(rate: rate / 100);
    }
    
    final numMatch = RegExp(r'^~(\d+(?:\.\d+)?)$').firstMatch(t);
    if (numMatch != null) {
      final rate = double.tryParse(numMatch.group(1)!) ?? 0;
      return SyntheticTickerData(rate: rate / 100);
    }
    
    return null;
  }

  /// Generate synthetic price data that grows at fixed XIRR.
  /// Start price = 1, so units = amount. Each day: price = (1+r)^(days/365.25).
  List<ChartPoint> _generateSyntheticPriceData(String startDateStr, String endDateStr, double xirrRate) {
    final start = DateTime.parse('${startDateStr}T00:00:00Z');
    final end = DateTime.parse('${endDateStr}T23:59:59Z');
    final result = <ChartPoint>[];

    final d = DateTime.utc(start.year, start.month, start.day);
    final endUtc = DateTime.utc(end.year, end.month, end.day).add(Duration(days: 1));
    
    DateTime current = d;
    while (current.isBefore(endUtc)) {
      final daysSinceStart = current.difference(d).inDays.toDouble();
      final years = daysSinceStart / 365.25;
      final nav = math.pow(1 + xirrRate, years) as double;
      result.add(ChartPoint(current, nav));
      current = current.add(Duration(days: 1));
    }

    return result;
  }

  /// Simple annualized return calculation
  /// Uses fractional days like React (milliseconds / msPerDay) instead of integer days
  double? _calculateXirr(DateTime investDate, double investAmount, DateTime endDate, double endValue) {
    if (investAmount <= 0) return null;
    if (endDate.isBefore(investDate)) return null;

    try {
      const msPerDay = 86400000.0;
      final ms = endDate.difference(investDate).inMilliseconds.toDouble();
      final days = ms / msPerDay;
      
      if (days <= 0) return null;
      final years = days / 365;

      if (endValue == 0) return -1;

      final ratio = endValue / investAmount;
      if (!ratio.isFinite || ratio < 0) return null;

      final annual = (math.pow(ratio, 1 / years) - 1) as double;
      if (!annual.isFinite || annual.isNaN) return null;
      
      return annual;
    } catch (e) {
      debugPrint('calculateXirr error: $e');
      return null;
    }
  }

  /// Safe wrapper for XIRR calculation with fallbacks
  double? _safeCalculateXirr(
    DateTime? investDate,
    double investAmount,
    DateTime? endDate,
    double endValue, {
    String portfolioName = '',
    String ticker = '',
  }) {
    if (investDate == null || endDate == null) {
      debugPrint('safeCalculateXirr: missing dates for $ticker in $portfolioName');
      return null;
    }
    if (investAmount <= 0) {
      debugPrint('safeCalculateXirr: non-positive investAmount for $ticker in $portfolioName');
      return null;
    }

    final result = _calculateXirr(investDate, investAmount, endDate, endValue);
    if (result != null && result.isFinite) {
      return result;
    }

    // Fallback: simple annualized return with fractional days
    try {
      const msPerDay = 86400000.0;
      final ms = endDate.difference(investDate).inMilliseconds.toDouble();
      final days = ms / msPerDay;
      
      if (days > 0 && endValue > 0 && investAmount > 0) {
        final years = days / 365;
        final ratio = endValue / investAmount;
        if (ratio > 0) {
          final fallback = (math.pow(ratio, 1 / years) - 1) as double;
          debugPrint('safeCalculateXirr: using fallback for $ticker in $portfolioName: ${fallback * 100}%');
          return fallback;
        }
      }
    } catch (e) {
      debugPrint('safeCalculateXirr: fallback error: $e');
    }

    return null;
  }

  /// Get price at a specific date (forward fill if exact date not available)
  double _getPriceAtDate(List<ChartPoint> data, DateTime targetDate) {
    double last = data.first.value;
    for (final p in data) {
      if (p.date.isBefore(targetDate) || p.date.isAtSameMomentAs(targetDate)) {
        last = p.value;
      } else {
        break;
      }
    }
    return last;
  }

  /// Compute portfolio value over time by combining multiple stocks
  List<ChartPoint> _computePortfolioValueOverTime(
    List<MapEntry<String, double>> tickersAndUnits,
  ) {
    final allDates = <DateTime>{};
    
    for (final entry in tickersAndUnits) {
      final data = priceData[entry.key];
      if (data != null) {
        for (final d in data) {
          allDates.add(d.date);
        }
      }
    }

    final sortedDates = allDates.toList()..sort();
    
    return sortedDates.map((date) {
      double value = 0;
      for (final entry in tickersAndUnits) {
        final data = priceData[entry.key];
        if (data != null && data.isNotEmpty) {
          final price = _getPriceAtDate(data, date);
          value += entry.value * price;
        }
      }
      return ChartPoint(date, value);
    }).toList();
  }

  void _calculateAnalytics() {
    summaryA.clear();
    summaryB.clear();
    normalizedSingleData.clear();
    portfolioValueData.clear();
    normalizedCompareData.clear();
    totalXirrA = 0;
    totalXirrB = 0;

    for (int i = 0; i < portfolios.length; i++) {
      String pKey = (i == 0) ? 'A' : 'B';
      List<SummaryRow> currentSummary = (i == 0) ? summaryA : summaryB;
      
      double totalInvestment = 0;
      double totalEndValue = 0;
      final tickersAndUnits = <MapEntry<String, double>>[];

      for (var entry in portfolios[i].entries) {
        if (entry.ticker.isEmpty || entry.amount.isEmpty) continue;

        final investAmount = double.tryParse(entry.amount) ?? 0;
        if (investAmount <= 0) continue;

        final data = priceData[entry.ticker];
        if (data == null || data.isEmpty) continue;

        final startPrice = data.first.value;
        final endPrice = data.last.value;
        final units = investAmount / startPrice;
        final endValue = units * endPrice;

        // Calculate return% same way as React: (endValue - investment) / investment * 100
        final returnPct = ((endValue - investAmount) / investAmount) * 100;

        currentSummary.add(SummaryRow(
          ticker: entry.ticker,
          investment: investAmount,
          units: units,
          endValue: endValue,
          returnPct: returnPct,
          xirr: 0, // Will be updated below
        ));

        totalInvestment += investAmount;
        totalEndValue += endValue;
        tickersAndUnits.add(MapEntry(entry.ticker, units));

        // Normalized single stock data
        normalizedSingleData[entry.ticker] = data.map((p) => 
          ChartPoint(p.date, (p.value / startPrice) * 100)
        ).toList();
      }

      // Portfolio value over time
      if (tickersAndUnits.isNotEmpty) {
        final portfolioValueSeries = _computePortfolioValueOverTime(tickersAndUnits);
        if (portfolioValueSeries.isNotEmpty) {
          portfolioValueData[pKey] = portfolioValueSeries;
          
          final pStartVal = portfolioValueSeries.first.value;
          normalizedCompareData[pKey] = portfolioValueSeries.map((p) => 
            ChartPoint(p.date, (p.value / pStartVal) * 100)
          ).toList();
        }
      }

      // Use actual data dates (first and last from portfolio value data), not input dates!
      DateTime? investDate;
      DateTime? endDate;
      
      if (portfolioValueData.containsKey(pKey)) {
        final pvData = portfolioValueData[pKey]!;
        if (pvData.isNotEmpty) {
          investDate = pvData.first.date;
          endDate = pvData.last.date;
        }
      }

      // Calculate XIRR for each stock using actual data dates
      for (int j = 0; j < currentSummary.length; j++) {
        final s = currentSummary[j];
        final xirrVal = _safeCalculateXirr(
          investDate,
          s.investment,
          endDate,
          s.endValue,
          portfolioName: portfolios[i].name,
          ticker: s.ticker,
        );
        
        currentSummary[j] = SummaryRow(
          ticker: s.ticker,
          investment: s.investment,
          units: s.units,
          endValue: s.endValue,
          returnPct: s.returnPct,
          xirr: (xirrVal ?? 0) * 100,
        );
      }

      // Calculate total XIRR for portfolio using actual data dates
      if (totalInvestment > 0 && totalEndValue > 0 && investDate != null && endDate != null) {
        final totalXirrVal = _safeCalculateXirr(
          investDate,
          totalInvestment,
          endDate,
          totalEndValue,
          portfolioName: portfolios[i].name,
        );
        if (i == 0) {
          totalXirrA = (totalXirrVal ?? 0) * 100;
        } else {
          totalXirrB = (totalXirrVal ?? 0) * 100;
        }
      }
    }
  }

  Future<void> handlePlot() async {
    if (_startDate.isAfter(_endDate)) {
      debugPrint('Invalid date range');
      return;
    }

    isLoading = true;
    notifyListeners();
    try {
      priceData.clear();
      originalTradingDays.clear();
      
      // Adjust end date to month end if it's invalid (e.g., Apr 31 → Apr 30)
      final adjustedEndDate = _adjustEndDateToMonthEnd(_endDate);
      
      // Format dates for Yahoo Finance API
      final startStr = _dateToString(_startDate);
      final endStr = _dateToString(adjustedEndDate);

      final allTickers = <String>{};
      for (var p in portfolios) {
        for (var e in p.entries) {
          if (e.ticker.isNotEmpty) {
            allTickers.add(e.ticker.toUpperCase());
          }
        }
      }

      // Fetch real tickers
      final realTickers = allTickers.where((t) => _parseSyntheticTicker(t) == null).toList();
      for (final ticker in realTickers) {
        try {
          final raw = await _service.fetchStockData(ticker, startDate: startStr, endDate: endStr);
          if (raw.isNotEmpty) {
            // Filter to requested date range
            final filtered = raw
              .where((pt) => !pt.date.isBefore(_startDate) && !pt.date.isAfter(adjustedEndDate))
              .map((pt) => ChartPoint(DateTime.utc(pt.date.year, pt.date.month, pt.date.day), pt.value))
              .toList();
            
            // Store original trading days (for month start/end determination)
            originalTradingDays[ticker] = filtered;
            
            // Fill missing dates for charting
            priceData[ticker] = DataUtils.fillMissingNavDates(filtered);
          }
        } catch (e) {
          debugPrint('Error fetching $ticker: $e');
        }
      }

      // Generate synthetic tickers
      for (final ticker in allTickers) {
        final parsed = _parseSyntheticTicker(ticker);
        if (parsed != null) {
          final data = _generateSyntheticPriceData(startStr, endStr, parsed.rate);
          priceData[ticker] = data;
          originalTradingDays[ticker] = data; // Synthetic data is all trading days
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