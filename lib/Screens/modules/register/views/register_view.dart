import 'package:airotrack/Screens/widgets/auth_logo.dart';
import 'package:airotrack/Screens/widgets/auth_text_field.dart';
import 'package:airotrack/Utils/app_colors.dart';
import 'package:airotrack/Utils/app_styles.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/register_controller.dart';

class RegisterView extends GetView<RegisterController> {
  const RegisterView({Key? key}) : super(key: key);

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
              // Content first
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Logo with standard reusable positioning
                    const AuthLogo(),

                    const SizedBox(height: 30),
                    // Welcome Text
                    const Text(
                      'Hello!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please Sign Up Your Account',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Name Field
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Obx(
                          () => AuthTextField(
                            controller: controller.nameController,
                            hint: 'Enter your name',
                            errorText: controller.nameError.value,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Phone Number Field (Special Handling for Country Picker)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Obx(
                          () => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width:
                                    MediaQuery.of(context).size.width <
                                        AppStyles.inputWidth + 32
                                    ? MediaQuery.of(context).size.width - 32
                                    : AppStyles.inputWidth,
                                height: AppStyles.inputHeight,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    AppStyles.inputRadius,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        showCountryPicker(
                                          context: context,
                                          showPhoneCode: true,
                                          onSelect: (Country country) {
                                            controller.updateCountry(
                                              country.phoneCode,
                                              country.flagEmoji,
                                            );
                                          },
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 15,
                                          right: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              controller
                                                  .selectedCountryFlag
                                                  .value,
                                              style: const TextStyle(
                                                fontSize: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              '+ ${controller.selectedCountryCode.value}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              height: 30,
                                              width: 1,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: controller.phoneController,
                                        keyboardType: TextInputType.phone,
                                        textAlignVertical:
                                            TextAlignVertical.center,
                                        decoration: const InputDecoration(
                                          hintText: 'Enter Your phone number',
                                          hintStyle: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                          border: InputBorder.none,
                                          isCollapsed: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (controller.phoneError.value.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 15,
                                    top: 5,
                                  ),
                                  child: Text(
                                    controller.phoneError.value,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Password Field
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Obx(
                          () => AuthTextField(
                            controller: controller.passwordController,
                            hint: 'Enter your password',
                            obscureText: !controller.isPasswordVisible.value,
                            errorText: controller.passwordError.value,
                            suffixIcon: IconButton(
                              icon: Icon(
                                controller.isPasswordVisible.value
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed: controller.togglePasswordVisibility,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Confirm Password Field
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Obx(
                          () => AuthTextField(
                            controller: controller.confirmPasswordController,
                            hint: 'Enter your confirm password',
                            obscureText:
                                !controller.isConfirmPasswordVisible.value,
                            errorText: controller.confirmPasswordError.value,
                            suffixIcon: IconButton(
                              icon: Icon(
                                controller.isConfirmPasswordVisible.value
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed:
                                  controller.toggleConfirmPasswordVisibility,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Sign Up Button
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width:
                              MediaQuery.of(context).size.width <
                                  AppStyles.buttonWidth + 32
                              ? MediaQuery.of(context).size.width - 32
                              : AppStyles.buttonWidth,
                          height: AppStyles.buttonHeight,
                          child: ElevatedButton(
                            onPressed: controller.signUp,
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
                              'Sign Up',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Sign In Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(color: Colors.black, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () => Get.back(),
                          child: const Text(
                            'Sign in',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              // Floating Back Button moved to LAST to ensure it stays on top
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
