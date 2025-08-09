import 'package:flutter/material.dart';
import 'package:pie_chart/pie_chart.dart';
import 'scan_history_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool isLoading = true;
  int scamCount = 0;
  int safeCount = 0;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<void> loadStats() async {
    setState(() => isLoading = true);
    try {
      final history = await ScanHistoryService.getHistory();
      final s = history.where((e) => e.isScam == true).length;
      final f = history.length - s;
      if (!mounted) return;
      setState(() {
        scamCount = s;
        safeCount = f;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดสถิติล้มเหลว: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataMap = {
      "มิจฉาชีพ": scamCount.toDouble(),
      "ปลอดภัย": safeCount.toDouble(),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text("สถิติจากเครื่อง"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await ScanHistoryService.clearHistory();
              await loadStats();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : scamCount + safeCount == 0
              ? const Center(child: Text("ยังไม่มีข้อมูลการตรวจสอบ"))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      PieChart(
                        dataMap: dataMap,
                        colorList: const [Colors.red, Colors.green],
                        chartRadius: MediaQuery.of(context).size.width / 2,
                        legendOptions: const LegendOptions(
                          legendPosition: LegendPosition.bottom,
                          showLegendsInRow: true,
                        ),
                        chartValuesOptions: const ChartValuesOptions(
                          showChartValuesInPercentage: true,
                          decimalPlaces: 1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildStat(
                          "รวมทั้งหมด", scamCount + safeCount, Colors.blue),
                      _buildStat("🚨 มิจฉาชีพ", scamCount, Colors.red),
                      _buildStat("✅ ปลอดภัย", safeCount, Colors.green),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStat(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(count.toString(),
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
