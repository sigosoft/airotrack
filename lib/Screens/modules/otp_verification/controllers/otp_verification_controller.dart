import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';

class OTPVerificationController extends GetxController {
  final otpControllers = List.generate(4, (_) => TextEditingController());
  var otpError = ''.obs;

  bool validate() {
    String otp = otpControllers.map((e) => e.text).join();
    if (otp.length < 4) {
      otpError.value = 'Please enter complete OTP';
      return false;
    }
    otpError.value = '';
    return true;
  }

  void verify() {
    if (validate()) {
      Get.toNamed(Routes.RESET_PASSWORD);
    }
  }

  @override
  void onClose() {
    for (var controller in otpControllers) {
      controller.dispose();
    }
    super.onClose();
  }
}
