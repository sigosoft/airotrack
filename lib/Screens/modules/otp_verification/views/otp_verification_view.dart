import 'package:airotrack/Screens/widgets/auth_logo.dart';
import 'package:airotrack/Utils/app_colors.dart';
import 'package:airotrack/Utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/otp_verification_controller.dart';

class OTPVerificationView extends GetView<OTPVerificationController> {
  const OTPVerificationView({Key? key}) : super(key: key);

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
                      'OTP Verification',
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
                        'Enter the verification code we just sent to your email or phone number',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 60,
                    ), // Gap to reach boxes roughly at 350
                    // OTP Fields
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              4,
                              (index) => _buildOTPBox(index, context),
                            ),
                          ),
                          Obx(
                            () => controller.otpError.value.isNotEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      controller.otpError.value,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 50), // Gap to reach button at 470
                    // Button
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: AppStyles.buttonWidth,
                          height: AppStyles.buttonHeight,
                          child: ElevatedButton(
                            onPressed: controller.verify,
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
                              'Verify',
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

  Widget _buildOTPBox(int index, BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextField(
        controller: controller.otpControllers[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.length == 1 && index < 3) {
            FocusScope.of(context).nextFocus();
          } else if (value.isEmpty && index > 0) {
            FocusScope.of(context).previousFocus();
          }
        },
      ),
    );
  }
}
