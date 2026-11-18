import 'dart:io';

import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/ReportItem.dart';
import 'package:airotrack/Screens/modules/home/controllers/home_controller.dart';
import 'package:airotrack/Services/OdometerOffsetService.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'report_pdf.dart';

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

  /// Set when the first page fails, so the list shows the error and a
  /// Retry button instead of "No reports found". Empty when there's none.
  final loadError = ''.obs;
  final hasMore = true.obs;
  final selectedPeriod = 'Today'.obs;
  final selectedImei = ''.obs;
  final selectedPlate = 'All vehicles'.obs;
  final searchQuery = ''.obs;

  /// Range picked from the calendar; used when [selectedPeriod] is 'Custom'.
  final customFrom = Rxn<DateTime>();
  final customTo = Rxn<DateTime>();

  ReportType? reportType;
  var currentPage = 1;
  static const int _pageLimit = 50;
  String? _configuredKey;

  List<Vehicle> get vehicles {
    if (Get.isRegistered<HomeController>()) {
      return Get.find<HomeController>().allVehicles.toList();
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
    final key = '${type.name}|${selectedPeriod.value}|'
        '${customFrom.value}|${customTo.value}|${selectedImei.value}';
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
      if (home.allVehicles.isNotEmpty) {
        final v = home.allVehicles.first;
        final imei = v.deviceId.trim();
        if (imei.isEmpty) continue;
        selectedImei.value = imei;
        selectedPlate.value =
            v.plateNumber.isEmpty ? imei : v.plateNumber;
        await loadItems(reset: true);
        return;
      }
      if (!home.isLoading.value && home.allVehicles.isEmpty) break;
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

  void setCustomRange(DateTime from, DateTime to) {
    customFrom.value = from;
    customTo.value = to;
    selectedPeriod.value = 'Custom';
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

  /// Bumped per request. Switching vehicle or period while a request is in
  /// flight must not let the older response overwrite the newer one.
  int _requestId = 0;

  Future<void> loadItems({bool reset = true}) async {
    if (reportType == null) return;
    final imei = selectedImei.value.trim();
    if (imei.isEmpty) return;
    final requestId = ++_requestId;
    bool stale() => requestId != _requestId;
    try {
      if (reset) {
        currentPage = 1;
        hasMore.value = true;
        items.clear();
        loadError.value = '';
      }
      isLoading.value = true;
      final page = await _fetchRows(reportType!, imei, _pageLimit);
      if (stale()) return;

      if (page != null) {
        if (reset) {
          items.assignAll(page.items);
        } else {
          items.addAll(page.items);
        }
        hasMore.value =
            page.listLength > 0 && page.items.length >= _pageLimit;
      } else {
        hasMore.value = false;
      }
    } catch (e) {
      if (stale()) return;
      showErrorMessage(e);
      hasMore.value = false;
      // First page failed: say so in the list (with Retry) rather than
      // showing "No reports found", which reads as "there is no data".
      if (reset) loadError.value = _loadErrorText(e);
    } finally {
      if (!stale()) isLoading.value = false;
    }
  }

  /// The date range for the selected period (or calendar range).
  PeriodQuery get _range => PeriodQuery.fromLabel(
        selectedPeriod.value,
        customFrom: customFrom.value,
        customTo: customTo.value,
      );

  /// Up to [limit] rows of [type] for [imei] in the selected range.
  /// [listLength] is the size of the server's row list (0 for the Summary
  /// report, which sends one `summary` object); [total] is the server's
  /// total row count when it sends one. Null when the response had no body.
  Future<({List<ReportItem> items, int listLength, int? total})?> _fetchRows(
    ReportType type,
    String imei,
    int limit,
  ) async {
    await ensureApiToken();
    // Dates only: when `period` is sent the server ignores from_date/to_date
    // (week = calendar week from Monday, custom = 422), so the range the
    // app shows would not match the data.
    final results = await Future.wait<dynamic>([
      DioClient().get(
        type.endpoint,
        query: _range.toQuery(
          imei: imei,
          limit: limit,
          includePeriod: false,
        ),
      ),
      // Reports give the device's km count; shift it to the vehicle
      // odometer that Home and Track show.
      OdometerOffsetService.offsetFor(imei),
    ]);
    final response = results[0];
    final odometerOffset = results[1] as num;
    if (response.data == null) return null;

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
        type.name,
        '${type.name}_reports',
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
            json is Map
                ? OdometerOffsetService.applyTo(
                    Map<String, dynamic>.from(json),
                    odometerOffset,
                  )
                : json,
            fallbackVehicleNumber: fallbackVehicle,
          ),
        )
        .toList();
    return (
      items: parsed,
      listLength: list.length,
      total: int.tryParse('${dataMap?['total'] ?? ''}'),
    );
  }

  // ---------------------------------------------------------------------
  // Download (PDF). There is no export endpoint, so the PDF is built on the
  // phone from the report rows, like the Alerts download.
  // ---------------------------------------------------------------------

  /// Most rows the report endpoints return in one request.
  static const int _maxDownloadRows = 2000;

  /// The stoppage and trip endpoints time out (no reply in 60 s+) at 500
  /// rows, while 200 rows take 2-4 s even for a month (a week can have 850
  /// stops, a month 900 trips). The app gives up after 20 s.
  static const int _maxSlowReportDownloadRows = 200;

  static int _downloadLimit(ReportType type) =>
      (type == ReportType.stoppage || type == ReportType.trip)
          ? _maxSlowReportDownloadRows
          : _maxDownloadRows;

  /// True while a download is being prepared.
  final isDownloading = false.obs;

  /// Builds a PDF of the current report (selected vehicle and period, every
  /// row, not just the loaded ones) and opens the share sheet so it can be
  /// saved or sent.
  Future<void> downloadReport() async {
    final type = reportType;
    final imei = selectedImei.value.trim();
    if (isDownloading.value || type == null) return;
    if (imei.isEmpty) {
      Get.snackbar(
        'Select a vehicle',
        'Pick a vehicle to download its report.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    isDownloading.value = true;
    try {
      final range = _range;
      final page = await _fetchRows(type, imei, _downloadLimit(type));
      final rows = page?.items ?? const <ReportItem>[];
      if (rows.isEmpty) {
        Get.snackbar(
          'No data',
          'There is nothing in this report for the selected period.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final from = DateTime.parse(range.fromDate);
      final to = DateTime.parse(range.toDate);
      final total = page?.total;
      final bytes = await ReportPdf.build(
        type: type,
        vehicle: selectedPlate.value,
        from: from,
        to: to,
        rows: rows,
        total: (total != null && total > rows.length) ? total : null,
      );

      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd');
      final plate = selectedPlate.value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      final name = '${type.name}_report_${plate}_'
          '${stamp.format(from)}_${stamp.format(to)}.pdf';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: name,
        ),
      );
    } catch (e) {
      debugPrint('[Reports] Download failed: $e');
      Get.snackbar(
        'Error',
        'Could not prepare the report file. Try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isDownloading.value = false;
    }
  }

  static String _loadErrorText(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'The server took too long to respond.';
        case DioExceptionType.connectionError:
          return 'No connection to the server.';
        default:
          break;
      }
    }
    return "Couldn't load this report.";
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
