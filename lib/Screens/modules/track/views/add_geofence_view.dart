import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/track_controller.dart';
import '../../../../widgets/map_widget.dart';
import '../../../routes/app_routes.dart';

class AddGeofenceView extends GetView<TrackController> {
  const AddGeofenceView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Map Background
          const MapWidget(),
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

              // zoom controls
              Positioned(
                top: 335.38,
                left: 347.38,
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

          // 2. Form Content
          Positioned(
            top: 450,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
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
                    const SizedBox(height: 25),
                    const Text(
                      "Fence Name",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 358,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: controller.fenceNameController,
                        decoration: const InputDecoration(
                          hintText: "Enter Fence Name",
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    Obx(
                      () => controller.fenceNameError.value.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                controller.fenceNameError.value,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildRadioOption("Circular", true),
                        const SizedBox(width: 30),
                        _buildRadioOption("Polygon", false),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      "Add location",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Get.toNamed(Routes.ADD_LOCATION_PICKER),
                      child: Container(
                        width: 358,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: IgnorePointer(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: "Search Location",
                                    hintStyle: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 15),
                              child: Icon(
                                Icons.search,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionBtn("Cancel", false, () => Get.back()),
                        _buildActionBtn(
                          "Submit",
                          true,
                          () => controller.submitFence(),
                        ),
                      ],
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

  Widget _buildRadioOption(String label, bool isSelected) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF009FE3), width: 1.5),
          ),
          child: isSelected
              ? Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF009FE3),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn(String label, bool isPrimary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        height: 45,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 30),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF009FE3) : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: isPrimary ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isPrimary ? Colors.white : Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
