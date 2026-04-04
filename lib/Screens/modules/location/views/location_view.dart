import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../widgets/map_widget.dart';
import '../controllers/location_controller.dart';

class LocationView extends GetView<LocationController> {
  const LocationView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AiroMapWidget(),
          Positioned(
            top: 45,
            left: 15,
            child: _buildFloatingButton(
              'lib/Asset/Icons/map.png',
              onTap: () {},
            ),
          ),
          Positioned(
            top: 45,
            right: 15,
            child: Column(
              children: [
                _buildFloatingButton(
                  'lib/Asset/Icons/Filters.png',
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _buildFloatingButton('lib/Asset/Icons/Zoom.png', onTap: () {}),
                const SizedBox(height: 10),
                _buildFloatingButton(
                  'lib/Asset/Icons/Traffic.png',
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _buildFloatingButton(
                  'lib/Asset/Icons/Refresh.png',
                  onTap: () {},
                ),
              ],
            ),
          ),
          Positioned(
            left: 5,
            top: MediaQuery.of(context).size.height * 0.45,
            child: _buildSideArrow(Icons.chevron_left),
          ),
          Positioned(
            right: 5,
            top: MediaQuery.of(context).size.height * 0.45,
            child: _buildSideArrow(Icons.chevron_right),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    "KL 07 A 0518",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Image.asset(
                  'lib/Asset/Images/Green right Car.png',
                  width: 55,
                  height: 55,
                  // color: const Color(0xFF00C853), // Green
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 130,
            right: 15,
            child: Column(
              children: [
                _buildFloatingButton(
                  'lib/Asset/Icons/Locations.png',
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _buildFloatingButton(
                  'lib/Asset/Icons/zoomin.png',
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _buildFloatingButton(
                  'lib/Asset/Icons/zoomout.png',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton(String iconPath, {required VoidCallback onTap}) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Center(
            child: Image.asset(
              iconPath,
              width: 20,
              height: 20,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideArrow(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(icon, color: Colors.black.withOpacity(0.7), size: 32),
      ),
    );
  }
}
