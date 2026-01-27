import 'package:airotrack/Screens/widgets/auth_logo.dart';
import 'package:airotrack/Screens/widgets/auth_text_field.dart';
import 'package:airotrack/Utils/app_colors.dart';
import 'package:airotrack/Utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/reset_password_controller.dart';

class ResetPasswordView extends GetView<ResetPasswordController> {
  const ResetPasswordView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.loginGradient),
        child: SafeArea(
          child: Stack(
            children: [
              // Content
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Logo
                    const AuthLogo(),

                    const SizedBox(height: 30),
                    // Title and Subtitle
                    const Text(
                      'Create New Password',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Enter a strong new password to secure your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),

                    // Input Fields
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          children: [
                            Obx(
                              () => AuthTextField(
                                controller: controller.passwordController,
                                hint: 'Enter your new password',
                                obscureText:
                                    !controller.isPasswordVisible.value,
                                errorText: controller.passwordError.value,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    controller.isPasswordVisible.value
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.grey,
                                  ),
                                  onPressed:
                                      controller.togglePasswordVisibility,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Obx(
                              () => AuthTextField(
                                controller:
                                    controller.confirmPasswordController,
                                hint: 'Enter your confirm password',
                                obscureText:
                                    !controller.isConfirmPasswordVisible.value,
                                errorText:
                                    controller.confirmPasswordError.value,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    controller.isConfirmPasswordVisible.value
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.grey,
                                  ),
                                  onPressed: controller
                                      .toggleConfirmPasswordVisibility,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Button
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: AppStyles.buttonWidth,
                          height: AppStyles.buttonHeight,
                          child: ElevatedButton(
                            onPressed: controller.resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.buttonColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppStyles.buttonRadius,
                                ),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Reset Password',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Back Button (Moved to LAST child in Stack)
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                  onPressed: () => Get.back(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
