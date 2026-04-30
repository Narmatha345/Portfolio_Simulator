import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
// Always use package imports to avoid "path not found" issues
import 'package:example/src/models/portfolio_models.dart';

class BaseLineChart extends StatelessWidget {
  final List<ChartSeries> series;
  final String title;

  const BaseLineChart({super.key, required this.series, required this.title});

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox(height: 100, child: Center(child: Text("No Data")));

    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        SizedBox(
          height: 300,
          child: LineChart(
            LineChartData(
              // .map<LineChartBarData> nu kudutha thaan 'List<dynamic>' error varathu
              lineBarsData: series.map<LineChartBarData>((s) {
                return LineChartBarData(
                  spots: s.data.map((p) => FlSpot(p.date.millisecondsSinceEpoch.toDouble(), p.value)).toList(),
                  isCurved: false,
                  color: Color(s.color),
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                );
              }).toList(),
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
            ),
          ),
        ),
      ],
    );
  }
}