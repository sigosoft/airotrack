import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:dio/dio.dart';
import 'dart:developer';
import 'dart:math' as math;

class AlertModel {
  final int id;
  final String deviceName;
  final String plateNumber;
  final String date;
  final String type;
  final String address;
  final bool isIgnitionOn;

  AlertModel({
    required this.id,
    required this.deviceName,
    required this.plateNumber,
    required this.date,
    required this.type,
    required this.address,
    this.isIgnitionOn = false,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: 0,
      deviceName: json['vehicle_number'] ?? '',
      plateNumber: json['vehicle_number'] ?? '',
      date: json['datetime'] ?? '',
      type: json['alert_description'] ?? json['alert_type'] ?? '',
      address:
          json['address'] ??
          (json['latitude'] != null
              ? "${json['latitude']}, ${json['longitude']}"
              : ''),
      isIgnitionOn: json['ignition'] == 1,
    );
  }
}

class AlertsController extends GetxController {
  final ScrollController scrollController = ScrollController();
  var alerts = <AlertModel>[].obs;
  var isLoading = false.obs;
  var hasMore = true.obs;
  var currentPage = 1;

  @override
  void onInit() {
    super.onInit();
    log("AlertsController: onInit called");
    loadAlerts();
    scrollController.addListener(() {
      try {
        if (!scrollController.hasClients) return;
        final position = scrollController.position;
        if (position.pixels >= position.maxScrollExtent - 100) {
          if (!isLoading.value && hasMore.value) {
            loadMoreAlerts();
          }
        }
      } catch (_) {
        // ScrollController not yet attached or detached during rebuild
      }
    });
  }

  Future<void> loadAlerts() async {
    log("AlertsController: loadAlerts started");
    try {
      isLoading.value = true;

      final token = await getSavedObject('token');
      if (token != null) {
        DioClient().updateToken(token.toString().trim());
      }

      // Strictly following the provided API request structure: imei=&limit=100
      final Map<String, dynamic> queryParams = {
        'imei': Get.parameters['imei'] ?? '',
        'limit': '100',
      };

      final response = await DioClient().get(
        ApiEndPoints.alerts,
        query: queryParams,
        options: Options(
          headers: {"Content-Type": null, "Accept": "application/json"},
          validateStatus: (status) =>
              true, // Capture all status codes for debugging
        ),
      );

      // Diagnostic Logging
      log("[Alerts] Debug - Status: ${response.statusCode}");
      log("[Alerts] Debug - Data: ${response.data}");
      log(
        "[Alerts] Token (start): ${token?.toString().substring(0, math.min(10, token.toString().length))}...",
      );

      if (response.statusCode == 200 &&
          response.data != null &&
          response.data['data'] != null &&
          response.data['data']['alerts'] != null) {
        final List<dynamic> data = response.data['data']['alerts'];
        alerts.assignAll(
          data.map((json) => AlertModel.fromJson(json)).toList(),
        );

        if (data.isEmpty) {
          log("[Alerts] Notice: List is empty (Matching Postman).");
        }

        if (data.length < 100) {
          hasMore.value = false;
        }
      } else {
        log(
          "[Alerts] API Request failed or list not found. Status: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("Error loading alerts: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMoreAlerts() async {
    // Basic pagination if supported, assuming similar structure
    if (isLoading.value || !hasMore.value) return;

    try {
      isLoading.value = true;
      currentPage++;

      final Map<String, dynamic> queryParams = {
        'imei': Get.parameters['imei'] ?? '',
        'limit': '100',
        'page': currentPage.toString(),
      };

      final response = await DioClient().get(
        ApiEndPoints.alerts,
        query: queryParams,
        options: Options(
          headers: {"Content-Type": null, "X-Requested-With": "XMLHttpRequest"},
        ),
      );

      if (response.data != null &&
          response.data['data'] != null &&
          response.data['data']['alerts'] != null) {
        final List<dynamic> data = response.data['data']['alerts'];
        if (data.isEmpty) {
          hasMore.value = false;
        } else {
          alerts.addAll(data.map((json) => AlertModel.fromJson(json)).toList());
          if (data.length < 100) {
            hasMore.value = false;
          }
        }
      } else {
        hasMore.value = false;
      }
    } catch (e) {
      print("Error loading more alerts: $e");
      hasMore.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
