import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add this for date formatting
import 'dart:math' as math;
import '../models/portfolio_models.dart';
import '../models/swp_models.dart';
import '../services/yahoo_finance_service.dart';
import '../utils/data_utils.dart';

class SwpPortfolioProvider extends ChangeNotifier {
  final YahooFinanceService _service = YahooFinanceService();
  bool isLoading = false;

  List<PortfolioEntry> corpusEntries = [PortfolioEntry(id: '1', ticker: 'VOO', amount: '100000')];
  
  DateTime _startMonth = DateTime.utc(DateTime.now().year - 1, DateTime.now().month, 1);
  DateTime _endMonth = DateTime.utc(DateTime.now().year, DateTime.now().month, 1);

  WithdrawalStrategy strategyA = WithdrawalStrategy(type: WithdrawalType.fixed, amount: 1000, growthPct: 0.5);
  WithdrawalStrategy strategyB = WithdrawalStrategy(type: WithdrawalType.percent, amount: 1, growthPct: 0);

  Map<String, List<ChartPoint>> priceDataByTicker = {}; // For charts (filled with all days)
  Map<String, List<ChartPoint>> originalTradingDays = {}; // Only trading days from Yahoo Finance
  Map<String, List<ChartPoint>> swpPortfolioValueData = {};
  Map<String, List<ChartPoint>> swpWithdrawalData = {};
  List<SwpBreakdownRow> breakdownRows = [];

  DateTime get startMonth => _startMonth;
  DateTime get endMonth => _endMonth;
  set startMonth(DateTime d) { _startMonth = DateTime.utc(d.year, d.month, 1); notifyListeners(); }
  set endMonth(DateTime d) { _endMonth = DateTime.utc(d.year, d.month, 1); notifyListeners(); }

  double _getPrice(List<ChartPoint>? data, DateTime target) {
    if (data == null || data.isEmpty) return 0;
    ChartPoint last = data[0];
    for (var p in data) {
      if (p.date.isBefore(target) || p.date.isAtSameMomentAs(target)) {
        last = p;
      } else {
        break;
      }
    }
    return last.value;
  }

  double _getPriceOnOrAfter(List<ChartPoint>? data, DateTime target) {
    if (data == null || data.isEmpty) return 0;
    for (var p in data) {
      if (!p.date.isBefore(target)) {
        return p.value;
      }
    }
    return data.last.value;
  }

  DateTime? _getFirstTradingDayOnOrAfter(List<ChartPoint>? data, DateTime calendarDate) {
    if (data == null || data.isEmpty) return null;
    for (var p in data) {
      if (!p.date.isBefore(calendarDate)) {
        return p.date;
      }
    }
    return data.last.date;
  }

  List<ChartPoint> _calculateSwpLogic(WithdrawalStrategy strategy, Map<String, double> unitsByTicker, List<DateTime> months, Map<String, List<ChartPoint>> priceData, String key) {
    List<ChartPoint> valueData = [];
    List<ChartPoint> withdrawData = [];
    Map<String, double> u = Map.from(unitsByTicker);

    // FIRST: Add initial row for start of first month
    DateTime firstMonthStart = DateTime.utc(months[0].year, months[0].month, 1, 12, 0, 0);
    double initialValue = 0;
    u.forEach((ticker, units) {
      if (priceData.containsKey(ticker)) {
        initialValue += units * _getPrice(priceData[ticker], firstMonthStart);
      }
    });
    valueData.add(ChartPoint(firstMonthStart, initialValue));
    withdrawData.add(ChartPoint(firstMonthStart, 0));

    // THEN: Loop through each month for month-end values
    for (int i = 0; i < months.length; i++) {
      // Get calendar month end - same logic as React's new Date(year, month+1, 0)
      int year = months[i].year;
      int month = months[i].month;
      
      // Calculate next month for the month+1 operation
      int nextMonth = month == 12 ? 1 : month + 1;
      int nextYear = month == 12 ? year + 1 : year;
      
      // Create date as: new Date(year, nextMonth, 0) which gives last day of current month
      // In Dart: DateTime(year, nextMonth, 0) doesn't work, so we use (year, nextMonth, 1) then subtract 1 day
      DateTime firstOfNextMonth = DateTime.utc(nextYear, nextMonth, 1);
      DateTime calendarMonthEnd = firstOfNextMonth.subtract(const Duration(days: 1));
      
      double portfolioValue = 0;
      // Calculate portfolio value using filled data at calendar month-end (midnight UTC)
      u.forEach((ticker, units) {
        if (priceData.containsKey(ticker)) {
          double price = _getPrice(priceData[ticker], calendarMonthEnd);
          double tickerValue = units * price;
          portfolioValue += tickerValue;
        }
      });

      double withdrawAmount = 0;
      if (portfolioValue > 0) {
        if (strategy.type == WithdrawalType.fixed) {
          withdrawAmount = math.min(strategy.amount, portfolioValue);
        } else if (strategy.type == WithdrawalType.fixedGrowth) {
          withdrawAmount = math.min(strategy.amount * math.pow(1 + (strategy.growthPct / 100), i) as double, portfolioValue);
        } else {
          withdrawAmount = portfolioValue * (strategy.amount / 100);
        }
      }

      if (withdrawAmount > 0 && portfolioValue > 0) {
        double ratio = withdrawAmount / portfolioValue;
        u.updateAll((ticker, units) => units * (1 - ratio));
      }
      // Use calendar month end for the chart point
      valueData.add(ChartPoint(calendarMonthEnd, portfolioValue - withdrawAmount));
      withdrawData.add(ChartPoint(calendarMonthEnd, withdrawAmount));
    }
    swpWithdrawalData[key] = withdrawData;
    return valueData;
  }

  Future<void> handleSimulate() async {
    isLoading = true; 
    priceDataByTicker.clear();
    originalTradingDays.clear();
    swpPortfolioValueData.clear();
    swpWithdrawalData.clear();
    breakdownRows.clear();
    notifyListeners();

    try {
      List<DateTime> months = [];
      DateTime temp = _startMonth;
      while (!temp.isAfter(_endMonth)) { 
        months.add(temp); 
        temp = DateTime.utc(temp.year, temp.month + 1, 1); 
      }

      if (months.isEmpty) return;

      // Format dates for Yahoo Finance API
      String sDateStr = "${months.first.year}-${months.first.month.toString().padLeft(2, '0')}-01";
      DateTime lastDayDT = DateTime.utc(_endMonth.year, _endMonth.month + 1, 0);
      String eDateStr = "${lastDayDT.year}-${lastDayDT.month.toString().padLeft(2, '0')}-${lastDayDT.day.toString().padLeft(2, '0')}";

      // Fetch all tickers
      for (var e in corpusEntries) {
        final tName = e.ticker.trim().toUpperCase();
        if (tName.isNotEmpty) {
          try {
            final raw = await _service.fetchStockData(tName, startDate: sDateStr, endDate: eDateStr);
            if (raw.isNotEmpty) {
              // Store original trading days
              originalTradingDays[tName] = raw;
              
              // Fill missing dates for charting
              priceDataByTicker[tName] = DataUtils.fillMissingNavDates(raw);
            }
          } catch (err) {
            debugPrint("Ticker fetch failed for SWP: $tName");
          }
        }
      }

      if (priceDataByTicker.isEmpty) throw "No price data found for tickers.";

      Map<String, double> initialUnits = {};
      for (var e in corpusEntries) {
        final tName = e.ticker.trim().toUpperCase();
        if (priceDataByTicker.containsKey(tName)) {
          // Use calendar month start (1st at 12:00 UTC) for initial investment date
          DateTime investDate = DateTime.utc(months.first.year, months.first.month, 1, 12, 0, 0);
          double p = _getPrice(priceDataByTicker[tName], investDate);
          if (p > 0) {
            initialUnits[tName] = (double.tryParse(e.amount) ?? 0) / p;
          }
        }
      }

      if (initialUnits.isEmpty) throw "Initial portfolio value is zero.";

      // RUN CALCULATIONS
      swpPortfolioValueData['Strategy A'] = _calculateSwpLogic(strategyA, initialUnits, months, priceDataByTicker, 'Strategy A');
      swpPortfolioValueData['Strategy B'] = _calculateSwpLogic(strategyB, initialUnits, months, priceDataByTicker, 'Strategy B');


      final valA = swpPortfolioValueData['Strategy A'];
      final valB = swpPortfolioValueData['Strategy B'];
      final withA = swpWithdrawalData['Strategy A'];
      final withB = swpWithdrawalData['Strategy B'];

      if (valA != null && valB != null && withA != null && withB != null) {
        double cA = 0; double cB = 0;
        
        // Build breakdown rows from the calculated data (valA, valB have same dates)
        for (int i = 0; i < valA.length && i < valB.length; i++) {
          double wa = withA[i].value;
          double wb = withB[i].value;
          cA += wa; cB += wb;
          
          breakdownRows.add(SwpBreakdownRow(
            date: valA[i].date,  // Use the actual date from valueData (React uses the same)
            strategyAValue: valA[i].value, 
            strategyAWithdrawal: wa, 
            strategyACumulative: cA, 
            strategyBValue: valB[i].value, 
            strategyBWithdrawal: wb, 
            strategyBCumulative: cB
          ));
        }
      }
    } catch (e) {
      debugPrint("SWP SIMULATION ERROR: $e");
    } finally { 
      isLoading = false; 
      notifyListeners(); 
    }
  }

  void addCorpusRow() { 
    corpusEntries.add(PortfolioEntry(id: DateTime.now().toString(), ticker: '', amount: '')); 
    notifyListeners(); 
  }
  
  void removeCorpusRow(String id) { 
    if (corpusEntries.length > 1) { 
      corpusEntries.removeWhere((e) => e.id == id); 
      notifyListeners(); 
    } 
  }

  void updateCorpus(String id, String field, String value) {
    var index = corpusEntries.indexWhere((x) => x.id == id);
    if (index != -1) {
      if (field == 'ticker') corpusEntries[index].ticker = value.toUpperCase();
      if (field == 'amount') corpusEntries[index].amount = value;
      notifyListeners();
    }
  }
}