import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/track_controller.dart';
import '../../../../widgets/map_widget.dart';

class AddLocationPickerView extends GetView<TrackController> {
  const AddLocationPickerView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Map Background
          AiroMapWidget(),
          Stack(
            children: [
              // Top Left: Back Button
              Positioned(
                top: 50,
                left: 16,
                child: GestureDetector(
                  onTap: () => Get.back(),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 24,
                    color: Colors.black,
                  ),
                ),
              ),
              // Search Bar
              Positioned(
                top: 90,
                left: 16,
                right: 16,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 20),
                      const Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Search Location",
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Icon(
                          Icons.search,
                          color: Colors.grey.shade400,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Center Pin (Simulated)
              const Center(
                child: Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
              // Zoom Controls (Visual only based on previous screens)
              Positioned(
                top: 400, // Adjusted
                right: 16,
                child: Column(
                  children: [
                    _buildZoomBtn(Icons.add),
                    const SizedBox(height: 7),
                    _buildZoomBtn(Icons.remove),
                  ],
                ),
              ),
            ],
          ),

          // 2. Bottom Sheet Container
          Positioned(
            top: 499,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height:
                  345, // Although constrained by bottom: 0, the content will drive height
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(29),
                  topRight: Radius.circular(29),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 26),
                    // Use Current Location
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: GestureDetector(
                        onTap: () {
                          // Action for current location
                        },
                        child: Container(
                          width: 330,
                          height: 44,
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE3F2FD), // Light blue circle
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.near_me,
                                  color: Color(0xFF009FE3),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 15),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Use Current Location",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      "GPS location",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 15),
                    // Radius Slider Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 17),
                      child: Container(
                        width: 357,
                        height: 137,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  "Radius",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  "500m",
                                  style: TextStyle(
                                    color: Color(0xFF009FE3),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                _buildCircleBtn(Icons.remove),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: const Color(0xFF009FE3),
                                      inactiveTrackColor: Colors.grey.shade300,
                                      thumbColor: const Color(0xFF009FE3),
                                      trackHeight: 4,
                                      overlayShape:
                                          SliderComponentShape.noOverlay,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 8,
                                      ),
                                    ),
                                    child: Slider(
                                      value: 500,
                                      min: 100,
                                      max: 5000,
                                      onChanged: (val) {},
                                    ),
                                  ),
                                ),
                                _buildCircleBtn(Icons.add),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  "100",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "5000",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    // Confirm Location Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () {
                          // Confirm logic
                          Get.back(); // Assuming it returns location
                        },
                        child: Container(
                          width: 358,
                          height: 45,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF009FE3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            "Confirm Location",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomBtn(IconData icon) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Icon(icon, color: Colors.black87, size: 20),
    );
  }

  Widget _buildCircleBtn(IconData icon) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(icon, size: 16, color: Colors.grey.shade600),
    );
  }
}
