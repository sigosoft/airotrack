import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeleteAccountController extends GetxController {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final RxBool obscurePassword = true.obs;
  final phoneError = ''.obs;
  final passwordError = ''.obs;

  void toggleObscure() => obscurePassword.value = !obscurePassword.value;

  bool validate() {
    bool isValid = true;
    if (phoneController.text.isEmpty) {
      phoneError.value = 'Phone number is required';
      isValid = false;
    } else {
      phoneError.value = '';
    }

    if (passwordController.text.isEmpty) {
      passwordError.value = 'Password is required to delete account';
      isValid = false;
    } else {
      passwordError.value = '';
    }
    return isValid;
  }

  void deleteAccount() {
    if (validate()) {
      // Logic for account deletion
      Get.back();
      // Usually would navigate somewhere else like Routes.WELCOME
      Get.snackbar(
        'Account Deleted',
        'Your account has been deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  void onClose() {
    phoneController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
