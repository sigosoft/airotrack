import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../../../widgets/custom_bottom_nav_bar.dart';
import '../../dashboard/views/dashboard_view.dart';

import '../../../routes/app_routes.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Screen width usually ~393 on modern devices, designing for that scale.
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF5F5F5), // Light grey background
      body: Stack(
        children: [
          // Main Content
          Obx(() {
            switch (controller.selectedIndex.value) {
              case 0:
                return DashboardView();
              case 1:
                return _buildHome();
              case 2:
                // return const LocationView();
                return const Center(child: Text("Location Map is Disabled"));
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
    );
  }

  Widget _buildHome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Area
        const SizedBox(height: 69),
        Padding(
          padding: const EdgeInsets.only(left: 16.41),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Container(
                width: 297.8,
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
                    const Expanded(
                      child: TextField(
                        decoration: InputDecoration(
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
        SizedBox(
          height: 76,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 15.61, right: 16),
            children: [
              _buildStatusCard("All Vehicles", "15", Colors.blue, true),
              const SizedBox(width: 11),
              _buildStatusCard("Running", "2", const Color(0xFF00C853), false),
              const SizedBox(width: 11),
              _buildStatusCard("Stopped", "11", const Color(0xFFFF3D00), false),
              const SizedBox(width: 11),
              _buildStatusCard("Idle", "2", const Color(0xFFFFD600), false),
              const SizedBox(width: 11),
              _buildStatusCard(
                "Inactive",
                "0",
                const Color.fromARGB(255, 21, 107, 178),
                false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // 3. Vehicle List
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView.separated(
              padding: const EdgeInsets.only(
                left: 15.61,
                right: 15.61,
                bottom: 120,
              ),
              itemCount: controller.vehicles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 11),
              itemBuilder: (context, index) {
                final vehicle = controller.vehicles[index];
                return _buildVehicleCard(vehicle);
              },
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
      // Min width or fixed? "Width Hug".
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      constraints: const BoxConstraints(minWidth: 80, maxHeight: 80),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'lib/Asset/Icons/Car.png',
            width: 25,
            height: 22,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            count,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle) {
    final isRunning = vehicle.status == 'Running';
    final statusColor = isRunning
        ? const Color(0xFF00C853)
        : const Color(0xFFFF3D00);

    return Container(
      width: 358,
      height: 165, // Fixed height to prevent layout errors
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
            child: Icon(
              vehicle.isLocked ? Icons.lock : Icons.lock_open,
              color: const Color(0xFF00C853),
              size: 18,
            ),
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
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 50,
                          child: Image.network(
                            vehicle.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'lib/Asset/Icons/Car.png',
                              width: 50,
                              height: 50,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vehicle.speed,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                        const Text(
                          "Kmph",
                          style: TextStyle(
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
                            Text(
                              vehicle.plateNumber,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Timeline Items
                        _buildTimelineItem(
                          color: statusColor,
                          icon: null,
                          text:
                              "${vehicle.status.toUpperCase()} since ${vehicle.statusDuration}",
                          isFirst: true,
                        ),
                        _buildTimelineItem(
                          color: Colors.transparent,
                          icon: Icons.access_time,
                          iconColor: statusColor,
                          text: vehicle.lastUpdated,
                        ),
                        _buildTimelineItem(
                          color: Colors.transparent,
                          icon: Icons.location_on_outlined,
                          iconColor: statusColor,
                          text: vehicle.address,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Bottom Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSquareBtn(
                    const AssetImage("lib/Asset/Icons/Mask.png"),
                    isRunning ? Colors.blue : Colors.black,
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
                    isRunning ? Colors.green : Colors.red,
                    width: 16,
                    height: 16,
                  ),
                  _buildSquareBtn(
                    const AssetImage("lib/Asset/Icons/key.png"),
                    isRunning ? Colors.green : Colors.red,
                    width: 16,
                    height: 16,
                  ),

                  const SizedBox(width: 10),

                  _buildInfoPill(Icons.speed, "${vehicle.distance} Km"),
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
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
