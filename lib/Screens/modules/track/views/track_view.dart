import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../../../../widgets/map_widget.dart';
import '../controllers/track_controller.dart';
import '../../../routes/app_routes.dart';
import 'lock_command_view.dart';

class TrackView extends GetView<TrackController> {
  const TrackView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Map Background
            Obx(
              () => MapWidget(
                mapController: controller.mapController,
                onTap: () => controller.showBottomSheet.value = false,
                markers: [
                  if (double.tryParse(controller.displayLatitude) != null &&
                      double.tryParse(controller.displayLongitude) != null)
                    Marker(
                      point: LatLng(
                        double.parse(controller.displayLatitude),
                        double.parse(controller.displayLongitude),
                      ),
                      width: 100,
                      height: 100,
                      child: GestureDetector(
                        onTap: () => controller.toggleBottomSheet(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Obx(
                              () => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: controller.displayStatusColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  controller.displayPlate,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              size: 12,
                              color: Colors.black54,
                            ),
                            Obx(
                              () => Transform.rotate(
                                angle:
                                    (controller.vehicleRotation.value - 45) *
                                    (math.pi / 180),
                                child: Image.asset(
                                  'lib/Asset/Icons/Track Vehicle.png',
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 2. Control Layout
            Stack(
              children: [
                // Top Left: Back Button
                Positioned(
                  top: 45,
                  left: 15,
                  child: GestureDetector(
                    onTap: () => Get.toNamed(Routes.HOME),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 22,
                      color: Colors.black87,
                    ),
                  ),
                ),

                // Left Control Group
                Positioned(
                  top: 180,
                  left: 15,
                  child: Column(
                    children: [
                      _buildMapControl('lib/Asset/Icons/routes detail.png'),
                      const SizedBox(height: 10),
                      _buildMapControl(
                        'lib/Asset/Icons/Focus.png',
                        onTap: () => controller.moveMapToVehicle(),
                      ),
                      const SizedBox(height: 10),
                      _buildMapControl('lib/Asset/Icons/Customer service.png'),
                      const SizedBox(height: 10),
                      _buildMapControl(
                        'lib/Asset/Icons/zoomin.png',
                        onTap: () {
                          controller.mapController.move(
                            controller.mapController.camera.center,
                            controller.mapController.camera.zoom + 1,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Top Right: Control Group
                Positioned(
                  top: 45,
                  right: 15,
                  child: Column(
                    children: [
                      _buildMapControl('lib/Asset/Icons/map.png'),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => Get.to(() => const LockCommandView()),
                        child: _buildMapControl('lib/Asset/Icons/Lock.png'),
                      ),
                      const SizedBox(height: 10),
                      _buildMapControl(null, text: 'P', textColor: Colors.red),
                      const SizedBox(height: 10),
                      _buildMapControl('lib/Asset/Icons/Video.png'),
                      const SizedBox(height: 10),
                      _buildMapControl('lib/Asset/Icons/profile.png'),
                      const SizedBox(height: 10),
                      _buildMapControl('lib/Asset/Icons/Locations.png'),
                      const SizedBox(height: 10),
                      _buildMapControl(
                        'lib/Asset/Icons/zoomin.png',
                        onTap: () {
                          controller.mapController.move(
                            controller.mapController.camera.center,
                            controller.mapController.camera.zoom + 1,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildMapControl(
                        'lib/Asset/Icons/zoomout.png',
                        onTap: () {
                          controller.mapController.move(
                            controller.mapController.camera.center,
                            controller.mapController.camera.zoom - 1,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 2. Bottom Sheet
            Obx(
              () => controller.showBottomSheet.value
                  ? _buildDraggableBottomSheet()
                  : const SizedBox.shrink(),
            ),

            // 3. Bottom Navigation Bar (Always visible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomNavBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControl(
    String? imagePath, {
    IconData? iconData,
    Color? color,
    String? text,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: imagePath != null
              ? Image.asset(imagePath, width: 20, height: 20)
              : text != null
              ? Text(
                  text,
                  style: TextStyle(
                    color: textColor ?? Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : Icon(iconData, color: color ?? Colors.black, size: 24),
        ),
      ),
    );
  }

  // Widget _buildAddRemoveControl() {
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(10),
  //       boxShadow: const [
  //         BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
  //       ],
  //     ),
  //     child: Column(
  //       children: [
  //         _buildControlPart(Icons.add),
  //         Container(width: 25, height: 1, color: Colors.grey[200]),
  //         _buildControlPart(Icons.remove),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildControlPart(IconData icon) {
  //   return SizedBox(
  //     width: 40,
  //     height: 40,
  //     child: Icon(icon, color: Colors.black, size: 24),
  //   );
  // }

  Widget _buildSpeedometerIndicator() {
    return Obx(() {
      final speedStr = controller.displaySpeed;
      final speed = double.tryParse(speedStr) ?? 0.0;
      // Gauge starts at 0.75pi and ends at 2.25pi (sweep 1.5pi)
      // The needle is vertical by default (pointing at 1.5pi position if not rotated)
      // So we rotate relative to 1.5pi.
      // 0 speed should be at 0.75pi. 140 speed at 2.25pi.
      final targetAngle = (speed / 140) * 1.5 * math.pi - (0.75 * math.pi);

      return Container(
        width: 140,
        height: 130,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: const Size(120, 120), painter: GaugePainter()),
            Positioned(
              bottom: 20,
              child: Column(
                children: [
                  Text(
                    speedStr,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "Km/h",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            // Needle
            Transform.rotate(
              angle: targetAngle,
              child: Container(
                width: 3,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(2),
                ),
                margin: const EdgeInsets.only(bottom: 45),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDraggableBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 45,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Obx(
                              () => Text(
                                controller.displayPlate,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Obx(() {
                              final imei = controller.vehicleImei.value;
                              // Show last 8 digits of IMEI to fit design
                              final displayImei = imei.length > 8
                                  ? imei.substring(imei.length - 8)
                                  : imei;
                              return Row(
                                children: List.generate(
                                  displayImei.length,
                                  (index) => _buildIdBox(displayImei[index]),
                                ),
                              );
                            }),
                            const SizedBox(height: 15),
                            Obx(
                              () => Text(
                                controller.displayDeviceTime,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Image.asset(
                                  'lib/Asset/Icons/Speed.png',
                                  width: 18,
                                  height: 18,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Obx(
                                  () => Text(
                                    "${controller.displayTodayKm} Km",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Green Car Visualization
                      Container(
                        width: 175,
                        height: 110,
                        alignment: Alignment.centerRight,
                        child: Image.asset(
                          'lib/Asset/Images/Green Car.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Obx(
                          () => Text(
                            "${controller.displayLatitude} ${controller.displayLongitude}",
                            style: const TextStyle(
                              color: Color(0xFF009FE3),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset(
                              'lib/Asset/Icons/Location.png',
                              width: 22,
                              height: 22,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Obx(
                                () => Text(
                                  controller.displayLatitude != '–'
                                      ? "Coordinates: ${controller.displayLatitude}, ${controller.displayLongitude}"
                                      : "Address information unavailable",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Status Icons Box
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.grey.shade100,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Image.asset(
                          'lib/Asset/Icons/Mask.png',
                          width: 22,
                          height: 22,
                          color: const Color(0xFF03A9F4),
                        ),
                        Image.asset(
                          'lib/Asset/Icons/Key start.png',
                          width: 22,
                          height: 22,
                          color: const Color.fromARGB(255, 3, 145, 62),
                        ),
                        Image.asset(
                          'lib/Asset/Icons/power.png',
                          width: 22,
                          height: 22,
                          color: const Color.fromARGB(255, 3, 145, 62),
                        ),
                        Image.asset(
                          'lib/Asset/Icons/Network.png',
                          width: 22,
                          height: 22,
                          color: const Color.fromARGB(255, 3, 145, 62),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Time boxes
                  Row(
                    children: [
                      Expanded(
                        child: Obx(
                          () => _buildTimeBox(
                            "Device Time",
                            controller.displayDeviceTime,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Obx(
                          () => _buildTimeBox(
                            "Server Time",
                            controller.displayLastUpdate,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Status Capsules
                  Obx(
                    () => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDurationStatusCard(
                          "Running",
                          controller.displayRunningDuration,
                          const Color.fromARGB(255, 3, 145, 62),
                        ),
                        _buildDurationStatusCard(
                          "Idle",
                          controller.displayIdleDuration,
                          const Color(0xFFFFB300),
                        ),
                        _buildDurationStatusCard(
                          "Stopped",
                          controller.displayStoppedDuration,
                          const Color(0xFFFF4B2B),
                        ),
                        _buildDurationStatusCard(
                          "Inactive",
                          controller.displayInactiveDuration,
                          const Color(0xFF00BCD4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Metric Cards section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF8FF),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Obx(
                      () => Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              "Avg Speed",
                              "–", // Placeholder
                              "Kmph",
                              'lib/Asset/Icons/AVG speed.png',
                              const Color(0xFF009FE3),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              "Max Speed",
                              "–", // Placeholder
                              "Kmph",
                              'lib/Asset/Icons/Max Distance.png',
                              const Color(0xFFFF5252),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              "Today Km",
                              controller.displayTodayKm,
                              "Km",
                              'lib/Asset/Icons/location outlined.png',
                              Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Small Grid Items
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Obx(
                      () => Row(
                        children: [
                          _buildSmallGridItem(
                            "Battery",
                            controller.isPowerOn ? "ON" : "OFF",
                            'lib/Asset/Icons/Battery.png',
                          ),
                          const SizedBox(width: 12),
                          _buildSmallGridItem(
                            "GSM Signal",
                            controller.displayGsmSignal,
                            'lib/Asset/Icons/Network.png',
                          ),
                          const SizedBox(width: 12),
                          _buildSmallGridItem(
                            "Ignition",
                            controller.isIgnitionOn ? "ON" : "OFF",
                            'lib/Asset/Icons/Key start.png',
                          ),
                          const SizedBox(width: 12),
                          _buildSmallGridItem(
                            "Network",
                            controller.displayNetwork,
                            'lib/Asset/Icons/Network.png',
                          ),
                          const SizedBox(width: 12),
                          _buildSmallGridItem(
                            "Altitude",
                            controller.displayAltitude,
                            'lib/Asset/Icons/Distance.png',
                          ),
                          const SizedBox(width: 12),
                          _buildSmallGridItem(
                            "Fuel",
                            "N/A",
                            'lib/Asset/Icons/Fuel.png',
                          ),
                          const SizedBox(width: 12),
                          _buildSmallGridItem(
                            "Temperature",
                            "N/A",
                            'lib/Asset/Icons/temperature.png',
                          ),
                          const SizedBox(width: 12),
                          _buildSmallGridItem(
                            "Movement",
                            controller.displaySpeed != "0.0" ? "True" : "False",
                            'lib/Asset/Icons/Movement.png',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),

                  // Action Buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showShareLocationBottomSheet(context),
                          child: _buildActionButton(
                            "Share Location",
                            'lib/Asset/Icons/Share Location.png',
                          ),
                        ),
                        const SizedBox(width: 18),
                        GestureDetector(
                          onTap: () => Get.toNamed(Routes.ADD_GEOFENCE),
                          child: _buildActionButton(
                            "Add \n Geofence",
                            'lib/Asset/Icons/Add geofence.png',
                          ),
                        ),
                        const SizedBox(width: 18),
                        GestureDetector(
                          onTap: () => _showStreetViewDetailsDialog(context),
                          child: _buildActionButton(
                            "Street \n View",
                            'lib/Asset/Icons/Street View.png',
                          ),
                        ),
                        const SizedBox(width: 18),
                        GestureDetector(
                          onTap: () => _showUpdateOdometerDialog(context),
                          child: _buildActionButton(
                            "Update \n Odometer",
                            'lib/Asset/Icons/Update Odometer.png',
                          ),
                        ),
                        const SizedBox(width: 18),
                        GestureDetector(
                          onTap: () => Get.toNamed(Routes.ADD_REMINDER),
                          child: _buildActionButton(
                            "Add \n Reminder",
                            'lib/Asset/Icons/Bells.png',
                          ),
                        ),
                        const SizedBox(width: 18),
                        GestureDetector(
                          onTap: () => _showOverspeedLimitDialog(context),
                          child: _buildActionButton(
                            "Overspeed \n Limit",
                            'lib/Asset/Icons/Top speed.png',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
            // Speedometer floating above
            Positioned(
              top: -85,
              left: 0,
              right: 0,
              child: Center(child: _buildSpeedometerIndicator()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIdBox(String text) {
    return Container(
      width: 15,
      height: 20,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey.shade300, width: 0.8),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeBox(String label, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            time,
            style: const TextStyle(
              color: Color(0xFF009FE3),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationStatusCard(String label, String time, Color color) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          time,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    String unit,
    String iconPath,
    Color color,
  ) {
    return Container(
      width: 82.28,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(iconPath, width: 28, height: 28, color: color),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallGridItem(String label, String value, String iconPath) {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0x08000000).withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade50, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(iconPath, width: 22, height: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, String iconPath) {
    return Container(
      width: 75,
      height: 85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0x10000000).withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(iconPath, width: 28, height: 28),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showShareLocationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          width: 391.41,
          height: 533.9,
          margin: const EdgeInsets.only(top: 18.9),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(23),
              topRight: Radius.circular(23),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              Center(
                child: Text(
                  "Share Live Location",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const Divider(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 23),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "KL 07 D 0518",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildShareOption("Only Once"),
                    const SizedBox(height: 15),
                    _buildShareOption("1 Hour"),
                    const SizedBox(height: 15),
                    _buildShareOption("1 Day"),
                    const SizedBox(height: 15),
                    _buildShareOption("1 Week"),
                    const SizedBox(height: 15),
                    _buildShareOption("2 Weeks"),
                    const SizedBox(height: 15),
                    _buildShareOption("Custom Hours"),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildShareActionButton(
                          "Cancel",
                          isSelected: false,
                          onTap: () => Navigator.pop(context),
                        ),
                        _buildShareActionButton(
                          "Share",
                          isSelected: true,
                          onTap: () {
                            // Logic for sharing
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption(String title) {
    return Obx(() {
      final isSelected = controller.selectedShareOption.value == title;
      return GestureDetector(
        onTap: () => controller.updateShareOption(title),
        child: Container(
          width: 342.26,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: isSelected ? Colors.transparent : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: const Color(0xFF009FE3), width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected ? Colors.black : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF009FE3),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF009FE3),
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildShareActionButton(
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
    double width = 140,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 30),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF009FE3) : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: isSelected ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showUpdateOdometerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 11.14),
          child: Container(
            width: 370.08,
            height: 175.38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              children: [
                const Positioned(
                  top: 15,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      "Update Odometer",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 57.47,
                  left: 24.09,
                  child: Container(
                    width: 343,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 15,
                  left: 24.09,
                  right: 24.09,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildShareActionButton(
                        "Cancel",
                        isSelected: false,
                        onTap: () => Navigator.pop(context),
                      ),
                      _buildShareActionButton(
                        "Update",
                        isSelected: true,
                        onTap: () {
                          // Update logic
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOverspeedLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            width: 370,
            height: 175,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              children: [
                const Positioned(
                  top: 15,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      "Update Speed Limit",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 57.47,
                  left: 13.5,
                  child: Container(
                    width: 343,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 15,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildShareActionButton(
                        "Cancel",
                        isSelected: false,
                        width: 160,
                        onTap: () => Navigator.pop(context),
                      ),
                      _buildShareActionButton(
                        "Update",
                        isSelected: true,
                        width: 160,
                        onTap: () {
                          // Update logic
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStreetViewDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 235,
            height: 112,
            padding: const EdgeInsets.fromLTRB(17, 9, 17, 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStreetViewDetailRow(
                  "Arrival Time:",
                  "08 Oct 2025 11:00 AM",
                ),
                const SizedBox(height: 5),
                _buildStreetViewDetailRow(
                  "Departure Time:",
                  "08 Oct 2025 12:30 PM",
                ),
                const SizedBox(height: 5),
                _buildStreetViewDetailRow("Duration:", "01h 30m"),
                const SizedBox(height: 5),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        width: 75,
                        child: Text(
                          "Address:",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          "Puthiyakavu Junction, Karunagappalli, Kerala 690539, India",
                          style: TextStyle(fontSize: 10, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStreetViewDetailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 10, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 85,
      padding: const EdgeInsets.only(bottom: 15),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomNavItem(
            "Track",
            'lib/Asset/Icons/Location.png',
            true,
            onTap: () => Get.toNamed(Routes.HOME),
          ),
          _buildBottomNavItem(
            "History",
            'lib/Asset/Icons/history.png',
            false,
            onTap: () => Get.toNamed(Routes.HISTORY),
          ),
          _buildBottomNavItem(
            "Alerts",
            'lib/Asset/Icons/Bells.png',
            false,
            onTap: () => Get.toNamed(Routes.ALERTS),
          ),
          _buildBottomNavItem(
            "Statistics",
            'lib/Asset/Icons/statistics.png',
            false,
            onTap: () => Get.toNamed(Routes.STATISTICS),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(
    String label,
    String iconPath,
    bool isSelected, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            iconPath,
            width: 25,
            height: 25,
            color: isSelected ? const Color(0xFF009FE3) : Colors.black87,
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF009FE3) : Colors.black87,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    final sections = [
      {'color': const Color(0xFF00C853), 'start': 0.75, 'sweep': 0.5},
      {'color': const Color(0xFFFFD600), 'start': 1.25, 'sweep': 0.5},
      {'color': const Color(0xFFFF3D00), 'start': 1.75, 'sweep': 0.5},
    ];

    for (var section in sections) {
      final paint = Paint()
        ..color = section['color'] as Color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * (section['start'] as double),
        math.pi * (section['sweep'] as double),
        false,
        paint,
      );
    }

    final paintMark = Paint()
      ..color = Colors.black38
      ..strokeWidth = 1.5;

    for (int i = 0; i <= 20; i++) {
      final double angle = math.pi * (0.75 + (i * 1.5 / 20));
      final double dx = math.cos(angle);
      final double dy = math.sin(angle);
      final double outerR = radius + 6;
      final double innerR = i % 5 == 0 ? radius - 6 : radius - 2;
      canvas.drawLine(
        Offset(center.dx + innerR * dx, center.dy + innerR * dy),
        Offset(center.dx + outerR * dx, center.dy + outerR * dy),
        paintMark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
