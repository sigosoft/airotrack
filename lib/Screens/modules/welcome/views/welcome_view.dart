import 'dart:math' as math;

import 'package:airotrack/Utils/app_assets.dart';
import 'package:airotrack/Utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/welcome_controller.dart';

/// Onboarding pages. Laid out in a column (not fixed top/left offsets) so the
/// picture stays centred and the dots and Next button stay on screen on short
/// and narrow phones as well as big ones.
class WelcomeView extends GetView<WelcomeController> {
  const WelcomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: controller.pageController,
                onPageChanged: controller.onPageChanged,
                itemCount: controller.onboardingData.length,
                itemBuilder: (context, index) {
                  final data = controller.onboardingData[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // 300 on the design phone; smaller when the screen is
                      // narrow or short so the text below still fits.
                      final imageSize = math.min(
                        300.0,
                        math.min(
                          constraints.maxWidth - 90,
                          constraints.maxHeight * 0.55,
                        ),
                      );
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                data['image']!,
                                width: imageSize,
                                height: imageSize,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 20),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Text(
                                  data['title']!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
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
                      );
                    },
                  );
                },
              ),
            ),

            // Indicator Dots
            Obx(() {
              return Row(
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
              );
            }),
            const SizedBox(height: 8),

            // Next Button (Arrow)
            GestureDetector(
              onTap: controller.nextPage,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Image.asset(AppAssets.arrowButton, width: 40, height: 40),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
