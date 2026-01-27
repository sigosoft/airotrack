import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../modules/home/controllers/home_controller.dart';

class CustomBottomNavBar extends GetView<HomeController> {
  const CustomBottomNavBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> navItems = [
      {'label': 'Dashboard', 'icon': 'lib/Asset/Icons/Dashboard.png'},
      {'label': 'Home', 'icon': 'lib/Asset/Icons/Car.png'},
      {'label': 'Location', 'icon': 'lib/Asset/Icons/Location.png'},
      {'label': 'Reports', 'icon': 'lib/Asset/Icons/Reports.png'},
      {'label': 'Settings', 'icon': 'lib/Asset/Icons/Settings.png'},
    ];

    return Obx(() {
      final int selectedIndex = controller.selectedIndex.value;
      final double width = MediaQuery.of(context).size.width;
      final double itemWidth = width / navItems.length;
      final double notchCenter = (selectedIndex + 0.5) * itemWidth;

      return Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Background with Notch
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 88,
            child: CustomPaint(
              size: Size(width, 88),
              painter: BottomNavPainter(notchCenter: notchCenter),
            ),
          ),

          // Icons and Labels
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected = selectedIndex == index;

                return GestureDetector(
                  onTap: () => controller.changeTab(index),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: itemWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon hidden when selected because it moves to the circle
                        Opacity(
                          opacity: isSelected ? 0.0 : 1.0,
                          child: ImageIcon(
                            AssetImage(item['icon']!),
                            size: 25,
                            color: const Color.fromARGB(255, 192, 189, 189),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Label stays in navbar
                        Text(
                          item['label']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected
                                ? Colors.white
                                : const Color.fromARGB(255, 210, 206, 206),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // The Selected Item (Floating Circle)
          Positioned(
            bottom:
                30, // Reduced from 25 to 15 to bring it closer to the shallower notch
            left: notchCenter - 35,
            child: GestureDetector(
              onTap: () => controller.changeTab(selectedIndex),
              child: Container(
                width: 70,
                height: 70,
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF009FE3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: ImageIcon(
                      AssetImage(navItems[selectedIndex]['icon']!),
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class BottomNavPainter extends CustomPainter {
  final double notchCenter;

  BottomNavPainter({required this.notchCenter});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = const Color(0xFF009FE3)
      ..style = PaintingStyle.fill;

    Path path = Path();
    var h = size.height;
    var w = size.width;

    // Start at top left (shifted down by 20 to allow for the notch area)
    path.moveTo(0, 20);

    double notchRadius = 38;

    // Line to the start of the notch
    path.lineTo(notchCenter - notchRadius - 10, 20);

    // Left curve of the notch
    path.cubicTo(
      notchCenter - notchRadius,
      25,
      notchCenter - notchRadius,
      60, //Reduced from 70 to 60 for shallower notch
      notchCenter,
      60, // Reduced from 70 to 60 for shallower notch
    );
    // Right curve of the notch
    path.cubicTo(
      notchCenter + notchRadius,
      60, // Reduced from 70 to 60 for shallower notch
      notchCenter + notchRadius,
      20,
      notchCenter + notchRadius + 10,
      20,
    );

    // Line to top right
    path.lineTo(w, 20);
    // Down to bottom right
    path.lineTo(w, h + 50); // Added extra height to ensure it covers the bottom
    // To bottom left
    path.lineTo(0, h + 50);
    // Back to start
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BottomNavPainter oldDelegate) {
    return oldDelegate.notchCenter != notchCenter;
  }
}
