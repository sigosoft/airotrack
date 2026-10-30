import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Configs/ApiConfigs.dart';
import '../Screens/modules/alerts/controllers/alerts_controller.dart';

/// Reads push notifications from the push server ([ApiConfig.pushBaseUrl]).
/// Uses plain Dio and SharedPreferences only, so it also works from the
/// background message isolate.
class PushFeedService {
  PushFeedService._();

  static const String _lastShownKey = 'last_push_key';

  /// Newest push notification on the push server, or null on any failure.
  static Future<AlertModel?> latest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('token');
      final token = raw == null ? null : json.decode(raw)?.toString().trim();

      final response = await Dio().get<dynamic>(
        ApiEndPoints.pushNotificationsUrl,
        queryParameters: {'limit': '1', 'page': '1'},
        options: Options(
          headers: {
            'Accept': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          validateStatus: (_) => true,
        ),
      );

      final data = response.data;
      final list = (response.statusCode == 200 && data is Map)
          ? (data['data'] is Map ? data['data']['alerts'] : null)
          : null;
      if (list is! List || list.isEmpty || list.first is! Map) {
        debugPrint('[PushFeed] no data, status=${response.statusCode}');
        return null;
      }
      return AlertModel.fromJson(Map<String, dynamic>.from(list.first as Map));
    } catch (e) {
      debugPrint('[PushFeed] fetch failed: $e');
      return null;
    }
  }

  /// True the first time [a] is seen, so the same push is never shown twice.
  static Future<bool> markShown(AlertModel a) async {
    final key = '${a.date}|${a.plateNumber}|${a.type}';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_lastShownKey) == key) return false;
    await prefs.setString(_lastShownKey, key);
    return true;
  }
}
