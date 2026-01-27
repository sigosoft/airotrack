import 'package:airotrack/Utils/app_assets.dart';
import 'package:airotrack/Utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/welcome_controller.dart';

class WelcomeView extends GetView<WelcomeController> {
  const WelcomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // PageView for onboarding content
          PageView.builder(
            controller: controller.pageController,
            onPageChanged: controller.onPageChanged,
            itemCount: controller.onboardingData.length,
            itemBuilder: (context, index) {
              final data = controller.onboardingData[index];
              return Stack(
                children: [
                  // Image
                  Positioned(
                    top: 150,
                    left: 45,
                    child: Image.asset(
                      data['image']!,
                      width: 300,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // Text Content
                  Positioned(
                    top: 450, // Approximate position between image and dots
                    left: 20,
                    right: 20,
                    child: Column(
                      children: [
                        Text(
                          data['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            data['subtitle']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.black,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // Indicator Dots
          Positioned(
            top: 665,
            left: 159.91,
            child: Obx(() {
              return SizedBox(
                width: 70.69,
                height: 13.56,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      controller.onboardingData.length,
                      (index) => Container(
                        margin: EdgeInsets.only(
                          right: index < controller.onboardingData.length - 1
                              ? 15
                              : 0,
                        ),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: controller.currentPage.value == index
                              ? AppColors.deepBlue
                              : AppColors.dotGray,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          // Next Button (Arrow)
          Positioned(
            top: 700,
            left: 165.69,
            child: GestureDetector(
              onTap: controller.nextPage,
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(AppAssets.arrowButton, width: 40, height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
