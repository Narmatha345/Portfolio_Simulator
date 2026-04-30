import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide ChartPoint;
import '../models/portfolio_models.dart';

class StockPriceChart extends StatelessWidget {
  final List<ChartPoint>? data;
  final Map<String, List<ChartPoint>>? seriesMap;
  final String? ticker;
  final String chartTitle;
  final bool isStacked;

  const StockPriceChart({
    super.key,
    this.data,
    this.seriesMap,
    this.ticker,
    this.chartTitle = 'Portfolio Performance',
    this.isStacked = false,
  });

  @override
  Widget build(BuildContext context) {
    // Number format for decimals: 8,000.00
    final NumberFormat currencyFormat = NumberFormat("#,##0.00");

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chartTitle,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 20),
          SizedBox(
            height: 350,
            child: SfCartesianChart(
              legend: Legend(
                  isVisible: seriesMap != null && seriesMap!.length > 1,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap),
              trackballBehavior: TrackballBehavior(
                enable: true,
                activationMode: ActivationMode.singleTap,
                tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
                // VERSION FIX: Using tooltipSettings format to show Date and Value
                tooltipSettings: InteractiveTooltip(
                  enable: true,
                  color: const Color(0xFF1F2937),
                  // 'point.x' will show the date from DateTimeAxis
                  // 'point.y' will show the value
                  format: 'point.x : point.y', 
                  textStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              primaryXAxis: DateTimeAxis(
                // Inga kudukkura format dhaan black box-la date-ah show pannum
                dateFormat: DateFormat('d MMM yyyy'), 
                labelIntersectAction: AxisLabelIntersectAction.rotate45,
                majorGridLines: const MajorGridLines(width: 0),
                edgeLabelPlacement: EdgeLabelPlacement.shift,
              ),
              primaryYAxis: NumericAxis(
                // Decimal formatting to remove 'k'
                numberFormat: currencyFormat,
                axisLine: const AxisLine(width: 0),
                majorTickLines: const MajorTickLines(size: 0),
              ),
              series: seriesMap != null ? _buildSeriesList() : _buildSingleSeries(),
            ),
          ),
        ],
      ),
    );
  }

  List<CartesianSeries<ChartPoint, DateTime>> _buildSingleSeries() {
    return [
      LineSeries<ChartPoint, DateTime>(
        dataSource: data!,
        xValueMapper: (ChartPoint d, _) => d.date,
        yValueMapper: (ChartPoint d, _) => d.value,
        name: ticker ?? 'Net worth',
        color: const Color(0xFF007BFF),
        width: 2.5,
      )
    ];
  }

  List<CartesianSeries<ChartPoint, DateTime>> _buildSeriesList() {
    return seriesMap!.entries.map((e) {
      if (isStacked) {
        return StackedAreaSeries<ChartPoint, DateTime>(
          dataSource: e.value,
          xValueMapper: (ChartPoint d, _) => d.date,
          yValueMapper: (ChartPoint d, _) => d.value,
          name: e.key,
        );
      } else {
        return LineSeries<ChartPoint, DateTime>(
          dataSource: e.value,
          xValueMapper: (ChartPoint d, _) => d.date,
          yValueMapper: (ChartPoint d, _) => d.value,
          name: e.key,
          width: 2,
        );
      }
    }).toList();
  }
}