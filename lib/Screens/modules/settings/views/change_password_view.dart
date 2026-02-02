import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/change_password_controller.dart';

class ChangePasswordView extends GetView<ChangePasswordController> {
  const ChangePasswordView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Change Password',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.5),
          child: Column(
            children: [
              const SizedBox(height: 15),
              _buildPasswordField(
                'Current Password',
                controller.oldPasswordController,
                controller.obscureOld,
                controller.toggleOld,
                controller.oldPasswordError,
              ),
              const SizedBox(height: 15),
              _buildPasswordField(
                'New Password',
                controller.newPasswordController,
                controller.obscureNew,
                controller.toggleNew,
                controller.newPasswordError,
              ),
              const SizedBox(height: 15),
              _buildPasswordField(
                'Confirm Password',
                controller.confirmPasswordController,
                controller.obscureConfirm,
                controller.toggleConfirm,
                controller.confirmPasswordError,
              ),
              const SizedBox(height: 300), // Spacing to match "top 607" approx
              SizedBox(
                width: 357,
                height: 45,
                child: ElevatedButton(
                  onPressed: controller.changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009FE3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Change Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String hint,
    TextEditingController fieldController,
    RxBool obscureText,
    VoidCallback onToggle,
    RxString errorText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 357,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Obx(
                  () => TextField(
                    controller: fieldController,
                    obscureText: obscureText.value,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.only(bottom: 12),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onToggle,
                child: Obx(
                  () => Icon(
                    obscureText.value
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        Obx(
          () => errorText.value.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    errorText.value,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
