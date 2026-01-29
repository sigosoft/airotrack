import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DailyReportsView extends StatelessWidget {
  const DailyReportsView({Key? key}) : super(key: key);

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
          'Daily Reports',
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
              itemCount: 2,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildDailyTile();
              },
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

  Widget _buildDailyTile() {
    return Container(
      width: 357,
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
              Image.asset(
                'lib/Asset/Icons/Route.png',
                width: 14,
                height: 14,
                // color: const Color(0xFFFF5252),
              ),
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
          const SizedBox(height: 8),
          // Time Row
          Row(
            children: [
              Image.asset(
                'lib/Asset/Icons/Time.png',
                width: 13,
                height: 13,
                color: const Color(0xFF00C853),
              ),
              const SizedBox(width: 6),
              const Text(
                'Oct 17, 2025 12:00:08 AM',
                style: TextStyle(
                  fontSize: 10,
                  color: Color.fromARGB(255, 110, 109, 109),
                ),
              ),
              const SizedBox(width: 20),
              Image.asset(
                'lib/Asset/Icons/Time.png',
                width: 13,
                height: 13,
                color: const Color(0xFFFF5252),
              ),
              const SizedBox(width: 6),
              const Text(
                'Oct 17, 2025 2:40:08 AM',
                style: TextStyle(
                  fontSize: 10,
                  color: Color.fromARGB(255, 110, 109, 109),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Dotted Line
          _buildDottedLine(),
          const SizedBox(height: 10),
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
              _buildStatItem('Stopped', '00:38:41h', const Color(0xFFFF3D00)),
              _buildStatItem(
                'Idle',
                '00:38:41h',
                const Color.fromARGB(255, 186, 169, 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Dotted Line
          _buildDottedLine(),
          const SizedBox(height: 10),
          // Start Location with vertical line alignment
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C853),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Container(width: 2, color: Colors.grey.shade300),
                    ),
                    Container(
                      width: 11,
                      height: 11,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3D00),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Puthiyakavu Junction, Karunagappalli, Kerala 690539, India',
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Trip IDs Row with double arrow
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(4),
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
                            const SizedBox(width: 8),
                            Image.asset(
                              'lib/Asset/Icons/Line.png',
                              width: 65,
                              height: 20,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(4),
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
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Puthiyakavu Junction, Karunagappalli, Kerala 690539, India',
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
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
          // Speed Row with shadow cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'lib/Asset/Icons/Distance.png',
                        width: 16,
                        height: 16,
                        color: const Color(0xFF009FE3),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Avg Speed: ',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const Text(
                        '25.10 kmph',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'lib/Asset/Icons/Max Distance.png',
                        width: 16,
                        height: 16,
                        color: const Color(0xFFFF5252),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Max Speed: ',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const Text(
                        '52.10 kmph',
                        style: TextStyle(
                          fontSize: 10,
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
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Container(width: 60, height: 2, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            // color: color,
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
      ..color = Color.fromARGB(255, 137, 137, 137)
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
