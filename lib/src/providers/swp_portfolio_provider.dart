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

  List<ChartPoint> _calculateSwpLogic(WithdrawalStrategy strategy, Map<String, double> unitsByTicker, List<DateTime> months, Map<String, List<ChartPoint>> priceData, String key) {
    List<ChartPoint> valueData = [];
    List<ChartPoint> withdrawData = [];
    Map<String, double> u = Map.from(unitsByTicker);

    for (int i = 0; i < months.length; i++) {
      DateTime mEnd = DateTime.utc(months[i].year, months[i].month + 1, 0);
      double portfolioValue = 0;
      
      u.forEach((ticker, units) {
        if (priceData.containsKey(ticker)) {
          portfolioValue += units * _getPrice(priceData[ticker], mEnd);
        }
      });

      double withdrawAmount = 0;
      if (portfolioValue > 0) {
        if (strategy.type == WithdrawalType.fixed) {
          withdrawAmount = math.min(strategy.amount, portfolioValue);
        } else if (strategy.type == WithdrawalType.fixedGrowth) {
          withdrawAmount = math.min(strategy.amount * math.pow(1 + (strategy.growthPct / 100), i), portfolioValue);
        } else {
          withdrawAmount = portfolioValue * (strategy.amount / 100);
        }
      }

      if (withdrawAmount > 0 && portfolioValue > 0) {
        double ratio = withdrawAmount / portfolioValue;
        u.updateAll((ticker, units) => units * (1 - ratio));
      }
      valueData.add(ChartPoint(mEnd, portfolioValue - withdrawAmount));
      withdrawData.add(ChartPoint(mEnd, withdrawAmount));
    }
    swpWithdrawalData[key] = withdrawData;
    return valueData;
  }

  Future<void> handleSimulate() async {
    isLoading = true; 
    swpPortfolioValueData.clear();
    swpWithdrawalData.clear();
    breakdownRows.clear();
    notifyListeners();

    try {
      Map<String, List<ChartPoint>> priceData = {};
      List<DateTime> months = [];
      DateTime temp = _startMonth;
      while (!temp.isAfter(_endMonth)) { 
        months.add(temp); 
        temp = DateTime.utc(temp.year, temp.month + 1, 1); 
      }

      // CRITICAL FIX: Generate date strings for Service
      final String sDateStr = DateFormat('yyyy-MM-01').format(_startMonth);
      final String eDateStr = DateFormat('yyyy-MM-dd').format(
          DateTime.utc(_endMonth.year, _endMonth.month + 1, 0)
      );

      for (var e in corpusEntries) {
        final tName = e.ticker.trim().toUpperCase();
        if (tName.isNotEmpty) {
          try {
            // FIX: Passing required startDate and endDate to service
            final raw = await _service.fetchStockData(
              tName, 
              startDate: sDateStr, 
              endDate: eDateStr
            );
            if (raw.isNotEmpty) {
              priceData[tName] = DataUtils.fillMissingNavDates(raw);
            }
          } catch (err) {
            debugPrint("Ticker fetch failed for SWP: $tName");
          }
        }
      }

      if (priceData.isEmpty) throw "No price data found for tickers.";

      Map<String, double> initialUnits = {};
      for (var e in corpusEntries) {
        final tName = e.ticker.trim().toUpperCase();
        if (priceData.containsKey(tName)) {
          double p = _getPrice(priceData[tName], months.first);
          if (p > 0) {
            initialUnits[tName] = (double.tryParse(e.amount) ?? 0) / p;
          }
        }
      }

      if (initialUnits.isEmpty) throw "Initial portfolio value is zero.";

      // RUN CALCULATIONS
      swpPortfolioValueData['Strategy A'] = _calculateSwpLogic(strategyA, initialUnits, months, priceData, 'Strategy A');
      swpPortfolioValueData['Strategy B'] = _calculateSwpLogic(strategyB, initialUnits, months, priceData, 'Strategy B');

      final valA = swpPortfolioValueData['Strategy A'];
      final valB = swpPortfolioValueData['Strategy B'];
      final withA = swpWithdrawalData['Strategy A'];
      final withB = swpWithdrawalData['Strategy B'];

      if (valA != null && valB != null && withA != null && withB != null) {
        double cA = 0; double cB = 0;
        for (int i = 0; i < months.length; i++) {
          if (i < valA.length && i < valB.length) {
            double wa = withA[i].value;
            double wb = withB[i].value;
            cA += wa; cB += wb;
            breakdownRows.add(SwpBreakdownRow(
              date: months[i], 
              strategyAValue: valA[i].value, 
              strategyAWithdrawal: wa, 
              strategyACumulative: cA, 
              strategyBValue: valB[i].value, 
              strategyBWithdrawal: wb, 
              strategyBCumulative: cB
            ));
          }
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