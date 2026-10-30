import 'package:airotrack/Screens/modules/home/controllers/home_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/statistics_controller.dart';
import '../../../routes/app_routes.dart';
import '../../../../widgets/app_bottom_nav_bar.dart';

class StatisticsView extends GetView<StatisticsController> {
  const StatisticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Statistics',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: false,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Get.toNamed(Routes.TRACK),
          ),
          actions: [
            GestureDetector(
              onTap: () => _showVehiclePicker(context),
              child: Container(
                width: 128.38,
                height: 33.88,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                margin: const EdgeInsets.only(top: 9.38, right: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Obx(
                        () => Text(
                          controller.selectedPlate.value,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF009FE3)),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Obx(
                () => Row(
                  children: [
                    for (final label in ['Today', 'Yesterday', 'Week', 'Month']) ...[
                      _buildFilterTab(
                        label,
                        controller.selectedPeriod.value == label,
                        () => controller.setPeriod(label),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GestureDetector(
                      onTap: () => _pickCustomRange(context),
                      child: Image.asset(
                        'lib/Asset/Icons/Calender.png',
                        height: 28,
                        width: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                final s = controller.stats.value;
                if (controller.isLoading.value &&
                    s.routeLength == '—' &&
                    s.moveDuration == '—') {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF009FE3)),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'lib/Asset/Icons/Route_length.png',
                            "Route Length",
                            s.routeLength,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            'lib/Asset/Icons/Move_duration.png',
                            "Move Duration",
                            s.moveDuration,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'lib/Asset/Icons/stop duration.png',
                            "Stop Duration",
                            s.stopDuration,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            'lib/Asset/Icons/Idle duration.png',
                            "Idle Duration",
                            s.idleDuration,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'lib/Asset/Icons/Top speed.png',
                            "Top Speed",
                            s.topSpeed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            'lib/Asset/Icons/Average speed.png',
                            "Average Speed",
                            s.averageSpeed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'lib/Asset/Icons/over_speed.png',
                            "Over Speed Count",
                            s.overSpeedCount,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            'lib/Asset/Icons/stop_count.png',
                            "Stop Count",
                            s.stopCount,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'lib/Asset/Icons/Engine.png',
                            "Engine Hours",
                            s.engineHours,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            'lib/Asset/Icons/Odometer.png',
                            "Odometer",
                            s.odometer,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
        bottomNavigationBar: Obx(
          () => AppBottomNavBar(
            selected: AppNavTab.statistics,
            imei: controller.selectedImei.value,
            plate: controller.selectedPlate.value,
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: controller.customFrom ?? now.subtract(const Duration(days: 7)),
        end: controller.customTo ?? now,
      ),
    );
    if (range != null) {
      controller.setCustomRange(range.start, range.end);
    }
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

  Widget _buildFilterTab(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72.2,
        height: 26.89,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF009FE3) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String imagePath, String title, String value) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(imagePath, width: 25, height: 25),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
