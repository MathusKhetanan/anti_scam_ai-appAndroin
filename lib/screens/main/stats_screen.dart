import 'package:flutter/material.dart';
import 'package:pie_chart/pie_chart.dart';
import '../models/scan_result.dart';

class StatsScreen extends StatelessWidget {
  final List<ScanResult> scanResults;

  const StatsScreen({super.key, required this.scanResults});

  @override
  Widget build(BuildContext context) {
    int scamCount = scanResults.where((e) => e.isScam).length;
    int safeCount = scanResults.length - scamCount;

    final dataMap = <String, double>{
      'มิจฉาชีพ': scamCount.toDouble(),
      'ปลอดภัย': safeCount.toDouble(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('สถิติการตรวจสอบ')),
      body: Center(
        child: PieChart(
          dataMap: dataMap,
          chartRadius: MediaQuery.of(context).size.width / 2,
          colorList: const [Colors.red, Colors.green],
          legendOptions: const LegendOptions(
            legendPosition: LegendPosition.right,
          ),
          chartValuesOptions: const ChartValuesOptions(
            showChartValuesInPercentage: true,
          ),
        ),
      ),
    );
  }
}
