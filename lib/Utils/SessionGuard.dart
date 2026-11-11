import 'package:airotrack/Configs/DioClient.dart';
import 'package:flutter/material.dart';
import 'package:airotrack/Screens/routes/app_routes.dart';
import 'package:airotrack/Services/FcmService.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Ends the session when the server rejects the saved token (HTTP 401).
class SessionGuard {
  static bool _ending = false;

  static Future<void> endSession() async {
    if (_ending) return;
    _ending = true;
    try {
      // Nothing to end if the token is already gone; this stops repeated 401s
      // from several in-flight requests from navigating again.
      final saved = await getSavedObject('token');
      if (saved == null) return;

      await removename('token');
      DioClient().clearToken();
      await FcmService.instance.removeDeviceToken();

      if (!Hive.isBoxOpen('userBox')) {
        await Hive.openBox('userBox');
      }
      await Hive.box('userBox').put('isLoggedIn', false);

      Fluttertoast.showToast(
        msg: 'Your session has ended. Please log in again.',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      Get.offAllNamed(Routes.LOGIN);
    } catch (_) {
      // Leave the screen as it is if the session cannot be cleared.
    } finally {
      _ending = false;
    }
  }
}
