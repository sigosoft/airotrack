import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../routes/app_routes.dart';

class SplashController extends GetxController {
  // Properties for the animating object (Square/Circle)
  var squareOpacity = 0.0.obs;
  var squareRotation = 0.0.obs;
  var squareRadius = 20.0.obs;
  var squareLeft = 145.0.obs;
  var squareTop = 372.0.obs;
  var squareSize = 100.0.obs;

  // Animation state flags
  var logoOpacity = 0.0.obs;
  var circleScale = 1.0.obs;
  var showFinalBackground = false.obs;

  // Gradient Alignment
  var gradientBegin = Alignment.topCenter.obs;
  var gradientEnd = Alignment.bottomCenter.obs;

  @override
  void onInit() {
    super.onInit();
    runSplashAnimation();
  }

  Future<void> runSplashAnimation() async {
    try {
      // Stage 1: Rounded Square fades in
      await Future.delayed(const Duration(milliseconds: 500));
      squareOpacity.value = 1.0;

      // Stage 2: Rotate and change to cross line
      await Future.delayed(const Duration(milliseconds: 800));
      squareRotation.value = -45.0; // CCW 45 degrees
      gradientBegin.value = Alignment.centerLeft;
      gradientEnd.value = Alignment.centerRight;

      // Stage 3: Morph to circle
      await Future.delayed(const Duration(milliseconds: 400));
      squareRadius.value = 45.0;

      // Stage 4: Move to "right after K" and shrink
      await Future.delayed(const Duration(milliseconds: 300));
      squareLeft.value = 300;
      squareTop.value = 420;
      squareSize.value = 30;

      // Stage 5: Logo appears
      await Future.delayed(const Duration(milliseconds: 500));
      logoOpacity.value = 1.0;

      // Stage 6: Hold position
      await Future.delayed(const Duration(milliseconds: 1200));

      // Stage 7: Explosion/Expansion to background
      circleScale.value = 150.0;

      // Stage 8: Transition to final background state
      await Future.delayed(const Duration(milliseconds: 400));
      showFinalBackground.value = true;

      // Navigation after splash
      await Future.delayed(const Duration(milliseconds: 500));

      print('Starting navigation...');

      // Navigate based on login status
      bool isLoggedIn = false;

      try {
        if (!Hive.isBoxOpen('userBox')) {
          print('Opening Hive box...');
          await Hive.openBox('userBox');
        }
        var box = Hive.box('userBox');
        isLoggedIn = box.get('isLoggedIn', defaultValue: false);
        print('Login status from Hive: $isLoggedIn');
      } catch (e) {
        print('Hive error: $e - Defaulting to not logged in');
        isLoggedIn = false;
      }

      // Ensure navigation happens
      print('Navigating to: ${isLoggedIn ? "HOME" : "WELCOME"}');
      if (isLoggedIn) {
        Get.offAllNamed(Routes.HOME);
      } else {
        Get.offAllNamed(Routes.WELCOME);
      }
    } catch (e) {
      print('Splash animation error: $e');
      // Force navigation to welcome on any error
      Get.offAllNamed(Routes.WELCOME);
    }
  }
}
