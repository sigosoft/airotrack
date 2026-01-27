import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../routes/app_routes.dart';

class RegisterController extends GetxController {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  var isPasswordVisible = false.obs;
  var isConfirmPasswordVisible = false.obs;

  var selectedCountryCode = '91'.obs;
  var selectedCountryFlag = '🇮🇳'.obs;

  // Validation messages
  var nameError = ''.obs;
  var phoneError = ''.obs;
  var passwordError = ''.obs;
  var confirmPasswordError = ''.obs;

  void updateCountry(String code, String flag) {
    selectedCountryCode.value = code;
    selectedCountryFlag.value = flag;
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
  }

  bool validate() {
    bool isValid = true;

    // Name validation
    if (nameController.text.trim().isEmpty) {
      nameError.value = 'Name is required';
      isValid = false;
    } else {
      nameError.value = '';
    }

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

    // Confirm Password validation
    if (confirmPasswordController.text.trim().isEmpty) {
      confirmPasswordError.value = 'Confirmation is required';
      isValid = false;
    } else if (confirmPasswordController.text != passwordController.text) {
      confirmPasswordError.value = 'Passwords do not match';
      isValid = false;
    } else {
      confirmPasswordError.value = '';
    }

    return isValid;
  }

  Future<void> signUp() async {
    if (validate()) {
      try {
        // Initialize Hive for storage
        // If this throws MissingPluginException, the app needs a restart
        await Hive.initFlutter();

        // Store user details in Hive
        if (!Hive.isBoxOpen('userBox')) {
          await Hive.openBox('userBox');
        }
        var box = Hive.box('userBox');
        box.put('isLoggedIn', false); // Not logged in yet
        box.put('name', nameController.text.trim());
        box.put('phone', phoneController.text.trim());
        box.put('password', passwordController.text.trim());
        // In a real app, you would store a token here

        Get.snackbar(
          'Success',
          'Account created successfully. Please login.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );

        // Close keyboard to prevent native crashes during transition
        Get.focusScope?.unfocus();

        // Small delay to allow snackbar to show and keyboard to close
        await Future.delayed(const Duration(milliseconds: 1500));

        // Navigate to Login
        Get.offAllNamed(Routes.LOGIN);
      } catch (e) {
        print('Sign up error: $e'); // Log error to console

        String errorMsg = 'Failed to sign up: $e';
        if (e.toString().contains('MissingPluginException') ||
            e.toString().contains('initialize Hive')) {
          errorMsg = 'Please fully restart the app to enable storage features.';
        }

        Get.snackbar(
          'Error',
          errorMsg,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    } else {
      // Show error snackbar if validation fails
      String errorMessage = "Please fix errors";
      if (nameError.isNotEmpty)
        errorMessage = nameError.value;
      else if (phoneError.isNotEmpty)
        errorMessage = phoneError.value;
      else if (passwordError.isNotEmpty)
        errorMessage = passwordError.value;
      else if (confirmPasswordError.isNotEmpty)
        errorMessage = confirmPasswordError.value;

      print(
        'Validation Error: $errorMessage',
      ); // Log validation error to console

      Get.snackbar(
        'Validation Error',
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
