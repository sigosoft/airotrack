import 'package:airotrack/Screens/widgets/pagination_widget.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import '../../../routes/app_routes.dart';

class ExpensesView extends StatelessWidget {
  const ExpensesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Expenses',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 20),
            child: RichText(
              text: const TextSpan(
                style: TextStyle(color: Colors.black),
                children: [
                  TextSpan(text: 'Total: ', style: TextStyle(fontSize: 14)),
                  TextSpan(
                    text: '1500 INR',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 15),
                // Search Bar
                Container(
                  width: 356.6,
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search Vehicles',
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      Icon(Icons.search, color: Colors.grey.shade400, size: 28),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Filter Days Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDayButton('Today', isSelected: true),
                    _buildDayButton('Yesterday'),
                    _buildDayButton('Week'),
                    _buildDayButton('Month'),
                    Image.asset(
                      'lib/Asset/Icons/Calender.png',
                      width: 25,
                      height: 25,
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                // Expense List
                Expanded(
                  child: ListView.builder(
                    itemCount: 4,
                    itemBuilder: (context, index) => _buildExpenseTile(context),
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
                const SizedBox(height: 80), // Space for floating button
              ],
            ),
          ),
          Positioned(
            bottom: 30, // Adjusting based on user "top 745" approx
            right: 16.5,
            child: FloatingActionButton(
              onPressed: () => Get.toNamed(Routes.ADD_EXPENSE),
              backgroundColor: const Color(0xFF009FE3),
              shape: const CircleBorder(),
              elevation: 4,
              child: const Icon(Icons.add, color: Colors.white, size: 35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayButton(String label, {bool isSelected = false}) {
    return Container(
      width: 72.2,
      height: 26.89,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF009FE3) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? const Color(0xFF009FE3) : Colors.grey.shade300,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseTile(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: screenWidth - 32,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Text(
                        'KL 07 D 0518',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 30),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1EFFF),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Text(
                          'Food',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '500 INR',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '18-10-2025 10:40 Am',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      children: [
                        TextSpan(text: 'Payment: '),
                        TextSpan(
                          text: 'Online',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 55.32,
              height: 76.95,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                image: const DecorationImage(
                  image: AssetImage('lib/Asset/Icons/Expenses.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
