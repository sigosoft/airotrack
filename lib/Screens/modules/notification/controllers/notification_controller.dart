import 'dart:developer';

import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../alerts/controllers/alerts_controller.dart';
import 'package:airotrack/Screens/modules/settings/controllers/configure_alerts_controller.dart'
    show AlertTypeOption;

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

  // Applied filters. Event types hold alert keys (e.g. "ignitionOn");
  // empty means no filter (every type / every vehicle).
  final selectedEventTypes = <String>{}.obs;
  final selectedVehicles = <String>{}.obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();

  // Draft filters while sheet is open
  final filterCategory = NotificationFilterCategory.eventTypes.obs;
  final draftEventTypes = <String>{}.obs;
  final draftVehicles = <String>{}.obs;
  final draftFromDate = Rxn<DateTime>();
  final draftToDate = Rxn<DateTime>();
  final vehicleFilterQuery = ''.obs;

  /// Event types for the filter, taken only from the alerts the alerts API
  /// returned (same as the Alerts page filter). Grows as more pages load.
  List<AlertTypeOption> get eventTypeOptions => eventTypeOptionsFrom(_all);

  /// True when every option in [options] is in [draft] ("All" row ticked).
  bool allTicked(Iterable<String> options, Set<String> draft) =>
      options.isNotEmpty && options.every(draft.contains);

  /// All Events: tick every type, or clear them all when all are ticked.
  void toggleDraftAllEvents() {
    final keys = eventTypeOptions.map((o) => o.key);
    if (allTicked(keys, draftEventTypes)) {
      draftEventTypes.clear();
    } else {
      draftEventTypes.addAll(keys);
    }
    draftEventTypes.refresh();
  }

  /// All Vehicles: tick every vehicle, or clear them all when all are ticked.
  void toggleDraftAllVehicles() {
    final all = vehicleOptions;
    if (allTicked(all, draftVehicles)) {
      draftVehicles.clear();
    } else {
      draftVehicles.addAll(all);
    }
    draftVehicles.refresh();
  }

  /// Vehicles for the filter, taken only from the loaded alerts
  /// (`vehicle_number`), sorted.
  List<String> get vehicleOptions {
    final plates = _all
        .map((a) => a.plateNumber.trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return plates;
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
    // No filter (empty) is shown as everything ticked.
    draftEventTypes
      ..clear()
      ..addAll(
        selectedEventTypes.isEmpty
            ? eventTypeOptions.map((o) => o.key)
            : selectedEventTypes,
      );
    draftVehicles
      ..clear()
      ..addAll(selectedVehicles.isEmpty ? vehicleOptions : selectedVehicles);
    draftFromDate.value = fromDate.value;
    draftToDate.value = toDate.value;
    draftEventTypes.refresh();
    draftVehicles.refresh();
  }

  void cancelFilterEdit() {
    // Discard draft — applied filters stay unchanged.
  }

  void applyFilters() {
    // Everything ticked is stored as "no filter".
    final allEvents =
        allTicked(eventTypeOptions.map((o) => o.key), draftEventTypes);
    final allVehicles = allTicked(vehicleOptions, draftVehicles);
    selectedEventTypes
      ..clear()
      ..addAll(allEvents ? const <String>[] : draftEventTypes);
    selectedVehicles
      ..clear()
      ..addAll(allVehicles ? const <String>[] : draftVehicles);
    fromDate.value = draftFromDate.value;
    toDate.value = draftToDate.value;
    selectedEventTypes.refresh();
    selectedVehicles.refresh();
    _applyLocalFilters();
    _autoPages = 0;
    _topUpFiltered();
  }

  bool get _hasActiveFilter =>
      selectedEventTypes.isNotEmpty ||
      selectedVehicles.isNotEmpty ||
      fromDate.value != null ||
      toDate.value != null;

  /// Older pages loaded on their own while a filter is on.
  int _autoPages = 0;
  static const int _maxAutoPages = 10;

  /// The filter only sees alerts already loaded (newest first). When it
  /// matches less than a page, load older pages until it fills one, the
  /// server has no more, or [_maxAutoPages] pages were tried. Without this a
  /// vehicle whose alerts are not among the newest 20 showed an empty list
  /// with nothing to scroll.
  Future<void> _topUpFiltered() async {
    while (_hasActiveFilter &&
        notifications.length < _pageSize &&
        hasMore.value &&
        !isLoading.value &&
        _autoPages < _maxAutoPages) {
      _autoPages++;
      await loadMoreNotifications();
    }
  }

  /// Ticks or unticks one alert type ([key] is the API alert key).
  void toggleDraftEventType(String key) {
    if (!draftEventTypes.remove(key)) draftEventTypes.add(key);
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

  /// Alerts for all of the user's vehicles from the main API
  /// (`GET website/alerts`, the same endpoint the Alerts page uses, without an
  /// imei so every vehicle is included). Returns the page's alerts and whether
  /// the server says another page exists, or null when the request failed.
  Future<({List<AlertModel> items, bool hasMore})?> _fetchPage(int page) async {
    try {
      final token = await getSavedObject('token');
      if (token != null) DioClient().updateToken(token.toString().trim());

      final response = await DioClient().get(
        ApiEndPoints.alerts,
        query: {'limit': '$_pageSize', 'page': '$page'},
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (status) => true,
        ),
      );

      final body = response.data;
      final data = body is Map ? body['data'] : null;
      final list = (response.statusCode == 200 && data is Map)
          ? data['alerts']
          : null;
      if (list is! List) {
        log('[Notifications] unexpected response, status=${response.statusCode}');
        return null;
      }
      final items = list
          .whereType<Map>()
          .map((e) => AlertModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // Prefer the server's pagination block; fall back to a short page.
      var more = items.length >= _pageSize;
      final pagination = (data as Map)['pagination'];
      if (pagination is Map) {
        final current = int.tryParse('${pagination['current_page']}');
        final last = int.tryParse('${pagination['last_page']}');
        if (current != null && last != null) more = current < last;
      }
      return (items: items, hasMore: more);
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
      ..addAll(page?.items ?? const [])
      ..sort((a, b) => b.date.compareTo(a.date));
    hasMore.value = page?.hasMore ?? false;
    _applyLocalFilters();
    isLoading.value = false;
  }

  Future<void> loadMoreNotifications() async {
    if (isLoading.value || !hasMore.value) return;
    isLoading.value = true;
    final page = await _fetchPage(currentPage + 1);
    if (page == null || page.items.isEmpty) {
      hasMore.value = false;
    } else {
      currentPage++;
      _all.addAll(page.items);
      hasMore.value = page.hasMore;
      _applyLocalFilters();
    }
    isLoading.value = false;
  }

  /// Event type, vehicle and date filters, applied to what has been loaded.
  void _applyLocalFilters() {
    final types = selectedEventTypes.map((e) => e.toLowerCase()).toSet();
    final from = fromDate.value;
    final to = toDate.value;

    bool matches(AlertModel a) {
      if (types.isNotEmpty &&
          !types.contains(a.filterKey.toLowerCase())) {
        return false;
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
