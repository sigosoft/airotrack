import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/ProfileModel.dart';
import 'package:airotrack/Screens/modules/settings/controllers/settings_controller.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EditProfileController extends GetxController {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final companyController = TextEditingController();

  final nameError = ''.obs;
  final phoneError = ''.obs;
  final companyError = ''.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final avatarInitial = 'U'.obs;

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      isLoading.value = true;
      await ensureApiToken();
      final response = await DioClient().get(ApiEndPoints.profile);
      if (response.data != null) {
        final data = response.data['data'] ?? response.data;
        final profile = ProfileModel.fromJson(data);
        nameController.text = profile.name;
        phoneController.text = profile.mobile;
        companyController.text = profile.companyName;
        avatarInitial.value = profile.avatarInitial;
      }
    } catch (e) {
      showErrorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }

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

    companyError.value = '';
    return isValid;
  }

  Future<void> saveProfile() async {
    if (!validate()) return;
    try {
      isSaving.value = true;
      await ensureApiToken();
      final response = await DioClient().post(
        ApiEndPoints.updateProfile,
        body: {
          'name': nameController.text.trim(),
          'company_name': companyController.text.trim(),
          'mobile': phoneController.text.trim(),
        },
      );

      final ok = response.data == null ||
          response.data['status'] == true ||
          response.data['success'] == true ||
          response.statusCode == 200;

      if (ok) {
        if (Get.isRegistered<SettingsController>()) {
          await Get.find<SettingsController>().loadProfile();
        }
        Get.back();
        Get.snackbar(
          'Success',
          response.data is Map && response.data['message'] != null
              ? response.data['message'].toString()
              : 'Profile updated successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        showErrorMessage(
          response.data is Map
              ? (response.data['message'] ?? 'Failed to update profile')
              : 'Failed to update profile',
        );
      }
    } catch (e) {
      showErrorMessage(e);
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    companyController.dispose();
    super.onClose();
  }
}
