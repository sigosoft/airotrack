import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../../../widgets/custom_bottom_nav_bar.dart';
import '../../dashboard/views/dashboard_view.dart';
import '../../reports/views/reports_view.dart';
import '../../settings/views/settings_view.dart';
import '../../location/views/location_view.dart';

import '../../../routes/app_routes.dart';
import '../../../widgets/vehicle_details_dialog.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Screen width usually ~393 on modern devices, designing for that scale.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        controller.onBackPressed();
      },
      child: Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white, // Pure white background to match design
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // Main Content
            Obx(() {
              switch (controller.selectedIndex.value) {
                case 0:
                  return DashboardView();
                case 1:
                  return _buildHome();
                case 2:
                  return const LocationView();
                case 3:
                  return const ReportsView();
                case 4:
                  return const SettingsView();
                default:
                  return _buildPlaceholder("Coming Soon");
              }
            }),

            // Bottom Navigation
            Positioned(
              left: -1.5,
              right: 0,
              bottom: 0,
              child: SizedBox(height: 118, child: const CustomBottomNavBar()),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Area. Keep the design's gap, but never less than the
        // status bar plus a margin (tall notches).
        Builder(
          builder: (context) => SizedBox(
            height: math.max(69.0, MediaQuery.paddingOf(context).top + 24),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar takes whatever width the bell leaves, so the row
              // fits every phone width.
              Expanded(
                child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        onChanged: (value) =>
                            controller.searchQuery.value = value,
                        decoration: const InputDecoration(
                          hintText: "Search Vehicles",
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          contentPadding: EdgeInsets.only(bottom: 12),
                        ),
                      ),
                    ),
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 16),
                  ],
                ),
                ),
              ),
              const SizedBox(width: 6.99),
              // Notification Icon
              GestureDetector(
                onTap: () => Get.toNamed(Routes.NOTIFICATION),
                child: Container(
                  width: 53.69,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: const FittedBox(
                    child: Icon(
                      Icons.notifications_outlined,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15.5),
        // 2. Status Filters
        Obx(
          () => SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 15.61, right: 16),
              children: [
                GestureDetector(
                  onTap: () => controller.fetchVehicles(type: 1),
                  child: _buildStatusCard(
                    "All Vehicles",
                    controller.totalCount.value,
                    Colors.blue,
                    controller.selectedType.value == 1,
                  ),
                ),
                const SizedBox(width: 11),
                GestureDetector(
                  onTap: () => controller.fetchVehicles(type: 2),
                  child: _buildStatusCard(
                    "Running",
                    controller.runningCount.value,
                    const Color(0xFF00C853),
                    controller.selectedType.value == 2,
                  ),
                ),
                const SizedBox(width: 11),
                GestureDetector(
                  onTap: () => controller.fetchVehicles(type: 3),
                  child: _buildStatusCard(
                    "Idle",
                    controller.idleCount.value,
                    const Color(0xFFFFD600),
                    controller.selectedType.value == 3,
                  ),
                ),
                const SizedBox(width: 11),
                GestureDetector(
                  onTap: () => controller.fetchVehicles(type: 4),
                  child: _buildStatusCard(
                    "Stop",
                    controller.stoppedCount.value,
                    const Color(0xFFFF3D00),
                    controller.selectedType.value == 4,
                  ),
                ),
                const SizedBox(width: 11),
                GestureDetector(
                  onTap: () => controller.fetchVehicles(type: 5),
                  child: _buildStatusCard(
                    "Expired",
                    controller.expiredCount.value,
                    const Color(0xFFFF9100),
                    controller.selectedType.value == 5,
                  ),
                ),
                const SizedBox(width: 11),
                GestureDetector(
                  onTap: () => controller.fetchVehicles(type: 6),
                  child: _buildStatusCard(
                    "Inactive",
                    controller.inactiveVehiclesCount.value,
                    Colors.blue,
                    controller.selectedType.value == 6,
                  ),
                ),
                const SizedBox(width: 11),
                GestureDetector(
                  onTap: () => controller.fetchVehicles(type: 7),
                  child: _buildStatusCard(
                    "No Data",
                    controller.noDataCount.value,
                    Colors.grey,
                    controller.selectedType.value == 7,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 3. Vehicle List
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = controller.filteredVehicles;
            final query = controller.searchQuery.value.trim();
            final showLoadMore =
                query.isEmpty && controller.isMoreLoading.value;
            Future<void> onRefresh() => controller.fetchVehicles(
                  type: controller.selectedType.value,
                  force: true,
                );
            if (list.isEmpty && !showLoadMore) {
              // Scrollable so pull-to-refresh still works on an empty tab.
              return RefreshIndicator(
                onRefresh: onRefresh,
                color: const Color(0xFF009FE3),
                child: LayoutBuilder(
                  builder: (context, constraints) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: constraints.maxHeight,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              query.isEmpty
                                  ? 'No vehicles found'
                                  : 'No vehicles match "$query"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: onRefresh,
              color: const Color(0xFF009FE3),
              child: ListView.separated(
                controller: controller.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  left: 15.61,
                  right: 15.61,
                  bottom: 120,
                ),
                itemCount: list.length + (showLoadMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 11),
                itemBuilder: (context, index) {
                  if (index < list.length) {
                    final vehicle = list[index];
                    return _buildVehicleCard(context, vehicle);
                  } else {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF009FE3),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusCard(
    String title,
    String count,
    Color color,
    bool isSelected,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      constraints: const BoxConstraints(minWidth: 80, maxHeight: 90),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isSelected ? color : Colors.transparent,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'lib/Asset/Icons/Car.png',
            width: 25,
            height: 22,
            color: color,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            count,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Car picture for each status, matching the status colours.
  String _statusCarImage(String status) {
    switch (status) {
      case 'Running':
        return 'lib/Asset/Images/Green right Car.png';
      case 'Idle':
        return 'lib/Asset/Images/Idle_yellow_rightcar.png';
      case 'Expired':
        return 'lib/Asset/Images/Expired_GlossyOrange_rightcar.png';
      case 'Inactive':
        return 'lib/Asset/Images/Inactive_blue_rightcar.png';
      case 'No data':
        return 'lib/Asset/Images/No data_grey_rightcar.png';
      default:
        return 'lib/Asset/Images/Red right Car.png';
    }
  }

  /// Same colours as the status cards at the top of Home.
  Color _statusColor(String status) {
    switch (status) {
      case 'Running':
        return const Color(0xFF00C853);
      case 'Idle':
        return const Color(0xFFFFD600);
      case 'Expired':
        return const Color(0xFFFF9100);
      case 'Inactive':
        return Colors.blue;
      case 'No data':
        return Colors.grey;
      default:
        return const Color(0xFFFF3D00);
    }
  }

  Widget _buildVehicleCard(BuildContext context, Vehicle vehicle) {
    // Both 'Running' and 'Idle' (Moving or Ignition-On) should show as Active (Green).
    final isStatusActive =
        vehicle.status == 'Running' || vehicle.status == 'Idle';
    final statusColor = _statusColor(vehicle.status);

    return GestureDetector(
      key: ValueKey('vehicle-${vehicle.id}-${vehicle.deviceId}'),
      onTap: () => showVehicleDetailsDialog(context, vehicle),
      child: Container(
        width: 358,
        height: 165,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Lock Icon Top Left
            Positioned(
              top: 0,
              left: 0,
              child: vehicle.isLocked
                  ? Image.asset(
                      'lib/Asset/Icons/Lock.png',
                      width: 18,
                      height: 18,
                      color: const Color(0xFF00C853),
                    )
                  : const SizedBox.shrink(),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Car Image & Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Col: Image + Speed
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 48,
                            child: Image.asset(
                              _statusCarImage(vehicle.status),
                              fit: BoxFit.contain,
                              // Keep the old picture until the new status
                              // picture is ready: no blank frame on refresh.
                              gaplessPlayback: true,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            vehicle.displaySpeed,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Roboto Mono',
                            ),
                          ),
                          Text(
                            vehicle.speedUnitLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right Col: Timeline Details
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Plate
                          Row(
                            children: [
                              Icon(
                                Icons.directions_car_filled,
                                size: 16,
                                color: statusColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  vehicle.plateNumber,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),

                          // Timeline Items
                          _buildTimelineItem(
                            color: statusColor,
                            icon: null,
                            // The home API sends no duration today: show
                            // "since …" only when there is one.
                            text: vehicle.statusDuration.trim().isEmpty
                                ? vehicle.statusLabel.toUpperCase()
                                : "${vehicle.statusLabel.toUpperCase()} since ${vehicle.statusDuration.trim()}",
                            isFirst: true,
                          ),
                          _buildTimelineItem(
                            color: Colors.transparent,
                            icon: Icons.access_time,
                            iconColor: statusColor,
                            text: vehicle.displayLastUpdated,
                          ),
                          _buildTimelineItem(
                            color: Colors.transparent,
                            icon: Icons.location_on_outlined,
                            iconColor: statusColor,
                            text: vehicle.locationLabel,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Bottom Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSquareBtn(
                      const AssetImage("lib/Asset/Icons/Mask.png"),
                      isStatusActive ? Colors.blue : Colors.black,
                      width: 16,
                      height: 16,
                    ),
                    _buildSquareBtn(
                      const AssetImage("lib/Asset/Icons/satellite.png"),
                      Colors.green,
                      width: 16,
                      height: 16,
                    ),
                    _buildSquareBtn(
                      const AssetImage("lib/Asset/Icons/power.png"),
                      isStatusActive ? Colors.green : Colors.red,
                      width: 16,
                      height: 16,
                    ),
                    _buildSquareBtn(
                      const AssetImage("lib/Asset/Icons/key.png"),
                      isStatusActive ? Colors.green : Colors.red,
                      width: 16,
                      height: 16,
                    ),

                    const SizedBox(width: 10),

                    _buildInfoPill(Icons.speed, vehicle.displayTodayKm),
                    const SizedBox(width: 6),
                    _buildInfoPill(
                      Icons.calendar_today,
                      "${vehicle.validityDays} Days",
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required Color color,
    IconData? icon,
    Color? iconColor,
    required String text,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            if (icon != null)
              Icon(icon, size: 12, color: iconColor)
            else
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            if (!isLast)
              Container(
                width: 1,
                height: 10,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildSquareBtn(
    AssetImage image,
    Color color, {
    double width = 16,
    double height = 16,
  }) {
    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Image(image: image, color: color, width: width, height: height),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Expanded(
      child: Container(
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: Colors.grey),
            const SizedBox(width: 2),
            // Shrink the value to fit narrow cards instead of cutting it
            // ("85.77 …"), so the whole number stays readable.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
