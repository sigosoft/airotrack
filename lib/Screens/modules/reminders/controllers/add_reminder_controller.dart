import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AddReminderController extends GetxController {
  final odometerController = TextEditingController();
  final periodController = TextEditingController();

  final odometerError = ''.obs;
  final periodError = ''.obs;

  bool validate() {
    bool isValid = true;
    if (odometerController.text.trim().isEmpty) {
      odometerError.value = 'Starting odometer is required';
      isValid = false;
    } else {
      odometerError.value = '';
    }

    if (periodController.text.trim().isEmpty) {
      periodError.value = 'Odometer period is required';
      isValid = false;
    } else {
      periodError.value = '';
    }
    return isValid;
  }

  void submit() {
    if (validate()) {
      Get.back();
      Get.snackbar(
        'Success',
        'Reminder added successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  @override
  void onClose() {
    odometerController.dispose();
    periodController.dispose();
    super.onClose();
  }
}
