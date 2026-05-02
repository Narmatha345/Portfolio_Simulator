import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/portfolio_models.dart';
import '../services/yahoo_finance_service.dart';
import '../utils/data_utils.dart';

class CashFlow {
  final DateTime date;
  final double amount;
  CashFlow({required this.date, required this.amount});
}

class SipSummaryRow {
  final String ticker;
  final double invested;
  final double units;
  final double endValue;
  final double returnPct;
  final double xirr;
  SipSummaryRow({
    required this.ticker,
    required this.invested,
    required this.units,
    required this.endValue,
    required this.returnPct,
    required this.xirr,
  });
}

class SipBreakdownRow {
  final String month;
  final String ticker;
  final double buyPrice;
  final double monthEndPrice;
  final double sipAmount;
  final double unitsBought;
  final double accumulatedUnits;
  final double investment;
  final double cumulativeInvested;
  final double value;
  final double? returnPct;

  SipBreakdownRow({
    required this.month,
    required this.ticker,
    required this.buyPrice,
    required this.monthEndPrice,
    required this.sipAmount,
    required this.unitsBought,
    required this.accumulatedUnits,
    required this.investment,
    required this.cumulativeInvested,
    required this.value,
    this.returnPct,
  });
}

class SipPortfolioProvider extends ChangeNotifier {
  final YahooFinanceService _service = YahooFinanceService();
  bool isLoading = false;

  Map<String, List<ChartPoint>> priceDataByTicker = {}; // For charts (filled with all days)
  Map<String, List<ChartPoint>> originalTradingDays = {}; // Only trading days from Yahoo Finance
  Map<String, List<ChartPoint>> portfolioValueData = {};
  Map<String, List<ChartPoint>> normalizedValueData = {};

  List<SipSummaryRow> summaryA = [];
  List<SipSummaryRow> summaryB = [];
  List<SipBreakdownRow> breakdownA = [];
  List<SipBreakdownRow> breakdownB = [];

  DateTime _startMonth = DateTime.utc(DateTime.now().year - 1, DateTime.now().month, 1);
  DateTime _endMonth = DateTime.utc(DateTime.now().year, DateTime.now().month, 1);

  DateTime get startMonth => _startMonth;
  DateTime get endMonth => _endMonth;
  set startMonth(DateTime d) { _startMonth = DateTime.utc(d.year, d.month, 1); notifyListeners(); }
  set endMonth(DateTime d) { _endMonth = DateTime.utc(d.year, d.month, 1); notifyListeners(); }

  List<PortfolioDef> portfolios = [
    PortfolioDef(id: 'A', name: 'Portfolio A', entries: [PortfolioEntry(id: '1')]),
    PortfolioDef(id: 'B', name: 'Portfolio B', entries: [PortfolioEntry(id: '2')]),
  ];

  /// Get price at or before target date (for SIP buy date)
  double _getPrice(List<ChartPoint> data, DateTime target) {
    if (data.isEmpty) return 0;
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

  /// Get price on or after target date (for month-end date that might be weekend/holiday)
  double _getPriceOnOrAfter(List<ChartPoint> data, DateTime target) {
    if (data.isEmpty) return 0;
    for (var p in data) {
      if (!p.date.isBefore(target)) {
        return p.value;
      }
    }
    return data.last.value;
  }

  /// Get first trading day on or after calendar date
  DateTime? _getFirstTradingDayOnOrAfter(List<ChartPoint> data, DateTime calendarDate) {
    if (data.isEmpty) return null;
    for (var p in data) {
      if (!p.date.isBefore(calendarDate)) {
        return p.date;
      }
    }
    return data.last.date;
  }

  /// Calculate NPV for a given rate (using fractional days from milliseconds like React)
  double _calculateNpv(List<CashFlow> cashFlows, double rate) {
    if (cashFlows.isEmpty) return 0;
    final firstDate = cashFlows.first.date;
    double npv = 0;
    const msPerDay = 86400000.0;
    
    for (var cf in cashFlows) {
      final ms = cf.date.difference(firstDate).inMilliseconds.toDouble();
      final years = ms / msPerDay / 365.0;
      final discount = math.pow(1 + rate, years) as double;
      npv += cf.amount / discount;
    }
    
    return npv;
  }

  /// Calculate NPV derivative for Newton-Raphson (using fractional days)
  double _calculateNpvDerivative(List<CashFlow> cashFlows, double rate) {
    if (cashFlows.isEmpty) return 0;
    final firstDate = cashFlows.first.date;
    double derivative = 0;
    const msPerDay = 86400000.0;
    
    for (var cf in cashFlows) {
      final ms = cf.date.difference(firstDate).inMilliseconds.toDouble();
      final years = ms / msPerDay / 365.0;
      final discount = math.pow(1 + rate, years) as double;
      derivative += -years * cf.amount / (discount * (1 + rate));
    }
    
    return derivative;
  }

  /// Calculate XIRR using Newton-Raphson method (standard XIRR algorithm)
  double? _calculateXirrFromCashFlows(List<CashFlow> cashFlows) {
    if (cashFlows.isEmpty || cashFlows.length < 2) return null;
    
    // Sort by date
    cashFlows.sort((a, b) => a.date.compareTo(b.date));
    
    // Try multiple initial guesses to find best convergence
    // Include common XIRR ranges
    List<double> guesses = [0.1, 0.15, 0.2, 0.25, 0.275, 0.3, 0.05, 0.0, -0.05];
    
    double? bestRate;
    double? bestNpv;
    
    for (double guess in guesses) {
      double rate = guess;
      
      for (int i = 0; i < 1000; i++) {
        final npv = _calculateNpv(cashFlows, rate);
        
        // Check convergence - very tight tolerance
        if (npv.abs() < 1e-14) {
          if (bestNpv == null || npv.abs() < bestNpv.abs()) {
            bestRate = rate;
            bestNpv = npv;
          }
          break;
        }
        
        final derivative = _calculateNpvDerivative(cashFlows, rate);
        
        if (derivative.abs() < 1e-10) {
          // Derivative too small, can't continue
          break;
        }
        
        final newRate = rate - (npv / derivative);
        
        // Check if converged
        if ((newRate - rate).abs() < 1e-14) {
          final finalNpv = _calculateNpv(cashFlows, newRate);
          if (bestNpv == null || finalNpv.abs() < bestNpv.abs()) {
            bestRate = newRate;
            bestNpv = finalNpv;
          }
          break;
        }
        
        rate = newRate;
        
        // Prevent runaway
        if (rate > 10 || rate < -0.99) {
          break;
        }
      }
    }
    
    return bestRate != null ? bestRate * 100 : null;
  }

  Future<void> handlePlot() async {
    isLoading = true;
    notifyListeners();
    try {
      priceDataByTicker.clear();
      originalTradingDays.clear();
      
      // Build list of all months in range
      List<DateTime> months = [];
      DateTime temp = _startMonth;
      while (!temp.isAfter(_endMonth)) {
        months.add(temp);
        temp = DateTime.utc(temp.year, temp.month + 1, 1);
      }

      if (months.isEmpty) return;

      // Calculate date range for fetching
      String startStr = "${months.first.year}-${months.first.month.toString().padLeft(2, '0')}-01";
      DateTime lastDayDT = DateTime.utc(_endMonth.year, _endMonth.month + 1, 0);
      String endStr = "${lastDayDT.year}-${lastDayDT.month.toString().padLeft(2, '0')}-${lastDayDT.day.toString().padLeft(2, '0')}";

      // Fetch all tickers
      Set<String> allTickers = {};
      for (var p in portfolios) {
        for (var e in p.entries) {
          if (e.ticker.isNotEmpty) {
            allTickers.add(e.ticker.toUpperCase());
          }
        }
      }

      for (String ticker in allTickers) {
        try {
          final raw = await _service.fetchStockData(ticker, startDate: startStr, endDate: endStr);
          if (raw.isNotEmpty) {
            // Store original trading days only
            originalTradingDays[ticker] = raw;
            
            // Fill missing dates for charting
            priceDataByTicker[ticker] = DataUtils.fillMissingNavDates(raw);
          }
        } catch (e) {
          debugPrint('Error fetching $ticker: $e');
        }
      }

      summaryA.clear(); summaryB.clear(); 
      breakdownA.clear(); breakdownB.clear();
      portfolioValueData.clear(); normalizedValueData.clear();

      // Process each portfolio
      for (int i = 0; i < portfolios.length; i++) {
        String pKey = (i == 0) ? 'A' : 'B';
        List<SipBreakdownRow> currentBreakdown = (i == 0) ? breakdownA : breakdownB;
        List<SipSummaryRow> currentSummary = (i == 0) ? summaryA : summaryB;
        
        Map<String, double> cumUnits = {};
        double totalCumInvested = 0;
        List<ChartPoint> valuePts = [];
        DateTime? firstSipDate;
        DateTime? lastSipDate;

        // Process each month
        for (var mDate in months) {
          // Month start: first trading day on or after 1st of month
          DateTime monthStart = DateTime.utc(mDate.year, mDate.month, 1);
          
          // Month end: CALENDAR month end (last day at 23:59:59)
          DateTime nextMonth = mDate.month == 12 ? DateTime.utc(mDate.year + 1, 1, 1) : DateTime.utc(mDate.year, mDate.month + 1, 1);
          DateTime calendarMonthEnd = nextMonth.subtract(Duration(days: 1));
          
          double mInvest = 0;
          DateTime actualMonthStartDate = monthStart;
          DateTime actualMonthEndDate = calendarMonthEnd; // Keep as calendar end, not trading date

          // Get actual trading dates and process each ticker
          for (var e in portfolios[i].entries) {
            if (e.ticker.isEmpty) continue;
            if (!originalTradingDays.containsKey(e.ticker)) continue;
            
            final tradingDays = originalTradingDays[e.ticker]!;
            if (tradingDays.isEmpty) continue;

            // Find first trading day on or after month start
            DateTime? tradingMonthStart = _getFirstTradingDayOnOrAfter(tradingDays, monthStart);
            if (tradingMonthStart != null && (firstSipDate == null || tradingMonthStart.isBefore(firstSipDate))) {
              firstSipDate = tradingMonthStart;
            }
            if (tradingMonthStart != null) {
              actualMonthStartDate = tradingMonthStart;
            }

            // For month end pricing, use calendar date directly (like React)
            // Don't convert to trading date - let getPriceOnOrAfter handle forward-fill
            if (lastSipDate == null || calendarMonthEnd.isAfter(lastSipDate)) {
              lastSipDate = calendarMonthEnd;
            }

            final filledData = priceDataByTicker[e.ticker]!;
            double buyPrice = _getPrice(filledData, actualMonthStartDate);
            double amt = double.tryParse(e.amount) ?? 0.0;
            
            if (buyPrice > 0 && amt > 0) {
              double unitsBought = amt / buyPrice;
              cumUnits[e.ticker] = (cumUnits[e.ticker] ?? 0) + unitsBought;
              mInvest += amt;
            }
          }
          
          totalCumInvested += mInvest;
          
          // Calculate portfolio value at month end (calendar month end at 23:59:59 like React)
          double curPortVal = 0;
          final filledEndData = priceDataByTicker;
          cumUnits.forEach((t, u) {
            if (filledEndData.containsKey(t)) {
              curPortVal += u * _getPriceOnOrAfter(filledEndData[t]!, actualMonthEndDate);
            }
          });
          // Use calendar month end at 23:59:59 UTC like React
          DateTime monthEndFull = DateTime.utc(actualMonthEndDate.year, actualMonthEndDate.month, actualMonthEndDate.day, 23, 59, 59);
          valuePts.add(ChartPoint(monthEndFull, curPortVal));

          // Build breakdown rows
          for (var e in portfolios[i].entries) {
            if (e.ticker.isEmpty) continue;
            if (!originalTradingDays.containsKey(e.ticker)) continue;
            
            final filledData = priceDataByTicker[e.ticker]!;
            if (filledData.isEmpty) continue;

            double buyP = _getPrice(filledData, actualMonthStartDate);
            double sipAmt = double.tryParse(e.amount) ?? 0;
            double monthEndPrice = _getPriceOnOrAfter(filledData, actualMonthEndDate);
            
            currentBreakdown.add(SipBreakdownRow(
              month: "${mDate.year}-${mDate.month.toString().padLeft(2, '0')}",
              ticker: e.ticker,
              buyPrice: buyP,
              monthEndPrice: monthEndPrice,
              sipAmount: sipAmt,
              unitsBought: buyP > 0 ? sipAmt / buyP : 0,
              accumulatedUnits: cumUnits[e.ticker] ?? 0,
              investment: mInvest,
              cumulativeInvested: totalCumInvested,
              value: curPortVal,
              returnPct: totalCumInvested > 0 ? ((curPortVal - totalCumInvested) / totalCumInvested) * 100 : 0,
            ));
          }
        }

        // Build portfolio-level XIRR from combined + deduplicated cash flows (exactly like React)
        Map<String, double> uniqueCashFlowsByDateStr = {}; // Keyed by YYYY-MM-DD
        double totalEndValue = 0;
        
        // Build summary rows 
        for (var e in portfolios[i].entries) {
          if (e.ticker.isEmpty) continue;
          if (!cumUnits.containsKey(e.ticker)) continue;

          double units = cumUnits[e.ticker]!;
          double monthlyAmt = double.tryParse(e.amount) ?? 0;
          double invested = monthlyAmt * months.length;
          
          double lastPrice = 0;
          if (priceDataByTicker.containsKey(e.ticker) && valuePts.isNotEmpty) {
            lastPrice = _getPriceOnOrAfter(priceDataByTicker[e.ticker]!, valuePts.last.date);
          }
          double endVal = units * lastPrice;
          totalEndValue += endVal;
          
          // Build cash flows for each ticker's investments
          for (var mDate in months) {
            // SIP date is always 1st of month at 12:00 UTC (like React)
            DateTime sipDate = DateTime.utc(mDate.year, mDate.month, 1, 12, 0, 0);
            
            if (originalTradingDays.containsKey(e.ticker)) {
              if (monthlyAmt > 0) {
                // Deduplicate by date (YYYY-MM-DD) like React does
                String dateKey = sipDate.toIso8601String().split('T')[0]; // YYYY-MM-DD
                uniqueCashFlowsByDateStr[dateKey] = 
                  (uniqueCashFlowsByDateStr[dateKey] ?? 0) - monthlyAmt;
              }
            }
          }

          currentSummary.add(SipSummaryRow(
            ticker: e.ticker,
            invested: invested,
            units: units,
            endValue: endVal,
            returnPct: invested > 0 ? ((endVal - invested) / invested) * 100 : 0,
            xirr: 0, // Will be calculated per ticker if needed
          ));
        }
        
        // Calculate portfolio XIRR from deduplicated combined cash flows (exactly like React)
        double? portfolioXirr;
        if (valuePts.isNotEmpty && uniqueCashFlowsByDateStr.isNotEmpty) {
          List<CashFlow> xirrCashFlows = [];
          
          // Add deduplicated cash flows (each date only once, with combined amount)
          for (var entry in uniqueCashFlowsByDateStr.entries) {
            DateTime date = DateTime.parse(entry.key + 'T12:00:00Z');
            xirrCashFlows.add(CashFlow(date: date, amount: entry.value));
          }
          
          // Add final portfolio value at end date
          final endDateFull = DateTime.utc(
            valuePts.last.date.year,
            valuePts.last.date.month,
            valuePts.last.date.day,
            23, 59, 59
          );
          xirrCashFlows.add(CashFlow(date: endDateFull, amount: totalEndValue));
          
          // Sort by date (like React does)
          xirrCashFlows.sort((a, b) => a.date.compareTo(b.date));
          
          if (xirrCashFlows.length >= 2) {
            portfolioXirr = _calculateXirrFromCashFlows(xirrCashFlows);
          }
        }
        
        // Store portfolio XIRR in first summary row (for display)
        if (currentSummary.isNotEmpty && portfolioXirr != null) {
          currentSummary[0] = SipSummaryRow(
            ticker: currentSummary[0].ticker,
            invested: currentSummary[0].invested,
            units: currentSummary[0].units,
            endValue: currentSummary[0].endValue,
            returnPct: currentSummary[0].returnPct,
            xirr: portfolioXirr,
          );
        }

        portfolioValueData[pKey] = valuePts;
        double base = (valuePts.isNotEmpty && valuePts.first.value > 0) ? valuePts.first.value : 1.0;
        normalizedValueData[pKey] = valuePts.map((p) => ChartPoint(p.date, (p.value / base) * 100)).toList();
      }
    } catch (e) {
      debugPrint('Error in SIP handlePlot: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void updateEntry(int pIdx, String id, String f, String v) {
    final e = portfolios[pIdx].entries.firstWhere((x) => x.id == id);
    if (f == 'ticker') e.ticker = v.toUpperCase();
    if (f == 'amount') e.amount = v;
    notifyListeners();
  }
  void addRow(int i) { portfolios[i].entries.add(PortfolioEntry(id: DateTime.now().toString())); notifyListeners(); }
  void removeRow(int i, String id) { if (portfolios[i].entries.length > 1) { portfolios[i].entries.removeWhere((x) => x.id == id); notifyListeners(); } }
}