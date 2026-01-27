import 'package:airotrack/Screens/modules/location/controllers/location_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LocationView extends GetView<LocationController> {
  const LocationView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Real Google Map Background
          // 1. Google Map Background (Hidden as requested)
          Container(
            color: Colors.grey[200],
            width: double.infinity,
            height: double.infinity,
          ),

          // 2. Top Left: Map Style Button
          Positioned(
            top: 50,
            left: 15,
            child: _buildFloatingButton(
              const AssetImage('lib/Asset/Icons/map.png'),
              onTap: () {},
              isLarge: true,
            ),
          ),

          // 3. Top Right: Controls Group
          Positioned(
            top: 50,
            right: 15,
            child: Column(
              children: [
                _buildFloatingButton(
                  const AssetImage('lib/Asset/Icons/Filters.png'),
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  const AssetImage('lib/Asset/Icons/Zoom.png'),
                  onTap: controller.centerOnVehicle,
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  const AssetImage('lib/Asset/Icons/Traffic.png'),
                  onTap: controller.toggleTraffic,
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  const AssetImage('lib/Asset/Icons/Refresh.png'),
                  onTap: () {},
                ),
              ],
            ),
          ),

          // 4. Side Arrows
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

          // 5. Vehicle Marker (Centered Overlay)
          // In a real implementation with many vehicles, we would use Markers[] in GoogleMap.
          // For the requested UI specific look, we overlay the custom card at the center.
          /* Center(
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
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
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
                const SizedBox(height: 4),
                Image.network(
                  'https://png.pngtree.com/png-vector/20230210/ourmid/pngtree-green-car-top-view-png-image_6593570.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ), */

          // 6. Bottom Right: Navigation Controls
          Positioned(
            bottom: 130,
            right: 15,
            child: Column(
              children: [
                _buildFloatingButton(
                  const AssetImage('lib/Asset/Icons/Locations.png'),
                  onTap: controller.centerOnVehicle,
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  const AssetImage('lib/Asset/Icons/zoomin.png'),
                  onTap: controller.zoomIn,
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  const AssetImage('lib/Asset/Icons/zoomout.png'),
                  onTap: controller.zoomOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton(
    AssetImage image, {
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    return Container(
      width: isLarge ? 42.0 : 35.12,
      height: isLarge ? 42.0 : 35.12,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Image(
              image: image,
              color: Colors.black87,
              width: isLarge ? 22 : 18,
              height: isLarge ? 22 : 18,
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
        color: Colors.black.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(child: Icon(icon, color: Colors.black, size: 30)),
    );
  }
}
