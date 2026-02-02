import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RaiseTicketController extends GetxController {
  final RxString selectedVehicle = ''.obs;
  final RxString selectedType = ''.obs;
  final messageController = TextEditingController();

  final vehicleError = ''.obs;
  final typeError = ''.obs;
  final messageError = ''.obs;

  bool validate() {
    bool isValid = true;
    if (selectedVehicle.value.isEmpty) {
      vehicleError.value = 'Vehicle selection is required';
      isValid = false;
    } else {
      vehicleError.value = '';
    }

    if (selectedType.value.isEmpty) {
      typeError.value = 'Ticket type is required';
      isValid = false;
    } else {
      typeError.value = '';
    }

    if (messageController.text.trim().isEmpty) {
      messageError.value = 'Message is required';
      isValid = false;
    } else {
      messageError.value = '';
    }
    return isValid;
  }

  void submitTicket() {
    if (validate()) {
      Get.back();
      Get.snackbar(
        'Success',
        'Ticket raised successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  @override
  void onClose() {
    messageController.dispose();
    super.onClose();
  }
}
