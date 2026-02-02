import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../controllers/raise_ticket_controller.dart';

class RaiseTicketView extends GetView<RaiseTicketController> {
  const RaiseTicketView({Key? key}) : super(key: key);

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
          'Raise Ticket',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Select Vehicle Section
              const Text(
                'Select Vehicle',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 9),
              GestureDetector(
                onTap: () {
                  // Simulate vehicle selection
                  controller.selectedVehicle.value = 'KL 07 D 0518';
                },
                child: Container(
                  width: 358,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Obx(
                        () => Text(
                          controller.selectedVehicle.value.isEmpty
                              ? 'Select Vehicle'
                              : controller.selectedVehicle.value,
                          style: TextStyle(
                            color: controller.selectedVehicle.value.isEmpty
                                ? Colors.grey
                                : Colors.black,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Image.asset(
                        'lib/Asset/Icons/Down arrow.png',
                        width: 15,
                        height: 10,
                        color: Colors.blue.shade700,
                      ),
                    ],
                  ),
                ),
              ),
              Obx(
                () => controller.vehicleError.value.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          controller.vehicleError.value,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),
              // Type Section
              const Text(
                'Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 9),
              GestureDetector(
                onTap: () {
                  // Simulate type selection
                  controller.selectedType.value = 'General Issue';
                },
                child: Container(
                  width: 358,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Obx(
                        () => Text(
                          controller.selectedType.value.isEmpty
                              ? 'Select Ticket Type'
                              : controller.selectedType.value,
                          style: TextStyle(
                            color: controller.selectedType.value.isEmpty
                                ? Colors.grey
                                : Colors.black,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Image.asset(
                        'lib/Asset/Icons/Down arrow.png',
                        width: 15,
                        height: 10,
                        color: Colors.blue.shade700,
                      ),
                    ],
                  ),
                ),
              ),
              Obx(
                () => controller.typeError.value.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          controller.typeError.value,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),
              // Message Section
              const Text(
                'Message',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 9),
              Container(
                width: 358,
                height: 94,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: controller.messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Describe the issue in detail',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Obx(
                () => controller.messageError.value.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          controller.messageError.value,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),
              // Upload Image Section
              const Text(
                'Upload Image',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 9),
              Container(
                width: 107.25,
                height: 111.8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 30,
                      color: Colors.blue.shade300,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload Image',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              // Submit Button
              SizedBox(
                width: 359.54,
                height: 45,
                child: ElevatedButton(
                  onPressed: controller.submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009FE3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {},
            child: Image.asset(
              'lib/Asset/Icons/call chat.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {},
            child: Image.asset(
              'lib/Asset/Icons/whatsapp chat.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
