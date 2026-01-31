import 'package:flutter/material.dart';

import 'package:get/get.dart';
import '../controllers/reports_controller.dart';

class SummaryReportsView extends GetView<ReportsController> {
  const SummaryReportsView({Key? key}) : super(key: key);

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
          'Summary Reports',
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
            child: Obx(
              () => ListView.separated(
                controller: controller.scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.31,
                  vertical: 10,
                ),
                itemCount:
                    controller.items.length +
                    (controller.isLoading.value && controller.hasMore.value
                        ? 1
                        : 0),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index < controller.items.length) {
                    return _buildSummaryTile(context);
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

  Widget _buildSummaryTile(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth - 32.62, // Responsive width
      padding: const EdgeInsets.all(14),
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
          // Header Row
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
              Image.asset('lib/Asset/Icons/Route.png', width: 14, height: 14),
              const SizedBox(width: 4),
              const Text(
                '2.65 Km',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                'Engine Hour',
                '00:38:41h',
                const Color(0xFFFF6F00),
              ),
              _buildStatItem('Running', '00:38:41h', const Color(0xFF00C853)),
              _buildStatItem('Stoped', '00:38:41h', const Color(0xFFFF5252)),
              _buildStatItem('Idle', '00:38:41h', const Color(0xFFFFC107)),
            ],
          ),
          const SizedBox(height: 10),
          // Dotted Line
          _buildDottedLine(),
          const SizedBox(height: 10),
          // Locations with vertical line alignment
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 13,
                      height: 13,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C853),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Container(width: 1, color: Colors.grey.shade300),
                    ),
                    Container(
                      width: 13,
                      height: 13,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3D00),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PuthiyakavuJunction,Karunagappalli, Kerala 690539, India',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Color.fromARGB(255, 110, 109, 109),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      // Trip IDs Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '000036345',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF00C853),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Image.asset(
                            'lib/Asset/Icons/Line.png',
                            width: 45,
                            height: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '000036361',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFFF3D00),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'PuthiyakavuJunction,Karunagappalli, Kerala 690539, India',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Color.fromARGB(255, 110, 109, 109),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Dotted Line
          _buildDottedLine(),
          const SizedBox(height: 10),
          // Speed Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'lib/Asset/Icons/Distance.png',
                        width: 18,
                        height: 18,
                        color: const Color(0xFF009FE3),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Avg Speed: ',
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                      const Text(
                        '25.10 kmph',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'lib/Asset/Icons/Max Distance.png',
                        width: 18,
                        height: 18,
                        color: const Color(0xFFFF5252),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Max Speed: ',
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                      const Text(
                        '52.10 kmph',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(width: 65, height: 2, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDottedLine() {
    return SizedBox(
      width: double.infinity,
      height: 1,
      child: CustomPaint(painter: DottedLinePainter()),
    );
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
