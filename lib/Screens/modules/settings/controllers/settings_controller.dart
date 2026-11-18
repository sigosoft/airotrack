import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/ProfileModel.dart';
import 'package:airotrack/Services/FcmService.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../routes/app_routes.dart';

class SettingsController extends GetxController {
  final profile = const ProfileModel().obs;
  final isLoadingProfile = false.obs;

  Future<void> signOut() async {
    try {
      final saved = await getSavedObject('token');
      final token = saved?.toString().trim();
      if (token == null || token.isEmpty) {
        throw Exception('No active session');
      }

      // Signing out depends on the server. If the call fails, the user stays
      // signed in and sees an error, so the phone and server never disagree.
      // 401 means the server has no valid session for this token, so it counts
      // as signed out. Any other failure keeps the user signed in.
      final response = await DioClient()
          .get(
            ApiEndPoints.logout,
            options: Options(
              headers: {'Authorization': 'Bearer $token'},
              validateStatus: (_) => true,
            ),
          )
          .timeout(const Duration(seconds: 3));
      final code = response.statusCode ?? 0;
      if (code != 401 && (code < 200 || code >= 300)) {
        throw Exception('Logout failed: $code');
      }

      await removename('token');
      DioClient().clearToken();
      // Runs after the session is cleared, so a token refresh cannot re-register.
      await FcmService.instance.removeDeviceToken();

      if (!Hive.isBoxOpen('userBox')) {
        await Hive.openBox('userBox');
      }
      var box = Hive.box('userBox');
      await box.put('isLoggedIn', false);

      Get.snackbar(
        'Success',
        'Signed out successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Get.offAllNamed(Routes.LOGIN);
    } catch (e) {
      debugPrint('Logout failed: $e');
      Get.snackbar(
        'Error',
        'Could not sign out. Check your connection and try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      isLoadingProfile.value = true;
      await ensureApiToken();
      final response = await DioClient().get(ApiEndPoints.profile);
      if (response.data != null) {
        final data = response.data['data'] ?? response.data;
        profile.value = ProfileModel.fromJson(data);
      }
    } catch (e) {
      showErrorMessage(e);
    } finally {
      isLoadingProfile.value = false;
    }
  }
}
