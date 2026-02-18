import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Utils/Utils.dart';

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
    loadAlerts();
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        if (!isLoading.value && hasMore.value) {
          loadMoreAlerts();
        }
      }
    });
  }

  Future<void> loadAlerts() async {
    try {
      isLoading.value = true;

      final token = await getSavedObject('token');
      if (token != null) {
        DioClient().updateToken(token);
      }

      final response = await DioClient().get(
        ApiEndPoints.alerts,
        query: {'imei': '', 'limit': '100'},
      );

      if (response.data != null &&
          response.data['data'] != null &&
          response.data['data']['alerts'] != null) {
        final List<dynamic> data = response.data['data']['alerts'];
        alerts.assignAll(
          data.map((json) => AlertModel.fromJson(json)).toList(),
        );

        // If we got less than 100 items, assume no more for now
        if (data.length < 100) {
          hasMore.value = false;
        }
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

      final response = await DioClient().get(
        ApiEndPoints.alerts,
        query: {'imei': '', 'limit': '100', 'page': currentPage},
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
