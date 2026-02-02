import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EditProfileController extends GetxController {
  final nameController = TextEditingController(text: "John Doe");
  final phoneController = TextEditingController(text: "+91 91234 56789");

  final nameError = ''.obs;
  final phoneError = ''.obs;

  bool validate() {
    bool isValid = true;
    if (nameController.text.trim().isEmpty) {
      nameError.value = 'Name is required';
      isValid = false;
    } else {
      nameError.value = '';
    }

    if (phoneController.text.trim().isEmpty) {
      phoneError.value = 'Phone number is required';
      isValid = false;
    } else {
      phoneError.value = '';
    }
    return isValid;
  }

  void saveProfile() {
    if (validate()) {
      Get.snackbar(
        'Success',
        'Profile updated successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      Get.back();
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    super.onClose();
  }
}
