import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/portfolio_provider.dart';
import '../widgets/common_ui.dart';
import '../models/portfolio_models.dart';

class StockPriceScreen extends StatelessWidget {
  const StockPriceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PortfolioProvider>(context);
    const double maxBodyWidth = 1100.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxBodyWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Lumpsum portfolio simulator", 
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Color(0xFF111827))),
                      const SizedBox(height: 12),
                      const Text("Build and compare two portfolios (A and B). Add tickers and dollar amounts. Interaction shows detailed values on hover.", 
                        style: TextStyle(fontSize: 15, color: Color(0xFF6B7280), height: 1.5)),
                      
                      const SizedBox(height: 35),

                      PageCard(
                        child: Column(
                          children: [
                            LayoutBuilder(builder: (context, constraints) {
                              bool isMobile = constraints.maxWidth < 700;
                              return Flex(
                                direction: isMobile ? Axis.vertical : Axis.horizontal,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: isMobile ? 0 : 1, child: _buildPortfolioSection(provider, 0, const Color(0xFF6366F1))),
                                  const SizedBox(width: 24, height: 24),
                                  Expanded(flex: isMobile ? 0 : 1, child: _buildPortfolioSection(provider, 1, const Color(0xFFEC4899))),
                                ],
                              );
                            }),
                            
                            const SizedBox(height: 30),
                            _buildDateSelectorRow(context, provider),
                          ],
                        ),
                      ),

                      if (provider.isLoading) 
                        const Padding(
                          padding: EdgeInsets.only(top: 100),
                          child: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
                        ),

                      if (!provider.isLoading && provider.priceData.isNotEmpty) ...[
                        const SizedBox(height: 40),
                        
                        _buildDataRangeInfo(provider),
                        const SizedBox(height: 30),
                        
                        _buildSummaryTable("Portfolio A", provider.summaryA, totalXirr: provider.totalXirrA),
                        _buildSummaryTable("Portfolio B", provider.summaryB, totalXirr: provider.totalXirrB),

                        const SizedBox(height: 40),

                        _buildProfessionalChart(
                          title: "Portfolio Value (Compare)",
                          data: provider.portfolioValueData,
                          isCurrency: true,
                          isCompare: true,
                        ),

                        _buildProfessionalChart(
                          title: "Portfolio - Normalized (Base = 100) - Compare",
                          data: provider.normalizedCompareData,
                          isCurrency: false,
                          isCompare: true,
                        ),

                        _buildProfessionalChart(
                          title: "Portfolio - Price",
                          data: provider.priceData,
                          isCurrency: true,
                          isCompare: false,
                        ),

                        _buildProfessionalChart(
                          title: "Portfolio - Normalized (Base = 100)",
                          data: provider.normalizedSingleData,
                          isCurrency: false,
                          isCompare: false,
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalChart({
    required String title, 
    required Map<String, List<ChartPoint>> data, 
    required bool isCurrency,
    required bool isCompare
  }) {
    final colors = [const Color(0xFF6366F1), const Color(0xFFEC4899), Colors.teal, Colors.orange];
    int colorIdx = 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      child: PageCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 35),
            SizedBox(
              height: 400,
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: const Color(0xFF1F2937),
                      tooltipRoundedRadius: 6,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt(), isUtc: true);
                          final dateStr = DateFormat('d MMM yyyy').format(date);
                          String seriesName = isCompare 
                              ? (spot.barIndex == 0 ? "Portfolio A" : "Portfolio B")
                              : data.keys.elementAt(spot.barIndex);

                          return LineTooltipItem(
                            '$dateStr\n',
                            const TextStyle(color: Colors.white70, fontSize: 11),
                            children: [
                              TextSpan(
                                text: '$seriesName: ${isCurrency ? "\$" : ""}${spot.y.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (val, _) {
                          final date = DateTime.fromMillisecondsSinceEpoch(val.toInt(), isUtc: true);
                          return Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Text(DateFormat('MMM yy').format(date), style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
                  lineBarsData: data.entries.map((e) {
                    return LineChartBarData(
                      spots: e.value.map((p) => FlSpot(p.date.millisecondsSinceEpoch.toDouble(), p.value)).toList(),
                      isCurved: true,
                      color: colors[colorIdx++ % colors.length],
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelectorRow(BuildContext context, PortfolioProvider provider) {
    final isDateRangeInvalid = provider.startDate.isAfter(provider.endDate);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16, runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildDatePickerField(context, "Start date", provider.startDate, (d) => provider.startDate = d),
            _buildDatePickerField(context, "End date", provider.endDate, (d) => provider.endDate = d),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
              onPressed: (provider.isLoading || isDateRangeInvalid) ? null : provider.handlePlot, 
              child: Text(provider.isLoading ? "Loading..." : "Plot", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (isDateRangeInvalid)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              "Start date must be before end date",
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _buildDatePickerField(BuildContext context, String label, DateTime date, Function(DateTime) onSelect) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        InkWell(
          onTap: () async {
            DateTime? picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
            if (picked != null) onSelect(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(4), color: Colors.white),
            child: Row(children: [Text(DateFormat('dd-MM-yyyy').format(date)), const SizedBox(width: 10), const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.black)]),
          ),
        ),
      ],
    );
  }

  Widget _buildDataRangeInfo(PortfolioProvider provider) {
    if (provider.originalTradingDays.isEmpty) return const SizedBox.shrink();
    
    // For each ticker, get its monthly breakdown using ONLY trading days
    final tickerMonthlyData = <String, List<({int year, int month, DateTime startDate, double startPrice, DateTime endDate, double endPrice})>>{};

    for (final entry in provider.originalTradingDays.entries) {
      final ticker = entry.key;
      final tradingDays = entry.value; // Only actual trading days, no weekends/holidays
      
      if (tradingDays.isEmpty) continue;

      // Sort trading days
      tradingDays.sort((a, b) => a.date.compareTo(b.date));

      // Group trading days by month
      final monthMap = <(int, int), List<ChartPoint>>{};
      for (final point in tradingDays) {
        final key = (point.date.year, point.date.month);
        if (!monthMap.containsKey(key)) {
          monthMap[key] = [];
        }
        monthMap[key]!.add(point);
      }

      // Sort months
      final sortedMonths = monthMap.keys.toList()
        ..sort((a, b) {
          if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
          return a.$2.compareTo(b.$2);
        });

      final monthlyList = <({int year, int month, DateTime startDate, double startPrice, DateTime endDate, double endPrice})>[];
      
      for (int i = 0; i < sortedMonths.length; i++) {
        final key = sortedMonths[i];
        final points = monthMap[key]!;
        
        // First trading day on or after calendar month start
        final calendarMonthStart = DateTime(key.$1, key.$2, 1);
        late ChartPoint startPoint;
        
        // Look in current month first
        var pointsOnOrAfterStart = points.where((p) => !p.date.isBefore(calendarMonthStart)).toList();
        if (pointsOnOrAfterStart.isNotEmpty) {
          startPoint = pointsOnOrAfterStart.first;
        } else {
          // If no trading day on or after month start, use first point of month
          startPoint = points.first;
        }
        
        // Last trading day on or after calendar month end
        final nextMonth = key.$2 == 12 ? (key.$1 + 1, 1) : (key.$1, key.$2 + 1);
        final calendarMonthEnd = DateTime(nextMonth.$1, nextMonth.$2, 1).subtract(Duration(days: 1));
        late ChartPoint endPoint;
        
        // Look for trading day on or after month end date
        final nextMonthData = i + 1 < sortedMonths.length ? monthMap[sortedMonths[i + 1]] : null;
        final allFollowingDays = [...points];
        if (nextMonthData != null) allFollowingDays.addAll(nextMonthData);
        
        var pointsOnOrAfterEnd = allFollowingDays.where((p) => !p.date.isBefore(calendarMonthEnd)).toList();
        if (pointsOnOrAfterEnd.isNotEmpty) {
          endPoint = pointsOnOrAfterEnd.first;
        } else {
          // If no trading day on or after month end, use last point of month
          endPoint = points.last;
        }

        monthlyList.add((
          year: key.$1,
          month: key.$2,
          startDate: startPoint.date,
          startPrice: startPoint.value,
          endDate: endPoint.date,
          endPrice: endPoint.value,
        ));
      }

      tickerMonthlyData[ticker] = monthlyList;
    }

    if (tickerMonthlyData.isEmpty) {
      return const SizedBox.shrink();
    }

    return PageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Monthly Trading Range by Ticker (Yahoo Finance)", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 20),
          
          // Display each ticker's monthly data
          for (int i = 0; i < tickerMonthlyData.length; i++) ...[
            if (i > 0) const SizedBox(height: 24),
            Text(
              tickerMonthlyData.keys.elementAt(i),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text("Month")),
                  DataColumn(label: Text("Month Start\n(Trading Day)")),
                  DataColumn(label: Text("Start Price")),
                  DataColumn(label: Text("Month End\n(Trading Day)")),
                  DataColumn(label: Text("End Price")),
                ],
                rows: tickerMonthlyData.values.elementAt(i).map((m) {
                  final monthName = DateFormat('MMM yyyy').format(DateTime(m.year, m.month));
                  final startDateStr = DateFormat('dd MMM').format(m.startDate);
                  final startPriceStr = '\$${m.startPrice.toStringAsFixed(2)}';
                  final endDateStr = DateFormat('dd MMM').format(m.endDate);
                  final endPriceStr = '\$${m.endPrice.toStringAsFixed(2)}';
                  
                  return DataRow(cells: [
                    DataCell(Text(monthName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
                    DataCell(Text(startDateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)))),
                    DataCell(Text(startPriceStr, style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600))),
                    DataCell(Text(endDateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)))),
                    DataCell(Text(endPriceStr, style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600))),
                  ]);
                }).toList(),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildPortfolioSection(PortfolioProvider provider, int idx, Color color) {
    final p = provider.portfolios[idx];
    var inputBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE5E7EB)));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Container(width: 4, height: 26, color: color), const SizedBox(width: 10), Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))]),
          const SizedBox(height: 20),
          ...p.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Expanded(flex: 3, child: TextField(decoration: InputDecoration(hintText: "Ticker", filled: true, fillColor: const Color(0xFFF9FAFB), border: inputBorder), onChanged: (v) => provider.updateEntry(idx, e.id, 'ticker', v))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text("\$")),
                Expanded(flex: 2, child: TextField(decoration: InputDecoration(hintText: "Amount", filled: true, fillColor: const Color(0xFFF9FAFB), border: inputBorder), keyboardType: TextInputType.number, onChanged: (v) => provider.updateEntry(idx, e.id, 'amount', v))),
                const SizedBox(width: 6),
                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.grey), onPressed: () => provider.removeRow(idx, e.id)),
              ],
            ),
          )),
          TextButton(onPressed: () => provider.addRow(idx), child: const Text("+ Add stock", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
        ],
      ),
    );
  }

  Widget _buildSummaryTable(String title, List<SummaryRow> rows, {double totalXirr = 0}) {
    if (rows.isEmpty) return const SizedBox.shrink();
    
    // Aggregates for the footer summary
    double totalInv = rows.fold(0, (sum, item) => sum + item.investment);
    double totalVal = rows.fold(0, (sum, item) => sum + item.endValue);
    double totalRet = totalInv > 0 ? ((totalVal - totalInv) / totalInv) * 100 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
            columns: const [DataColumn(label: Text("Ticker")), DataColumn(label: Text("Investment (\$)")), DataColumn(label: Text("Units")), DataColumn(label: Text("End Value (\$)")), DataColumn(label: Text("Return (%)")), DataColumn(label: Text("XIRR (%)"))],
            rows: rows.map((r) => DataRow(cells: [
              DataCell(Text(r.ticker, style: const TextStyle(fontWeight: FontWeight.w500))),
              DataCell(Text(NumberFormat('#,##0.00').format(r.investment))),
              DataCell(Text(r.units.toStringAsFixed(6))),
              DataCell(Text(NumberFormat('#,##0.000').format(r.endValue))),
              DataCell(Text("${r.returnPct >= 0 ? '+' : ''}${r.returnPct.toStringAsFixed(1)}%", style: TextStyle(color: r.returnPct >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
              DataCell(Text("${r.xirr >= 0 ? '+' : ''}${r.xirr.toStringAsFixed(1)}%", style: TextStyle(color: r.xirr >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
            ])).toList(),
          ),
        ),
        const SizedBox(height: 15),
        // FOOTER SUMMARY with total XIRR
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 15, color: Color(0xFF374151)),
              children: [
                const TextSpan(text: "Total: "),
                TextSpan(text: "\$${NumberFormat('#,##0.00').format(totalInv)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: " → "),
                TextSpan(text: "\$${NumberFormat('#,##0.000').format(totalVal)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                  text: " (${totalRet >= 0 ? '+' : ''}${totalRet.toStringAsFixed(1)}%)", 
                  style: TextStyle(color: totalRet >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)
                ),
                const TextSpan(text: " · XIRR: "),
                TextSpan(
                  text: "${totalXirr >= 0 ? '+' : ''}${totalXirr.toStringAsFixed(1)}%", 
                  style: TextStyle(color: totalXirr >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 35),
      ],
    );
  }
}