import 'package:airotrack/Screens/widgets/auth_logo.dart';
import 'package:airotrack/Screens/widgets/auth_text_field.dart';
import 'package:airotrack/Utils/app_colors.dart';
import 'package:airotrack/Utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/forgot_password_controller.dart';

class ForgotPasswordView extends GetView<ForgotPasswordController> {
  const ForgotPasswordView({Key? key}) : super(key: key);

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
              // Content (Moved to FIRST child in Stack)
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Logo
                    const AuthLogo(),

                    const SizedBox(height: 30),
                    // Title and Subtitle
                    const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No worries! Create a new password.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 90),

                    // Input Field
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Obx(
                          () => AuthTextField(
                            controller: controller.phoneController,
                            hint: 'Enter your phone number',
                            keyboardType: TextInputType.phone,
                            errorText: controller.phoneError.value,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 59),

                    // Button
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: AppStyles.buttonWidth,
                          height: AppStyles.buttonHeight,
                          child: ElevatedButton(
                            onPressed: controller.sendCode,
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
                              'Send Verification Code',
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
