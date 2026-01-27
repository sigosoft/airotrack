import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors
  static const Color primaryBlue = Color(0xFF009FE3);
  static const Color lightBlue = Color(0xFF46C5FB);
  static const Color deepBlue = Color(0xFF0071BC);
  static const Color lightBlueshade = Color.fromARGB(255, 141, 221, 255);
  static const Color buttonColor = Color(0xFF0071BC); // #0071BCFC

  // Neutral colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color lightGray = Color(0xFFF2F2F2);
  static const Color dotGray = Color(0xFFD9D9D9);

  // Standard background gradient for Login/Welcome
  static const LinearGradient loginGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      white,
      lightBlueshade, // Using the blue from splash screen
    ],
    stops: [0.2, 1.0],
  );
}
