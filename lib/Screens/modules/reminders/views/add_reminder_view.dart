import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/add_reminder_controller.dart';

class AddReminderView extends GetView<AddReminderController> {
  const AddReminderView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Add Reminder',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Select Type
                const Text(
                  "Select Type",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 359,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      8,
                    ), // Assumed radius based on look, inputs usually smaller radius
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Select Reminder Type",
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF009FE3),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Start
                const Text(
                  "Start",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 359,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller.odometerController,
                    decoration: const InputDecoration(
                      hintText: "Enter Starting Odometer",
                      hintStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ), // Colors.grey defaults to a shade around 500, check if needs lighter
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12, // Adjusted for alignment
                      ), // Centered vertically in 40px
                    ),
                    style: const TextStyle(fontSize: 13),
                    keyboardType: TextInputType.number,
                  ),
                ),
                Obx(
                  () => controller.odometerError.value.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            controller.odometerError.value,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Period
                const Text(
                  "Period",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 359,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller.periodController,
                    decoration: const InputDecoration(
                      hintText: "Enter the Odometer Period for Alerts",
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12, // Adjusted for alignment
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                    keyboardType: TextInputType.number,
                  ),
                ),
                Obx(
                  () => controller.periodError.value.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            controller.periodError.value,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // Submit Button
          Positioned(
            left: 16,
            bottom:
                30, // Using bottom positioning for responsiveness, although user said top 680px. 680px is quite far down on typical screens. Safest to dock bottom or use high margin.
            child: GestureDetector(
              onTap: controller.submit,
              child: Container(
                width: 358,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFF009FE3),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  "Submit",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
