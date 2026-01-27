import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../routes/app_routes.dart';

class LoginController extends GetxController {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  var isPasswordVisible = false.obs;

  // Validation messages
  var phoneError = ''.obs;
  var passwordError = ''.obs;

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  bool validate() {
    bool isValid = true;

    // Phone validation
    if (phoneController.text.trim().isEmpty) {
      phoneError.value = 'Phone number is required';
      isValid = false;
    } else if (phoneController.text.length < 10) {
      phoneError.value = 'Please enter a valid phone number';
      isValid = false;
    } else {
      phoneError.value = '';
    }

    // Password validation
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
    if (validate()) {
      try {
        // Ensure Hive is open
        if (!Hive.isBoxOpen('userBox')) {
          // Basic init if needed (though main should have done it)
          try {
            await Hive.initFlutter();
          } catch (_) {}
          await Hive.openBox('userBox');
        }
        var box = Hive.box('userBox');

        String? storedPhone = box.get('phone');
        String? storedPassword = box.get('password');

        if (storedPhone != null &&
            storedPhone == phoneController.text.trim() &&
            storedPassword != null &&
            storedPassword == passwordController.text.trim()) {
          // Login Success
          box.put('isLoggedIn', true);

          Get.snackbar(
            'Success',
            'Logged in successfully',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          Get.offAllNamed(Routes.HOME);
        } else {
          Get.snackbar(
            'Error',
            'Invalid phone number or password',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } catch (e) {
        Get.snackbar(
          'Error',
          'Login failed: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  void onClose() {
    phoneController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
