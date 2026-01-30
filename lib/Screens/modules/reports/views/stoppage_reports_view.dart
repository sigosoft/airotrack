import 'package:airotrack/Screens/widgets/pagination_widget.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

class StoppageReportsView extends StatelessWidget {
  const StoppageReportsView({Key? key}) : super(key: key);

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
          'Stoppage Reports',
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
                return _buildStoppageTile(context);
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

  Widget _buildStoppageTile(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth - 32.62,
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                color: const Color(0xFFFF3D00), // Red car
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
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  children: [
                    const TextSpan(text: 'Duration: '),
                    TextSpan(
                      text: '02h 40m',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Image.asset(
                'lib/Asset/Icons/Time.png',
                width: 12,
                height: 12,
                color: const Color(0xFF00C853), // Green start time
              ),
              const SizedBox(width: 6),
              const Text(
                'Oct 17, 2025 12:00:08 AM',
                style: TextStyle(fontSize: 9, color: Colors.grey),
              ),
              const SizedBox(width: 20),
              Image.asset(
                'lib/Asset/Icons/Time.png',
                width: 12,
                height: 12,
                color: const Color(0xFFFF5252), // Red end time
              ),
              const SizedBox(width: 6),
              const Text(
                'Oct 17, 2025 2:40:08 AM',
                style: TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Image.asset(
                'lib/Asset/Icons/location outlined.png',
                width: 12,
                height: 12,
                color: const Color(0xFFFF5252),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Puthiyakavu Junction, Karunagappalli, Kerala 690539, India',
                  style: TextStyle(fontSize: 9, color: Colors.grey[700]),
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
