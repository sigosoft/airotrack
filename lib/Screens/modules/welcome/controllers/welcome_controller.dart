import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:airotrack/Utils/app_assets.dart';
import '../../../routes/app_routes.dart';

class WelcomeController extends GetxController {
  final pageController = PageController();
  var currentPage = 0.obs;

  final List<Map<String, String>> onboardingData = [
    {
      "title": "Drive Smart. Track Easy.",
      "subtitle":
          "Your all-in-one vehicle tracking companion. Drive with confidence, monitor with ease, and stay connected on every journey.",
      "image": AppAssets.onboarding1,
    },
    {
      "title": "Smarter Tracking for Smarter Journeys.",
      "subtitle":
          "Experience real-time tracking and smart insights that keep you in control. Make every drive safer, easier, and stress-free.",
      "image": AppAssets.onboarding2,
    },
    {
      "title": "Keep Your Vehicle Road-Ready.",
      "subtitle":
          "Track, monitor, and stay updated. Peace of mind, mind, every drive.",
      "image": AppAssets.onboarding3,
    },
  ];

  void onPageChanged(int index) {
    currentPage.value = index;
  }

  void nextPage() {
    if (currentPage.value < onboardingData.length - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      Get.offAllNamed(Routes.LOGIN);
    }
  }
}
