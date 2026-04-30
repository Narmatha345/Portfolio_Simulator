import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/portfolio_models.dart';
import '../services/yahoo_finance_service.dart';
import '../utils/data_utils.dart';

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

  Map<String, List<ChartPoint>> priceDataByTicker = {};
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

  // Simple XIRR logic based on duration and returns for summary display
  double _calculateApproxXirr(double startVal, double endVal, int totalMonths) {
    if (startVal <= 0 || totalMonths <= 0) return 0;
    double years = totalMonths / 12.0;
    return (math.pow(endVal / startVal, 1 / years) - 1) * 100;
  }

  Future<void> handlePlot() async {
    isLoading = true;
    notifyListeners();
    try {
      priceDataByTicker.clear();
      List<DateTime> months = [];
      DateTime temp = _startMonth;
      while (!temp.isAfter(_endMonth)) {
        months.add(temp);
        temp = DateTime.utc(temp.year, temp.month + 1, 1);
      }

      String startStr = "${months.first.year}-${months.first.month.toString().padLeft(2, '0')}-01";
      DateTime lastDayDT = DateTime.utc(_endMonth.year, _endMonth.month + 1, 0);
      String endStr = "${lastDayDT.year}-${lastDayDT.month.toString().padLeft(2, '0')}-${lastDayDT.day.toString().padLeft(2, '0')}";

      for (var p in portfolios) {
        for (var e in p.entries) {
          if (e.ticker.isNotEmpty) {
            final raw = await _service.fetchStockData(e.ticker, startDate: startStr, endDate: endStr);
            if (raw.isNotEmpty) {
              priceDataByTicker[e.ticker] = DataUtils.fillMissingNavDates(raw);
            }
          }
        }
      }

      summaryA.clear(); summaryB.clear(); 
      breakdownA.clear(); breakdownB.clear();
      portfolioValueData.clear(); normalizedValueData.clear();

      for (int i = 0; i < portfolios.length; i++) {
        String pKey = (i == 0) ? 'A' : 'B';
        List<SipBreakdownRow> currentBreakdown = (i == 0) ? breakdownA : breakdownB;
        List<SipSummaryRow> currentSummary = (i == 0) ? summaryA : summaryB;
        
        Map<String, double> cumUnits = {};
        double totalCumInvested = 0;
        List<ChartPoint> valuePts = [];

        for (var mDate in months) {
          double mInvest = 0;
          DateTime mEnd = DateTime.utc(mDate.year, mDate.month + 1, 0);

          for (var e in portfolios[i].entries) {
            if (priceDataByTicker.containsKey(e.ticker)) {
              final data = priceDataByTicker[e.ticker]!;
              double buyPrice = _getPrice(data, mDate);
              double amt = double.tryParse(e.amount) ?? 0.0;
              
              if (buyPrice > 0 && amt > 0) {
                double unitsBought = amt / buyPrice;
                cumUnits[e.ticker] = (cumUnits[e.ticker] ?? 0) + unitsBought;
                mInvest += amt;
              }
            }
          }
          totalCumInvested += mInvest;
          
          double curPortVal = 0;
          cumUnits.forEach((t, u) {
            curPortVal += u * _getPrice(priceDataByTicker[t]!, mEnd);
          });
          valuePts.add(ChartPoint(mEnd, curPortVal));

          // Breakdown Row logic exactly as React
          for (var e in portfolios[i].entries) {
            if (priceDataByTicker.containsKey(e.ticker)) {
              final data = priceDataByTicker[e.ticker]!;
              double buyP = _getPrice(data, mDate);
              double sipAmt = double.tryParse(e.amount) ?? 0;
              
              currentBreakdown.add(SipBreakdownRow(
                month: "${mDate.year}-${mDate.month.toString().padLeft(2, '0')}",
                ticker: e.ticker,
                buyPrice: buyP,
                monthEndPrice: _getPrice(data, mEnd),
                sipAmount: sipAmt,
                unitsBought: buyP > 0 ? sipAmt / buyP : 0,
                accumulatedUnits: cumUnits[e.ticker] ?? 0,
                investment: mInvest, // Portfolio total investment this month
                cumulativeInvested: totalCumInvested,
                value: curPortVal, // Portfolio total value this month end
                returnPct: totalCumInvested > 0 ? ((curPortVal - totalCumInvested) / totalCumInvested) * 100 : 0,
              ));
            }
          }
        }

        // Summary Rows logic exactly as React
        for (var e in portfolios[i].entries) {
          if (cumUnits.containsKey(e.ticker)) {
            double units = cumUnits[e.ticker]!;
            double monthlyAmt = double.tryParse(e.amount) ?? 0;
            double invested = monthlyAmt * months.length;
            double lastPrice = _getPrice(priceDataByTicker[e.ticker]!, valuePts.last.date);
            double endVal = units * lastPrice;
            
            currentSummary.add(SipSummaryRow(
              ticker: e.ticker,
              invested: invested,
              units: units,
              endValue: endVal,
              returnPct: invested > 0 ? ((endVal - invested) / invested) * 100 : 0,
              xirr: _calculateApproxXirr(invested, endVal, months.length),
            ));
          }
        }

        portfolioValueData[pKey] = valuePts;
        double base = (valuePts.isNotEmpty && valuePts.first.value > 0) ? valuePts.first.value : 1.0;
        normalizedValueData[pKey] = valuePts.map((p) => ChartPoint(p.date, (p.value / base) * 100)).toList();
      }
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