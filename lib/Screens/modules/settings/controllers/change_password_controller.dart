import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChangePasswordController extends GetxController {
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final RxBool obscureOld = true.obs;
  final RxBool obscureNew = true.obs;
  final RxBool obscureConfirm = true.obs;

  final oldPasswordError = ''.obs;
  final newPasswordError = ''.obs;
  final confirmPasswordError = ''.obs;

  void toggleOld() => obscureOld.value = !obscureOld.value;
  void toggleNew() => obscureNew.value = !obscureNew.value;
  void toggleConfirm() => obscureConfirm.value = !obscureConfirm.value;

  bool validate() {
    bool isValid = true;
    if (oldPasswordController.text.isEmpty) {
      oldPasswordError.value = 'Old password is required';
      isValid = false;
    } else {
      oldPasswordError.value = '';
    }

    if (newPasswordController.text.isEmpty) {
      newPasswordError.value = 'New password is required';
      isValid = false;
    } else if (newPasswordController.text.length < 6) {
      newPasswordError.value = 'Password must be at least 6 characters';
      isValid = false;
    } else {
      newPasswordError.value = '';
    }

    if (confirmPasswordController.text != newPasswordController.text) {
      confirmPasswordError.value = 'Passwords do not match';
      isValid = false;
    } else {
      confirmPasswordError.value = '';
    }

    return isValid;
  }

  void changePassword() {
    if (validate()) {
      Get.back();
      Get.snackbar(
        'Success',
        'Password changed successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  @override
  void onClose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
