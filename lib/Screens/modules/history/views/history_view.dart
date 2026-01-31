import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/history_controller.dart';
import '../../../routes/app_routes.dart';

class HistoryView extends GetView<HistoryController> {
  const HistoryView({Key? key}) : super(key: key);

  Widget _buildMapLayer() {
    return FlutterMap(
      options: const MapOptions(
        initialCenter: LatLng(11.8745, 75.3704),
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.airotrack.app',
        ),
        // PolylineLayer(
        //   polylines: [
        //     Polyline(
        //       points: const [
        //         LatLng(11.8745, 75.3704),
        //         LatLng(11.8800, 75.3800),
        //         LatLng(11.8700, 75.3900),
        //         LatLng(11.8600, 75.3800),
        //         LatLng(11.8745, 75.3704),
        //       ],
        //       color: Colors.black,
        //       strokeWidth: 4,
        //     ),
        //   ],
        // ),
        // MarkerLayer(
        //   markers: [
        //     _buildClusterMarker(LatLng(11.8845, 75.3750), "2"),
        //     _buildClusterMarker(LatLng(11.8900, 75.3950), "1"),
        //     _buildClusterMarker(LatLng(11.8680, 75.3780), "3"),
        //     _buildClusterMarker(LatLng(11.8610, 75.3940), "4"),
        //   ],
        // ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 22),
          onPressed: () => Get.back(),
        ),
        title: Obx(
          () => Text(
            controller.vehicleId.value,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            onSelected: controller.updateDateRange,
            itemBuilder: (context) => controller.dateRangeOptions
                .map(
                  (option) => PopupMenuItem(value: option, child: Text(option)),
                )
                .toList(),
            offset: const Offset(0, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Container(
              height: 35,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(
                    () => Text(
                      controller.selectedDateRange.value,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF009FE3)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight;
          // Calculate initial size based on the requested top position (425.62)
          // Adjusting for the fact that Positioned top: 425.62-80 was used.
          // We'll target the same starting height.
          double topTarget = 425.62 - 80;
          double initialSize = (maxHeight - topTarget) / maxHeight;
          initialSize = initialSize.clamp(0.2, 0.9);

          return Stack(
            children: [
              _buildMapLayer(),

              // Side Buttons (Left Top)
              Positioned(
                top: 15,
                left: 15,
                child: _buildSideButton('lib/Asset/Icons/map.png'),
              ),

              // Side Buttons (Right Middle)
              Positioned(
                top: 100,
                right: 15,
                child: Column(
                  children: [
                    _buildSideButton('lib/Asset/Icons/Locations.png'),
                    const SizedBox(height: 10),
                    _buildSideButton(null, text: "P", textColor: Colors.green),
                    const SizedBox(height: 10),
                    _buildSideButton('lib/Asset/Icons/Arrows.png'),
                    const SizedBox(height: 10),
                    _buildSideButton('lib/Asset/Icons/zoomin.png'),
                    const SizedBox(height: 10),
                    _buildSideButton('lib/Asset/Icons/zoomout.png'),
                  ],
                ),
              ),

              // Bottom Sheet
              Obx(
                () => controller.showBottomSheet.value
                    ? DraggableScrollableSheet(
                        initialChildSize: initialSize,
                        minChildSize: initialSize,
                        maxChildSize: 0.95,
                        snap: true,
                        builder: (context, scrollController) {
                          return _buildHistoryBottomSheet(scrollController);
                        },
                      )
                    : Positioned(
                        bottom: 120,
                        right: 15,
                        child: GestureDetector(
                          onTap: () => controller.showBottomSheet.value = true,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: const Icon(
                              Icons.keyboard_arrow_up,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomNavBar(),
              ),
            ],
          );
        },
      ),
    );
  }

  // Marker _buildClusterMarker(LatLng point, String label) {
  //   return Marker(
  //     point: point,
  //     width: 40,
  //     height: 40,
  //     child: Container(
  //       decoration: BoxDecoration(
  //         color: const Color(0xFF009FE3).withOpacity(0.6),
  //         borderRadius: BorderRadius.circular(8),
  //       ),
  //       child: Center(
  //         child: Text(
  //           label,
  //           style: const TextStyle(
  //             color: Colors.white,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildSideButton(String? assetPath, {String? text, Color? textColor}) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: assetPath != null
            ? Image.asset(assetPath, width: 20, height: 20)
            : Text(
                text ?? "",
                style: TextStyle(
                  color: textColor ?? Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  Widget _buildHistoryBottomSheet(ScrollController scrollController) {
    return Container(
      width: 390.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 12),
          // Handle
          Center(
            child: Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'lib/Asset/Icons/Calender.png',
                      width: 22,
                      height: 22,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Obx(
                      () => Text(
                        "From: ${controller.fromDate.value}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Obx(
                  () => Text(
                    controller.vehicleId.value,
                    style: const TextStyle(
                      color: Color(0xFF009FE3),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Image.asset(
                      'lib/Asset/Icons/Calender.png',
                      width: 22,
                      height: 22,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Obx(
                      () => Text(
                        "To: ${controller.toDate.value}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildIconStat(
                  'lib/Asset/Icons/KmPh.png',
                  controller.currentSpeed,
                  Colors.red,
                ),
                _buildIconStat(
                  'lib/Asset/Icons/time duration.png',
                  controller.duration,
                  Colors.red,
                ),
                _buildIconStat(
                  'lib/Asset/Icons/Distance.png',
                  controller.totalDistance,
                  Colors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Image.asset(
                    'lib/Asset/Icons/Play.png',
                    width: 30,
                    height: 30,
                  ),

                  onPressed: () {},
                ),
                Expanded(
                  child: Obx(
                    () => Slider(
                      value: controller.progress.value,
                      onChanged: (v) => controller.progress.value = v,
                      activeColor: const Color(0xFF009FE3),
                      inactiveColor: Colors.grey.shade200,
                    ),
                  ),
                ),
                _buildCircularControl(
                  Image.asset(
                    'lib/Asset/Icons/1x.png',
                    width: 35,
                    height: 35,
                    fit: BoxFit.contain,
                    // color: const Color(0xFF009FE3),
                  ),
                ),
                const SizedBox(width: 8),
                _buildCircularControlIcon(
                  Image.asset(
                    'lib/Asset/Icons/repeat.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                    color: const Color(0xFF009FE3),
                  ),
                ),
                const SizedBox(width: 8),
                _buildCircularControlIcon(
                  Image.asset(
                    'lib/Asset/Icons/mapfromto.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                    // color: const Color(0xFF009FE3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildSegmentItem(
                  distance: "00.00 Km",
                  status: "Stop",
                  statusColor: Colors.red.shade100,
                  statusTextColor: Colors.red,
                  maxSpeed: "00.00 Kmph",
                  start: "08 Oct 2025, 12:04:32 AM",
                  duration: "09h 33m 13s",
                  end: "08 Oct 2025, 11:01:30 PM",
                ),
                const SizedBox(height: 15),
                _buildSegmentItem(
                  distance: "00.00 Km",
                  status: "Stop",
                  statusColor: Colors.green.shade100,
                  statusTextColor: Colors.green,
                  maxSpeed: "00.00 Kmph",
                  start: "08 Oct 2025, 12:04:32 AM",
                  duration: "09h 33m 13s",
                  end: "08 Oct 2025, 11:01:30 PM",
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconStat(String assetPath, RxString value, Color iconColor) {
    return Row(
      children: [
        Image.asset(assetPath, width: 22, height: 22, color: iconColor),
        const SizedBox(width: 8),
        Obx(
          () => Text(
            value.value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircularControl(Widget child) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 35,
        height: 35,
        color: Colors.transparent,
        child: Center(child: child),
      ),
    );
  }

  Widget _buildCircularControlIcon(Widget child) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 35,
        height: 35,
        color: Colors.transparent,
        child: Center(child: child),
      ),
    );
  }

  Widget _buildSegmentItem({
    required String distance,
    required String status,
    required Color statusColor,
    required Color statusTextColor,
    required String maxSpeed,
    required String start,
    required String duration,
    required String end,
  }) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.directions_walk, color: Colors.grey, size: 22),
            const SizedBox(width: 8),
            Text(
              "Distance: $distance",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            const Icon(Icons.speed, color: Colors.grey, size: 22),
            const SizedBox(width: 8),
            Text(
              "Max Speed: $maxSpeed",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildDashedLine(),
        const SizedBox(height: 8),
        _buildRowDetail(Icons.play_circle_outline, "Start:", start),
        const SizedBox(height: 8),
        _buildDashedLine(),
        const SizedBox(height: 8),
        _buildRowDetail(Icons.access_time, "Duration:", duration),
        const SizedBox(height: 8),
        _buildDashedLine(),
        const SizedBox(height: 8),
        _buildRowDetail(Icons.stop_circle_outlined, "End:", end),
        const SizedBox(height: 20),
        _buildDivider(),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildRowDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 22),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildDashedLine() {
    return Row(
      children: List.generate(
        40,
        (index) => Expanded(
          child: Container(
            color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade400,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: double.infinity,
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem('lib/Asset/Icons/Location.png', "Track", false),
          _buildNavItem('lib/Asset/Icons/history.png', "History", true),
          _buildNavItem('lib/Asset/Icons/notification.png', "Alerts", false),
          _buildNavItem('lib/Asset/Icons/statistics.png', "Statistics", false),
        ],
      ),
    );
  }

  Widget _buildNavItem(String assetPath, String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (label == 'Track') Get.toNamed(Routes.TRACK);
        if (label == 'Alerts') Get.toNamed(Routes.ALERTS);
        if (label == 'Statistics') Get.toNamed(Routes.STATISTICS);
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              assetPath,
              width: 25,
              height: 25,
              color: isSelected ? const Color(0xFF009FE3) : Colors.black,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF009FE3) : Colors.black,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
