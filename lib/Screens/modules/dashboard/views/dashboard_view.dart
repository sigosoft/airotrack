import 'package:airotrack/Models/DashboardModel.dart';
import 'package:airotrack/Screens/modules/home/controllers/home_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/dashboard_controller.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = controller.dashboard.value;
      final fleet = data.fleet;
      final engineSpots = data.engineSpots();
      final engineLabels = data.engineLabels();
      final distance = data.travelDistance;

      return Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              children: [
                const SizedBox(height: 15),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Image.asset(
                      'lib/Asset/airotrack_Logo.png',
                      height: 60,
                      errorBuilder: (_, __, ___) => const SizedBox(height: 60),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () => _showVehiclePicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                          Expanded(
                            child: Text(
                              controller.selectedPlate.value,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
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
                ),
                const SizedBox(height: 20),
                _buildCard(
                  title: "Fleet Status",
                  child: Row(
                    children: [
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
                                  sections: _fleetSections(fleet),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${fleet.total}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
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
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _buildLegendItem(
                              "Running",
                              fleet.padded(fleet.running),
                              const Color(0xFF10B25B),
                            ),
                            _buildLegendItem(
                              "Stopped",
                              fleet.padded(fleet.stopped),
                              const Color(0xFFEA4335),
                            ),
                            _buildLegendItem(
                              "Idle",
                              fleet.padded(fleet.idle),
                              const Color(0xFFFABC05),
                            ),
                            _buildLegendItem(
                              "Expired",
                              fleet.padded(fleet.expired),
                              const Color(0xFFFB8C00),
                            ),
                            _buildLegendItem(
                              "Inactive",
                              fleet.padded(fleet.inactive),
                              const Color(0xFF4285F4),
                            ),
                            _buildLegendItem(
                              "No Data",
                              fleet.padded(fleet.noData),
                              const Color(0xFF9E9E9E),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCard(
                  title: "Engine Hours",
                  child: SizedBox(
                    height: 200,
                    child: engineSpots.isEmpty
                        ? const Center(
                            child: Text(
                              'No engine hour data',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    interval: 4,
                                    getTitlesWidget: (value, meta) {
                                      if (value < 0 ||
                                          value > 24 ||
                                          value % 4 != 0) {
                                        return const SizedBox();
                                      }
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
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      final x = value.round();
                                      if ((value - x).abs() > 0.01) {
                                        return const SizedBox();
                                      }
                                      final i = x - 1;
                                      if (i < 0 || i >= engineLabels.length) {
                                        return const SizedBox();
                                      }
                                      // Skip some labels when many days to avoid clutter.
                                      if (engineLabels.length > 8 &&
                                          i % 2 != 0 &&
                                          i != engineLabels.length - 1) {
                                        return const SizedBox();
                                      }
                                      return SideTitleWidget(
                                        meta: meta,
                                        space: 5,
                                        child: Text(
                                          engineLabels[i],
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 9,
                                          ),
                                        ),
                                      );
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
                                  left: BorderSide(
                                    color: Colors.grey.shade400,
                                    width: 2,
                                  ),
                                  bottom: BorderSide(
                                    color: Colors.grey.shade400,
                                    width: 2,
                                  ),
                                ),
                              ),
                              minX: engineSpots.length == 1
                                  ? 0.5
                                  : 1,
                              maxX: engineSpots.length == 1
                                  ? 1.5
                                  : engineSpots.length.toDouble(),
                              minY: 0,
                              maxY: 24,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _engineLineSpots(engineSpots),
                                  isCurved: true,
                                  color: const Color(0xFF10B25B),
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  // Match design mock: smooth line, no dots.
                                  dotData: FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF06753A)
                                            .withOpacity(0.3),
                                        const Color(0xFF10B25B)
                                            .withOpacity(0.0),
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
                _buildCard(
                  title: "Travel Distance (in Km)",
                  child: SizedBox(
                    height: 250,
                    child: distance.isEmpty
                        ? const Center(
                            child: Text(
                              'No travel distance data',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : BarChart(
                            BarChartData(
                              backgroundColor: Colors.transparent,
                              gridData: FlGridData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (value, meta) {
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
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    getTitlesWidget: (value, meta) {
                                      final i = value.toInt();
                                      if (i < 0 || i >= distance.length) {
                                        return const SizedBox();
                                      }
                                      return SideTitleWidget(
                                        meta: meta,
                                        space: 5,
                                        child: Text(
                                          distance[i].label,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 9,
                                          ),
                                        ),
                                      );
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
                                  left: BorderSide(
                                    color: Colors.grey.shade400,
                                    width: 2,
                                  ),
                                  bottom: BorderSide(
                                    color: Colors.grey.shade400,
                                    width: 2,
                                  ),
                                ),
                              ),
                              barGroups: [
                                for (var i = 0; i < distance.length; i++)
                                  _buildBarGroup(
                                    i,
                                    distance[i].value,
                                    _maxDistance(distance),
                                  ),
                              ],
                              minY: 0,
                              maxY: _maxDistance(distance),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (controller.isLoading.value)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF009FE3)),
                ),
              ),
            ),
        ],
      );
    });
  }

  /// With a single API day, draw a short flat line so it matches the design
  /// line-chart look instead of one isolated point.
  List<FlSpot> _engineLineSpots(List<FlSpot> spots) {
    if (spots.length != 1) return spots;
    final y = spots.first.y;
    return [FlSpot(0.5, y), FlSpot(1, y), FlSpot(1.5, y)];
  }

  double _maxDistance(List<ChartPoint> points) {
    if (points.isEmpty) return 10;
    final max = points.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    if (max <= 0) return 10;
    // Round up to a nicer axis top (at least 10% headroom).
    final padded = max * 1.15;
    if (padded <= 10) return 10;
    if (padded <= 50) return (padded / 5).ceil() * 5.0;
    if (padded <= 100) return (padded / 10).ceil() * 10.0;
    if (padded <= 500) return (padded / 50).ceil() * 50.0;
    return (padded / 100).ceil() * 100.0;
  }

  List<PieChartSectionData> _fleetSections(FleetStatus fleet) {
    final entries = [
      (fleet.running.toDouble(), const Color(0xFF10B25B)),
      (fleet.stopped.toDouble(), const Color(0xFFEA4335)),
      (fleet.idle.toDouble(), const Color(0xFFFABC05)),
      (fleet.expired.toDouble(), const Color(0xFFFB8C00)),
      (fleet.inactive.toDouble(), const Color(0xFF4285F4)),
      (fleet.noData.toDouble(), const Color(0xFF9E9E9E)),
    ];
    final hasAny = entries.any((e) => e.$1 > 0);
    if (!hasAny) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 1,
          radius: 25,
          showTitle: false,
        ),
      ];
    }
    return [
      for (final e in entries)
        if (e.$1 > 0)
          PieChartSectionData(
            color: e.$2,
            value: e.$1,
            radius: 25,
            showTitle: false,
          ),
    ];
  }

  void _showVehiclePicker(BuildContext context) {
    final list = controller.vehicles;
    if (list.isEmpty && Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().fetchVehicles();
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final vehicles = controller.vehicles;
        if (vehicles.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No vehicles available'),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: vehicles.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final v = vehicles[i];
            return ListTile(
              title: Text(v.plateNumber.isEmpty ? v.deviceId : v.plateNumber),
              subtitle: Text(v.deviceId),
              onTap: () {
                Get.back();
                controller.selectVehicle(v);
              },
            );
          },
        );
      },
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
