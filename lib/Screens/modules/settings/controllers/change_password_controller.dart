import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChangePasswordController extends GetxController {
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final RxBool obscureOld = true.obs;
  final RxBool obscureNew = true.obs;
  final RxBool obscureConfirm = true.obs;
  final isLoading = false.obs;

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

  Future<void> changePassword() async {
    if (!validate()) return;
    try {
      isLoading.value = true;
      await ensureApiToken();
      final response = await DioClient().post(
        ApiEndPoints.changePassword,
        body: {
          'current_password': oldPasswordController.text.trim(),
          'password': newPasswordController.text.trim(),
          'password_confirmation': confirmPasswordController.text.trim(),
        },
      );

      final ok = response.data == null ||
          response.data['status'] == true ||
          response.data['success'] == true ||
          response.statusCode == 200;

      if (ok) {
        Get.back();
        Get.snackbar(
          'Success',
          response.data is Map && response.data['message'] != null
              ? response.data['message'].toString()
              : 'Password changed successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        showErrorMessage(
          response.data is Map
              ? (response.data['message'] ?? 'Failed to change password')
              : 'Failed to change password',
        );
      }
    } catch (e) {
      showErrorMessage(e);
    } finally {
      isLoading.value = false;
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
