import 'package:airotrack/Screens/widgets/pagination_widget.dart';
import 'package:airotrack/Screens/routes/app_routes.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/reminders_controller.dart';

class RemindersView extends GetView<RemindersController> {
  const RemindersView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Reminders',
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
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(
                  height: 20,
                ), // Adjust to match visual spacing ~114px from top including AppBar
                // Search Bar
                Container(
                  width: 358,
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
                      hintText: "Search Reminders",
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
                const SizedBox(height: 16),

                // List of Reminders
                Expanded(
                  child: ListView.builder(
                    itemCount: 5,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      return _buildReminderTile(context);
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
                const SizedBox(height: 80), // Space for FAB
              ],
            ),
          ),

          //... (in build method)

          // Floating Action Button
          Positioned(
            bottom:
                30, // Approx for pixel requests, ensuring it's on screen. User said Top 759, assumes specific screen height. Bottom alignment is safer.
            right:
                16, // User said 329 left on 393 width -> approx 16-20 from right
            child: GestureDetector(
              onTap: () => Get.toNamed(Routes.ADD_REMINDER),
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFF009FE3),
                  borderRadius: BorderRadius.circular(22.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderTile(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth - 32,
      height: 64,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
        children: [
          // Icon Car
          Image.asset(
            'lib/Asset/Icons/Car.png', // Assuming this asset exists from listing
            width: 24,
            height: 24,
            color: const Color(0xFF009FE3),
          ),
          const SizedBox(width: 12),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Oil Change",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Type: Oil Change",
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                Text(
                  "Period: 5000 km",
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Actions
          Column(
            children: [
              const SizedBox(height: 10),
              Image.asset(
                'lib/Asset/Icons/Edit.png',
                width: 15,
                height: 15,
                color: const Color(0xFF009FE3),
              ),
              const SizedBox(height: 5),
              Image.asset(
                'lib/Asset/Icons/Delete.png',
                width: 20,
                height: 20,
                color: const Color.fromARGB(255, 252, 90, 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
