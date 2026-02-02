import 'package:flutter/material.dart';

import 'package:get/get.dart';
import '../controllers/alerts_controller.dart';
import '../../../routes/app_routes.dart';

class AlertsView extends GetView<AlertsController> {
  const AlertsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Alerts',
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
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'lib/Asset/Icons/download.png',
              height: 28,
              width: 28,
            ),
            // Placeholder for the green/blue arrow icon
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 13.97, right: 13.97),
            child: Row(
              children: [
                Container(
                  width: 297,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: "Search Alerts",
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      suffixIcon: Icon(Icons.search, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 45,
                  width: 45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'lib/Asset/Icons/Filters.png',
                      width: 22,
                      height: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // List of Alerts
          Expanded(
            child: Obx(
              () => ListView.builder(
                controller: controller.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount:
                    controller.alerts.length +
                    (controller.isLoading.value && controller.hasMore.value
                        ? 1
                        : 0),
                itemBuilder: (context, index) {
                  if (index < controller.alerts.length) {
                    return _buildAlertTile(context, index);
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
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem('lib/Asset/Icons/Location.png', "Track", false),
            _buildNavItem('lib/Asset/Icons/history.png', "History", false),
            _buildNavItem('lib/Asset/Icons/notification.png', "Alerts", true),
            _buildNavItem(
              'lib/Asset/Icons/statistics.png',
              "Statistics",
              false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTile(BuildContext context, int index) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isIgnitionOn = index % 2 == 0;
    return Container(
      width: screenWidth - 32,
      height: 64, // From Reminder Page dimensions
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Power Icon
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.asset(
              'lib/Asset/Icons/power.png',
              width: 24,
              height: 24,
              color: isIgnitionOn
                  ? const Color(0xFF00C853)
                  : const Color(0xFFD50000), // Green for On, Red for Off
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "KL 07 D 0518",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      "Oct 17, 2025 5:38:08 PM",
                      style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    ),
                  ],
                ),
                Text(
                  isIgnitionOn ? "Ignition On" : "Ignition Off",
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  "PuthiyakavuJunction, Karunagappalli...",
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String assetPath, String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (label == 'Statistics') {
          Get.toNamed(Routes.STATISTICS);
        } else if (label == 'History') {
          Get.toNamed(Routes.HISTORY);
        } else if (label == 'Track') {
          Get.toNamed(Routes.TRACK);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            assetPath,
            width: 24,
            height: 24,
            color: isSelected ? const Color(0xFF009FE3) : Colors.black,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF009FE3) : Colors.black,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
