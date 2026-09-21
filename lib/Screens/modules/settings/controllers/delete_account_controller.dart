import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../routes/app_routes.dart';

class DeleteAccountController extends GetxController {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final RxBool obscurePassword = true.obs;
  final phoneError = ''.obs;
  final passwordError = ''.obs;
  final isLoading = false.obs;

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

  Future<void> deleteAccount() async {
    if (!validate()) return;
    try {
      isLoading.value = true;
      await ensureApiToken();
      final response = await DioClient().post(
        ApiEndPoints.deleteAccount,
        body: {
          'mobile': phoneController.text.trim(),
          'password': passwordController.text.trim(),
        },
      );

      final ok = response.data == null ||
          response.data['status'] == true ||
          response.data['success'] == true ||
          response.statusCode == 200;

      if (ok) {
        await _clearSession();
        Get.offAllNamed(Routes.DELETE_SUCCESS);
      } else {
        showErrorMessage(
          response.data is Map
              ? (response.data['message'] ?? 'Failed to delete account')
              : 'Failed to delete account',
        );
      }
    } catch (e) {
      showErrorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _clearSession() async {
    try {
      if (!Hive.isBoxOpen('userBox')) {
        await Hive.openBox('userBox');
      }
      await Hive.box('userBox').put('isLoggedIn', false);
      await removename('token');
      DioClient().dio.options.headers.remove('Authorization');
    } catch (_) {}
  }

  @override
  void onClose() {
    phoneController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
