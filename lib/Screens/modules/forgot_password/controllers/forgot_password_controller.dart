import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';

class ForgotPasswordController extends GetxController {
  final phoneController = TextEditingController();
  var phoneError = ''.obs;

  bool validate() {
    if (phoneController.text.trim().isEmpty) {
      phoneError.value = 'Phone number is required';
      return false;
    } else if (phoneController.text.length < 10) {
      phoneError.value = 'Please enter a valid phone number';
      return false;
    }
    phoneError.value = '';
    return true;
  }

  void sendCode() {
    if (validate()) {
      Get.toNamed(Routes.OTP_VERIFICATION);
    }
  }

  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }
}
