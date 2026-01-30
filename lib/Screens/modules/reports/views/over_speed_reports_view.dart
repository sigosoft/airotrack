import 'package:airotrack/Screens/widgets/pagination_widget.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

class OverSpeedReportsView extends StatelessWidget {
  const OverSpeedReportsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 22),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Over Speed Reports',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'lib/Asset/Icons/download.png',
              width: 32,
              height: 32,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search Vehicles",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        contentPadding: EdgeInsets.only(bottom: 12),
                      ),
                    ),
                  ),
                  const Icon(Icons.search, color: Colors.grey, size: 24),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
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
          // List of Tiles
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.31,
                vertical: 10,
              ),
              itemCount: 6,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildOverSpeedTile(context);
              },
            ),
          ),
          // Pagination Widget
          PaginationWidget(
            currentPage: 1,
            totalPages: 5,
            onPageChanged: (page) {
              // Handle page change
            },
          ),
        ],
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

  Widget _buildOverSpeedTile(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth - 32.62,
      height: 95,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'lib/Asset/Icons/Car.png',
                width: 22,
                height: 20,
                color: const Color(0xFF009FE3),
              ),
              const SizedBox(width: 8),
              const Text(
                'KL 07 D 0518',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Image.asset(
                    'lib/Asset/Icons/Speed.png',
                    width: 30,
                    height: 24,
                    color: Colors.black,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                  const Text(
                    '55.00 kmph',
                    style: TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Image.asset(
                'lib/Asset/Icons/Time.png',
                width: 14,
                height: 14,
                color: const Color(0xFFFF5252),
              ),
              const SizedBox(width: 6),
              const Text(
                'Oct 17, 2025 05:38:08 PM',
                style: TextStyle(
                  fontSize: 9,
                  color: Color.fromARGB(255, 110, 109, 109),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Image.asset(
                'lib/Asset/Icons/location outlined.png',
                width: 14,
                height: 14,
                color: const Color(0xFFFF5252),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'PuthiyakavuJunction,Karunagappalli, Kerala 690539, India',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color.fromARGB(255, 110, 109, 109),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
