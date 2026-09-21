import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/ReportItem.dart';
import 'package:airotrack/Screens/modules/home/controllers/home_controller.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum ReportType {
  ignition,
  stoppage,
  trip,
  daily,
  summary,
  overspeed,
  geofence,
  alerts,
}

extension ReportTypeX on ReportType {
  String get endpoint {
    switch (this) {
      case ReportType.ignition:
        return ApiEndPoints.reportsIgnition;
      case ReportType.stoppage:
        return ApiEndPoints.reportsStoppage;
      case ReportType.trip:
        return ApiEndPoints.reportsTrip;
      case ReportType.daily:
        return ApiEndPoints.reportsDaily;
      case ReportType.summary:
        return ApiEndPoints.reportsSummary;
      case ReportType.overspeed:
        return ApiEndPoints.reportsOverspeed;
      case ReportType.geofence:
        return ApiEndPoints.reportsGeofence;
      case ReportType.alerts:
        return ApiEndPoints.reportsAlerts;
    }
  }

  String get title {
    switch (this) {
      case ReportType.ignition:
        return 'Ignition Reports';
      case ReportType.stoppage:
        return 'Stoppage Reports';
      case ReportType.trip:
        return 'Trip Reports';
      case ReportType.daily:
        return 'Daily Reports';
      case ReportType.summary:
        return 'Summary Reports';
      case ReportType.overspeed:
        return 'Over Speed Reports';
      case ReportType.geofence:
        return 'Geofence Reports';
      case ReportType.alerts:
        return 'Alert Reports';
    }
  }
}

class ReportsController extends GetxController {
  final ScrollController scrollController = ScrollController();
  final items = <ReportItem>[].obs;
  final isLoading = false.obs;
  final hasMore = true.obs;
  final selectedPeriod = 'Today'.obs;
  final selectedImei = ''.obs;
  final selectedPlate = 'All vehicles'.obs;
  final searchQuery = ''.obs;

  ReportType? reportType;
  var currentPage = 1;
  static const int _pageLimit = 50;
  String? _configuredKey;

  List<Vehicle> get vehicles {
    if (Get.isRegistered<HomeController>()) {
      return Get.find<HomeController>().vehicles.toList();
    }
    return const [];
  }

  List<ReportItem> get filteredItems {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return items.toList();
    return items
        .where(
          (e) =>
              e.vehicleNumber.toLowerCase().contains(q) ||
              e.location.toLowerCase().contains(q) ||
              e.status.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(() {
      try {
        if (!scrollController.hasClients) return;
        final position = scrollController.position;
        if (position.pixels >= position.maxScrollExtent - 100) {
          if (!isLoading.value && hasMore.value && reportType != null) {
            loadMore();
          }
        }
      } catch (_) {}
    });
  }

  /// Called by each report list view to bind endpoint + fetch.
  void configure(ReportType type) {
    final key = '${type.name}|${selectedPeriod.value}|${selectedImei.value}';
    if (_configuredKey == key) return;
    reportType = type;
    _configuredKey = key;
    if (selectedImei.value.isEmpty && vehicles.isNotEmpty) {
      final v = vehicles.first;
      final imei = v.deviceId.trim();
      if (imei.isNotEmpty) {
        selectedImei.value = imei;
        selectedPlate.value =
            v.plateNumber.isEmpty ? imei : v.plateNumber;
      }
    }
    // All report endpoints need imei (+ date filters).
    if (selectedImei.value.trim().isEmpty) {
      _waitThenLoad();
      return;
    }
    loadItems(reset: true);
  }

  Future<void> _waitThenLoad() async {
    if (!Get.isRegistered<HomeController>()) return;
    final home = Get.find<HomeController>();
    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (home.vehicles.isNotEmpty) {
        final v = home.vehicles.first;
        final imei = v.deviceId.trim();
        if (imei.isEmpty) continue;
        selectedImei.value = imei;
        selectedPlate.value =
            v.plateNumber.isEmpty ? imei : v.plateNumber;
        await loadItems(reset: true);
        return;
      }
      if (!home.isLoading.value && home.vehicles.isEmpty) break;
    }
  }

  void setPeriod(String period) {
    if (selectedPeriod.value == period) return;
    selectedPeriod.value = period;
    if (reportType != null && selectedImei.value.trim().isNotEmpty) {
      _configuredKey = null;
      loadItems(reset: true);
    }
  }

  void selectVehicle({String? imei, String? plate}) {
    selectedImei.value = imei ?? '';
    selectedPlate.value =
        plate ?? (imei == null || imei.isEmpty ? 'All vehicles' : imei);
    if (reportType != null && selectedImei.value.trim().isNotEmpty) {
      _configuredKey = null;
      loadItems(reset: true);
    }
  }

  Future<void> loadItems({bool reset = true}) async {
    if (reportType == null) return;
    final imei = selectedImei.value.trim();
    if (imei.isEmpty) return;
    try {
      if (reset) {
        currentPage = 1;
        hasMore.value = true;
        items.clear();
      }
      isLoading.value = true;
      await ensureApiToken();
      final range = PeriodQuery.fromLabel(selectedPeriod.value);
      // Spec: imei, period, from_date, to_date, limit (same for all report GETs)
      final response = await DioClient().get(
        reportType!.endpoint,
        query: range.toQuery(
          imei: imei,
          limit: _pageLimit,
        ),
      );

      if (response.data != null) {
        final data = response.data['data'] ?? response.data;
        final dataMap = asStringKeyedMap(data);
        final vehicleMap = asStringKeyedMap(dataMap?['vehicle']);
        final fallbackVehicle = pickString(vehicleMap, [
          'vehicle_number',
          'name',
          'plate_number',
        ]);

        final list = extractList(
          data,
          preferredKeys: [
            'items',
            'reports',
            reportType!.name,
            '${reportType!.name}_reports',
            'alerts',
          ],
        );

        // Summary API returns a single `summary` object, not an items array.
        List<dynamic> rows = list;
        if (rows.isEmpty && dataMap != null) {
          final summary = asStringKeyedMap(dataMap['summary']);
          if (summary != null) {
            rows = [summary];
          }
        }

        final parsed = rows
            .map(
              (json) => ReportItem.fromJson(
                json,
                fallbackVehicleNumber: fallbackVehicle,
              ),
            )
            .toList();
        if (reset) {
          items.assignAll(parsed);
        } else {
          items.addAll(parsed);
        }
        hasMore.value = list.isNotEmpty && parsed.length >= _pageLimit;
      } else {
        hasMore.value = false;
      }
    } catch (e) {
      showErrorMessage(e);
      hasMore.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (!hasMore.value || isLoading.value) return;
    currentPage++;
    await loadItems(reset: false);
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
