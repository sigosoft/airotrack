import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/get_navigation.dart';
import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';

savename(String key, value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(value));
  } catch (e) {
    throw e;
  }
}

getSavedObject(String key) async {
  final prefs = await SharedPreferences.getInstance();
  var data = prefs.getString(key);
  return data != null ? json.decode(data) : null;
}

bool get isInDebugMode {
  bool inDebugMode = false;
  assert(inDebugMode = true);
  return inDebugMode;
}

removename(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  } catch (e) {
    throw e;
  }
}

showErrorMessage(error) {
  if (isInDebugMode) {
    print("Error is :$error");
  }
  if (!error.toString().contains("setState()")) {
    if (error is DioException) {
      DioException e = error;
      print("Error is :${error.response!.data}");
      var message = e.response!.data["message"];
      if (message == null) {
        message = e.response!.data["message"];
        message ??= "Oops Something went wrong try again !!";
      } else {
        message = e.response!.data["message"];
      }
      Fluttertoast.showToast(
        msg: message.toString(),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } else {
      Fluttertoast.showToast(
        msg: error?.toString() ?? "Oops Something went wrong try again !!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }
}

void showToast(BuildContext context, String message) {
  FocusScope.of(context).requestFocus(FocusNode());
  final overlay = Overlay.of(context);

  // Calculate the position based on the keyboard visibility
  double bottomPadding = 50.0; // Default padding for toast
  if (MediaQuery.of(context).viewInsets.bottom > 0) {
    // Keyboard is visible, adjust the position
    bottomPadding = MediaQuery.of(context).viewInsets.bottom + 50.0;
  }

  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: bottomPadding, // Adjust the position of the toast
      left: MediaQuery.of(context).size.width * 0.1, // Center horizontally
      right: MediaQuery.of(context).size.width * 0.1, // Center horizontally
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(
                  'lib/assets/images/logo.png', // Replace with your image path
                  width: 24,
                  height: 24,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);

  // Remove the toast after 3 seconds
  Future.delayed(Duration(seconds: 3), () {
    overlayEntry.remove();
  });
}

// void navigateTo(double lat, double lng) async {
//   if (Platform.isIOS) {
//     var uri = Uri.parse("http://maps.apple.app/q=$lat,$lng&mode=d");
//     if (await canLaunch(uri.toString())) {
//       await launch(uri.toString());
//     } else {
//       throw 'Could not launch ${uri.toString()}';
//     }
//   } else {
//     var uri = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
//     if (await canLaunch(uri.toString())) {
//       await launch(uri.toString());
//     } else {
//       throw 'Could not launch ${uri.toString()}';
//     }
//   }
// }

bool emailValid(String email) {
  final bool emailValid = RegExp(
    r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
  ).hasMatch(email);
  return emailValid;
}

Future<bool> checkNetwork() async {
  var connectivityResult = await Connectivity().checkConnectivity();

  if (connectivityResult == ConnectivityResult.mobile) {
    print('Connected to mobile network');
    return true;
  } else if (connectivityResult == ConnectivityResult.wifi) {
    print('Connected to WiFi');
    return true;
  } else {
    print('No internet connection');
    return false;
  }
}

extension EmailValidator on String {
  bool isValidEmail() {
    return RegExp(
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
    ).hasMatch(this);
  }
}

extension PasswordValidator on String {
  bool isValidPassword() {
    return RegExp(
      r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$',
    ).hasMatch(this);
  }
}

// void showLoadingDialog(BuildContext context) {
//   showDialog(
//     context: context,
//     barrierDismissible: false, // Prevent closing when tapping outside
//     builder: (context) {
//       return Dialog(
//         backgroundColor: Colors.transparent, // No background
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Lottie.asset(
//               'lib/assets/images/loader.json',
//               width: 100,
//               height: 100,
//             ),
//             // SizedBox(height: 10),
//             // Text("Loading...", style: TextStyle(color: Colors.white)),
//           ],
//         ),
//       );
//     },
//   );
// }

void printFormData(FormData formData) {
  Map<String, String> formDataMap = {};
  formData.fields.forEach((field) {
    formDataMap[field.key] = field.value;
  });
  print(formDataMap);
}

int versionToCode(String version) {
  final parts = version.split('.');
  final major = int.parse(parts[0]);
  final minor = int.parse(parts[1]);
  final patch = int.parse(parts[2]);

  return major * 10000 + minor * 100 + patch;
}

String convertToAmPm(String time24) {
  try {
    final parsedTime = DateFormat("HH:mm").parse(time24);
    return DateFormat("h a").format(parsedTime);
  } catch (e) {
    return time24; // fallback
  }
}

String formatRatingCount(int? value) {
  if (value == null) return "0";
  if (value < 1000) {
    return value.toString(); 
  } else if (value < 1000000) {
    double result = value / 1000;
    return "${result.toStringAsFixed(result < 10 ? 1 : 0)}K+";
  } else {
    double result = value / 1000000;
    return "${result.toStringAsFixed(result < 10 ? 1 : 0)}M+";
  }
}


