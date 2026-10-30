import 'dart:developer';

import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../alerts/controllers/alerts_controller.dart';
import '../../home/controllers/home_controller.dart';

enum NotificationFilterCategory { eventTypes, vehicles, date }

class NotificationController extends GetxController {
  final RxString selectedTab = 'Alerts'.obs;
  final ScrollController scrollController = ScrollController();
  /// Notifications shown on screen (after the local filters).
  final notifications = <AlertModel>[].obs;
  final List<AlertModel> _all = [];
  var isLoading = false.obs;
  var hasMore = true.obs;
  var currentPage = 1;

  // Applied filters
  final selectedEventTypes = <String>{'All Events'}.obs;
  final selectedVehicles = <String>{}.obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();

  // Draft filters while sheet is open
  final filterCategory = NotificationFilterCategory.eventTypes.obs;
  final draftEventTypes = <String>{'All Events'}.obs;
  final draftVehicles = <String>{}.obs;
  final draftFromDate = Rxn<DateTime>();
  final draftToDate = Rxn<DateTime>();
  final vehicleFilterQuery = ''.obs;

  static const eventTypeOptions = <String>[
    'All Events',
    'Command Result',
    'Device Online',
    'Device Unknown',
    'Device Offline',
    'Device Inactive',
    'Device Moving',
    'Device Stopped',
    'Device Overspeed',
    'Device Fuel Drop',
  ];

  List<String> get vehicleOptions {
    if (Get.isRegistered<HomeController>()) {
      final plates = Get.find<HomeController>()
          .vehicles
          .map((v) => v.plateNumber)
          .where((p) => p.trim().isNotEmpty)
          .toList();
      if (plates.isNotEmpty) return plates;
    }
    return const [
      'KL 07 D 0518',
      'KL 07 D 6788',
      'KL 07 D 0510',
      'KL 07 D 1234',
      'KL 07 D 9876',
    ];
  }

  List<String> get filteredVehicleOptions {
    final q = vehicleFilterQuery.value.trim().toLowerCase();
    final all = vehicleOptions;
    if (q.isEmpty) return all;
    return all.where((p) => p.toLowerCase().contains(q)).toList();
  }

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        if (!isLoading.value && hasMore.value) {
          loadMoreNotifications();
        }
      }
    });
  }

  void beginFilterEdit() {
    filterCategory.value = NotificationFilterCategory.eventTypes;
    vehicleFilterQuery.value = '';
    draftEventTypes
      ..clear()
      ..addAll(selectedEventTypes);
    draftVehicles
      ..clear()
      ..addAll(selectedVehicles);
    draftFromDate.value = fromDate.value;
    draftToDate.value = toDate.value;
    draftEventTypes.refresh();
    draftVehicles.refresh();
  }

  void cancelFilterEdit() {
    // Discard draft — applied filters stay unchanged.
  }

  void applyFilters() {
    selectedEventTypes
      ..clear()
      ..addAll(draftEventTypes);
    selectedVehicles
      ..clear()
      ..addAll(draftVehicles);
    fromDate.value = draftFromDate.value;
    toDate.value = draftToDate.value;
    selectedEventTypes.refresh();
    selectedVehicles.refresh();
    _applyLocalFilters();
  }

  void toggleDraftEventType(String option) {
    if (option == 'All Events') {
      draftEventTypes
        ..clear()
        ..add('All Events');
    } else {
      draftEventTypes.remove('All Events');
      if (draftEventTypes.contains(option)) {
        draftEventTypes.remove(option);
      } else {
        draftEventTypes.add(option);
      }
      if (draftEventTypes.isEmpty) {
        draftEventTypes.add('All Events');
      }
    }
    draftEventTypes.refresh();
  }

  void toggleDraftVehicle(String plate) {
    if (draftVehicles.contains(plate)) {
      draftVehicles.remove(plate);
    } else {
      draftVehicles.add(plate);
    }
    draftVehicles.refresh();
  }

  Future<void> pickDraftFromDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: draftFromDate.value ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: draftToDate.value ?? now,
    );
    if (picked != null) draftFromDate.value = picked;
  }

  Future<void> pickDraftToDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: draftToDate.value ?? draftFromDate.value ?? now,
      firstDate: draftFromDate.value ?? DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) draftToDate.value = picked;
  }

  static const int _pageSize = 20;

  /// Push notifications only: read from the push server ([ApiConfig.pushBaseUrl]).
  Future<List<AlertModel>?> _fetchPage(int page) async {
    try {
      final token = await getSavedObject('token');
      if (token != null) DioClient().updateToken(token.toString().trim());

      final response = await DioClient().get(
        ApiEndPoints.pushNotificationsUrl,
        query: {'limit': '$_pageSize', 'page': '$page'},
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (status) => true,
        ),
      );

      final data = response.data;
      final list = (response.statusCode == 200 && data is Map)
          ? (data['data'] is Map ? data['data']['alerts'] : null)
          : null;
      if (list is! List) {
        log('[Notifications] unexpected response, status=${response.statusCode}');
        return null;
      }
      return list
          .whereType<Map>()
          .map((e) => AlertModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      log('[Notifications] load failed: $e');
      return null;
    }
  }

  Future<void> loadNotifications() async {
    isLoading.value = true;
    currentPage = 1;
    hasMore.value = true;
    final page = await _fetchPage(1);
    _all
      ..clear()
      ..addAll(page ?? const [])
      ..sort((a, b) => b.date.compareTo(a.date));
    if (page == null || page.length < _pageSize) hasMore.value = false;
    _applyLocalFilters();
    isLoading.value = false;
  }

  Future<void> loadMoreNotifications() async {
    if (isLoading.value || !hasMore.value) return;
    isLoading.value = true;
    final page = await _fetchPage(currentPage + 1);
    if (page == null || page.isEmpty) {
      hasMore.value = false;
    } else {
      currentPage++;
      _all.addAll(page);
      if (page.length < _pageSize) hasMore.value = false;
      _applyLocalFilters();
    }
    isLoading.value = false;
  }

  /// Event type, vehicle and date filters, applied to what has been loaded.
  void _applyLocalFilters() {
    final types = selectedEventTypes.contains('All Events')
        ? <String>{}
        : selectedEventTypes.map((e) => e.toLowerCase()).toSet();
    final from = fromDate.value;
    final to = toDate.value;

    bool matches(AlertModel a) {
      if (types.isNotEmpty) {
        final t = a.type.toLowerCase();
        final ok = types.any(
          (o) => t.contains(o) || t.contains(o.replaceFirst('device ', '')),
        );
        if (!ok) return false;
      }
      if (selectedVehicles.isNotEmpty &&
          !selectedVehicles.contains(a.plateNumber)) {
        return false;
      }
      if (from != null || to != null) {
        final d = DateTime.tryParse(a.date);
        if (d != null) {
          if (from != null && d.isBefore(DateTime(from.year, from.month, from.day))) {
            return false;
          }
          if (to != null && !d.isBefore(DateTime(to.year, to.month, to.day + 1))) {
            return false;
          }
        }
      }
      return true;
    }

    notifications.assignAll(_all.where(matches));
  }

  void changeTab(String tab) {
    selectedTab.value = tab;
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
