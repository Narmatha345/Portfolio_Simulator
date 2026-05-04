import 'portfolio_models.dart';

enum WithdrawalType { fixed, fixedGrowth, percent }

class WithdrawalStrategy {
  WithdrawalType type;
  double amount;    
  double growthPct; 

  WithdrawalStrategy({
    required this.type,
    required this.amount,
    required this.growthPct,
  });
}

class SwpBreakdownRow {
  final DateTime date;
  final double strategyAValue;
  final double strategyAWithdrawal;
  final double strategyACumulative;
  final double strategyBValue;
  final double strategyBWithdrawal;
  final double strategyBCumulative;

  SwpBreakdownRow({
    required this.date,
    required this.strategyAValue,
    required this.strategyAWithdrawal,
    required this.strategyACumulative,
    required this.strategyBValue,
    required this.strategyBWithdrawal,
    required this.strategyBCumulative,
  });
}

class SwpMonthPriceRow {
  final DateTime month;
  final Map<String, double> prices; // ticker -> price
  final Map<String, DateTime> tradingDates; // ticker -> actual trading date used

  SwpMonthPriceRow({
    required this.month,
    required this.prices,
    required this.tradingDates,
  });
}