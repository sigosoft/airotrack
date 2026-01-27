import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/statistics_controller.dart';
import '../../../routes/app_routes.dart';

class StatisticsView extends GetView<StatisticsController> {
  const StatisticsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          onPressed: () => Get.back(),
        ),
        actions: [
          Container(
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
                const Text(
                  "KL 07 D 0518",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, color: Color(0xFF009FE3)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterTab("Today", true),
                const SizedBox(width: 8),
                _buildFilterTab("Yesterday", false),
                const SizedBox(width: 8),
                _buildFilterTab("Week", false),
                const SizedBox(width: 8),
                _buildFilterTab("Month", false),
                const SizedBox(width: 8),
                Image.asset(
                  'lib/Asset/Icons/Calender.png',
                  height: 28,
                  width: 28,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Statistics Cards
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'lib/Asset/Icons/Route_length.png',
                        "Route Length",
                        "100.13 km",
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        'lib/Asset/Icons/Move_duration.png',
                        "Move Duration",
                        "30:10:11",
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
                        "10:49:23",
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        'lib/Asset/Icons/Idle duration.png',
                        "Idle Duration",
                        "00:10:11",
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
                        "63 kmph",
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        'lib/Asset/Icons/Average speed.png',
                        "Average Speed",
                        "30.09 kmph",
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
                        "5",
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        'lib/Asset/Icons/stop_count.png',
                        "Stop Count",
                        "10",
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
                        "30:10:11",
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        'lib/Asset/Icons/Odometer.png',
                        "Odometer",
                        "5000 km",
                      ),
                    ),
                  ],
                ),
              ],
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
            _buildNavItem('lib/Asset/Icons/notification.png', "Alerts", false),
            _buildNavItem('lib/Asset/Icons/statistics.png', "Statistics", true),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String text, bool isSelected) {
    return Container(
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String assetPath, String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (label == 'Alerts') {
          Get.toNamed(Routes.ALERTS);
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
