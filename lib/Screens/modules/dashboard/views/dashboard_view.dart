import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/dashboard_controller.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        children: [
          const SizedBox(height: 15),
          // Logo
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Image.asset(
                'lib/Asset/airotrack_Logo.png',
                height: 60,
                errorBuilder: (_, __, ___) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 30,
                      ),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "AT",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            "AIRO TRACK",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "KL 07 D 0518",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Colors.blue.shade400,
                    size: 40,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Fleet Status Card
          _buildCard(
            title: "Fleet Status",
            child: Row(
              children: [
                // Donut Chart
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 0,
                            centerSpaceRadius: 40,
                            startDegreeOffset: -90,
                            sections: [
                              PieChartSectionData(
                                color: const Color(0xFF10B25B),
                                value: 15,
                                radius: 25,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                color: const Color(0xFFEA4335),
                                value: 3,
                                radius: 25,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                color: const Color(0xFFFABC05),
                                value: 5,
                                radius: 25,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                color: const Color(0xFFFB8C00),
                                value: 1,
                                radius: 25,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                color: const Color(0xFF4285F4),
                                value: 4,
                                radius: 25,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                color: const Color(0xFF9E9E9E),
                                value: 3,
                                radius: 25,
                                showTitle: false,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              "30",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Vehicles",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Legend
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _buildLegendItem(
                        "Running",
                        "15",
                        const Color(0xFF10B25B),
                      ),
                      _buildLegendItem(
                        "Stopped",
                        "03",
                        const Color(0xFFEA4335),
                      ),
                      _buildLegendItem("Idle", "05", const Color(0xFFFABC05)),
                      _buildLegendItem(
                        "Expired",
                        "01",
                        const Color(0xFFFB8C00),
                      ),
                      _buildLegendItem(
                        "Inactive",
                        "04",
                        const Color(0xFF4285F4),
                      ),
                      _buildLegendItem(
                        "No Data",
                        "03",
                        const Color(0xFF9E9E9E),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Engine Hours Card
          _buildCard(
            title: "Engine Hours",
            child: SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 25,
                        interval: 4,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() == value &&
                              value >= 0 &&
                              value <= 24) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 5,
                              child: Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() != value ||
                              value < 2 ||
                              value > 8) {
                            return const SizedBox();
                          }
                          const titles = [
                            '2/10',
                            '3/10',
                            '4/10',
                            '5/10',
                            '6/10',
                            '7/10',
                            '8/10',
                          ];
                          int index = value.toInt() - 2;
                          if (index >= 0 && index < titles.length) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 5,
                              child: Text(
                                titles[index],
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade400, width: 2),
                      bottom: BorderSide(color: Colors.grey.shade400, width: 2),
                    ),
                  ),
                  minX: 1.5,
                  maxX: 8.5,
                  minY: 0,
                  maxY: 24,
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(2, 4),
                        FlSpot(3, 3),
                        FlSpot(4, 3),
                        FlSpot(5, 2),
                        FlSpot(6, 3),
                        FlSpot(7, 4),
                        FlSpot(8, 0),
                      ],
                      isCurved: true,
                      color: const Color(0xFF10B25B),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color.fromARGB(
                              255,
                              6,
                              117,
                              58,
                            ).withOpacity(0.3),
                            const Color(0xFF10B25B).withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Travel Distance Card
          _buildCard(
            title: "Travel Distance (in Km)",
            child: SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  backgroundColor: Colors.transparent,
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 25,
                        interval: 16,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() == value &&
                              value % 16 == 0 &&
                              value >= 0 &&
                              value <= 144) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 5,
                              child: Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          const titles = [
                            '6/10',
                            '7/10',
                            '8/10',
                            '9/10',
                            '10/10',
                            '11/10',
                            '12/10',
                            '13/10',
                          ];
                          int index = value.toInt() - 6;
                          if (index >= 0 && index < titles.length) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 5,
                              child: Text(
                                titles[index],
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade400, width: 2),
                      bottom: BorderSide(color: Colors.grey.shade400, width: 2),
                    ),
                  ),
                  barGroups: [
                    _buildBarGroup(6, 48, 140),
                    _buildBarGroup(7, 24, 140),
                    _buildBarGroup(8, 32, 140),
                    _buildBarGroup(9, 64, 140),
                    _buildBarGroup(10, 112, 140),
                    _buildBarGroup(11, 0, 140),
                    _buildBarGroup(12, 0, 140),
                    _buildBarGroup(13, 8, 140),
                  ],
                  minY: 0,
                  maxY: 144,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double value, double total) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          color: const Color(0xFF10B25B),
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: total,
            color: Colors.grey.shade300,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(padding: const EdgeInsets.all(16.0), child: child),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Text(
            count,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
