import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TrackController extends GetxController {
  final RxInt selectedBottomTabIndex = 0.obs;
  final RxBool showBottomSheet = false.obs;
  final RxString selectedShareOption = 'Only Once'.obs;

  final fenceNameController = TextEditingController();
  final fenceNameError = ''.obs;

  void toggleBottomSheet() {
    showBottomSheet.value = !showBottomSheet.value;
  }

  void updateShareOption(String option) {
    selectedShareOption.value = option;
  }

  void changeBottomTab(int index) {
    selectedBottomTabIndex.value = index;
  }

  bool validateFence() {
    if (fenceNameController.text.trim().isEmpty) {
      fenceNameError.value = 'Fence name is required';
      return false;
    }
    fenceNameError.value = '';
    return true;
  }

  void submitFence() {
    if (validateFence()) {
      Get.back();
      Get.snackbar(
        'Success',
        'Geofence added successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  @override
  void onClose() {
    fenceNameController.dispose();
    super.onClose();
  }
}
