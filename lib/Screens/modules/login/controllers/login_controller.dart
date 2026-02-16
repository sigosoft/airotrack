import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../routes/app_routes.dart';

class LoginController extends GetxController {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  var isPasswordVisible = false.obs;
  var isLoading = false.obs;

  // Validation messages
  var phoneError = ''.obs;
  var passwordError = ''.obs;

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  static final _emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');

  bool _isValidEmail(String value) => _emailRegex.hasMatch(value);

  bool _isValidPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10;
  }

  bool _isValidUsername(String value) {
    return value.length >= 3;
  }

  bool validate() {
    bool isValid = true;
    final username = phoneController.text.trim();
    if (username.isEmpty) {
      phoneError.value = 'Phone number, email or username is required';
      isValid = false;
    } else if (username.contains('@')) {
      if (!_isValidEmail(username)) {
        phoneError.value = 'Please enter a valid email address';
        isValid = false;
      } else {
        phoneError.value = '';
      }
    } else if (_isValidPhone(username)) {
      phoneError.value = '';
    } else if (_isValidUsername(username)) {
      phoneError.value = '';
    } else {
      phoneError.value =
          'Please enter a valid phone number (10+ digits), email or username (3+ characters)';
      isValid = false;
    }
    if (passwordController.text.trim().isEmpty) {
      passwordError.value = 'Password is required';
      isValid = false;
    } else if (passwordController.text.length < 6) {
      passwordError.value = 'Password must be at least 6 characters';
      isValid = false;
    } else {
      passwordError.value = '';
    }

    return isValid;
  }

  Future<void> signIn() async {
    if (!validate()) return;
    isLoading.value = true;
    try {
      final response = await DioClient().post(
        ApiEndPoints.login,
        body: {
          'username': phoneController.text.trim(),
          'password': passwordController.text.trim(),
          'fcm': '',
        },
      );
      isLoading.value = false;
      if (response.data != null && response.data['data'] != null) {
        final token = response.data['data']['details']['token'];
        debugPrint(token);
        savename('token', token);
        DioClient().updateToken(token);

        // Persist login status for Splash screen check
        if (!Hive.isBoxOpen('userBox')) {
          await Hive.openBox('userBox');
        }
        await Hive.box('userBox').put('isLoggedIn', true);

        Get.offAllNamed(Routes.HOME);
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar('Error', e.toString());
    }
  }

  @override
  void onClose() {
    phoneController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
