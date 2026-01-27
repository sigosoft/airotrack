import 'package:airotrack/Utils/app_assets.dart';
import 'package:airotrack/Utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Obx(() {
        // Dynamic gradient based on animation stage
        final currentGradient = LinearGradient(
          begin: controller.gradientBegin.value,
          end: controller.gradientEnd.value,
          colors: const [
            AppColors.primaryBlue, // Edge (Dark Blue)
            AppColors.lightBlue, // Transition (Light Blue)
            AppColors.white, // The White Center Line
            AppColors.lightBlue, // Transition (Light Blue)
            AppColors.primaryBlue, // Edge (Dark Blue)
          ],
          stops: const [0.0, 0.42, 0.475, 0.55, 1.0],
        );

        // Final Background Gradient (Always diagonal as per Stage 2+)
        final finalGradient = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: const [
            AppColors.primaryBlue,
            AppColors.lightBlue,
            AppColors.white,
            AppColors.lightBlue,
            AppColors.primaryBlue,
          ],
          stops: const [0.0, 0.42, 0.475, 0.55, 1.0],
        );

        return Stack(
          children: [
            // 1. Initial White Background
            Positioned.fill(child: Container(color: AppColors.white)),

            // 2. Final Lock-in Background (Visible after expansion completes)
            if (controller.showFinalBackground.value)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(gradient: finalGradient),
                ),
              ),

            // 3. The Animating Square/Circle/Background Expansion
            AnimatedPositioned(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              top: controller.squareTop.value,
              left: controller.squareLeft.value,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 1500),
                scale: controller.circleScale.value,
                curve: Curves.fastOutSlowIn,
                alignment: Alignment.center,
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 800),
                  turns: controller.squareRotation.value / 360,
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: controller.squareOpacity.value,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: controller.squareSize.value,
                      height: controller.squareSize.value,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          controller.squareRadius.value >= 45.0
                              ? controller.squareSize.value / 2
                              : controller.squareRadius.value,
                        ),
                        gradient: currentGradient,
                        boxShadow: [
                          if (controller.circleScale.value == 1.0 &&
                              controller.squareOpacity.value > 0)
                            BoxShadow(
                              color: AppColors.black.withOpacity(0.08),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 4. Branding (Always on top to prevent being "covered" by the expansion)
            Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 800),
                opacity: controller.logoOpacity.value,
                child: Image.asset(
                  AppAssets.logo,
                  width: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
