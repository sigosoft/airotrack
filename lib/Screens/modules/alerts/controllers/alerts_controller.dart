import 'package:flutter/material.dart';
import 'package:get/get.dart' hide FormData;
import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Screens/modules/settings/controllers/configure_alerts_controller.dart'
    show AlertTypeOption, ConfigureAlertsController;
import 'package:airotrack/Services/ReverseGeocodeService.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

class AlertModel {
  final int id;
  final String deviceName;
  final String plateNumber;
  final String date;
  final String type;
  /// API `alert` key, e.g. "ignitionOn". The event filter matches on it.
  final String alertKey;
  /// Server text for the event, e.g. "MC2...: Vehicle ignition turned ON".
  final String content;
  /// Filled from the server, or looked up from [lat]/[lng] when missing.
  String address;
  final double? lat;
  final double? lng;
  final bool isIgnitionOn;

  AlertModel({
    required this.id,
    required this.deviceName,
    required this.plateNumber,
    required this.date,
    required this.type,
    required this.address,  
    this.content = '',
    this.alertKey = '',
    this.lat,
    this.lng,
    this.isIgnitionOn = false,
  });

  static String _first(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k]?.toString().trim();
      if (v != null && v.isNotEmpty && v != 'null') return v;
    }
    return '';
  }

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    final ignition = json['ignition']?.toString().trim();
    var type = _first(json, [
      'event',
      'alert_description',
      'alert_type',
      'type',
      'description',
      'message',
      'title',
    ]);
    if (type.isEmpty && (ignition == '1' || ignition == '0')) {
      type = ignition == '1' ? 'Ignition On' : 'Ignition Off';
    }
    final lower = type.toLowerCase();
    final isOn = lower.contains('ignition on')
        ? true
        : lower.contains('ignition off')
            ? false
            : ignition == '1';

    final address = _first(json, ['address', 'location']);
    final lat = double.tryParse(_first(json, ['latitude', 'lat']));
    final lng = double.tryParse(_first(json, ['longitude', 'lng', 'lon']));

    final plate = _first(json, ['vehicle_number', 'vehicle_name']);
    return AlertModel(
      id: int.tryParse(_first(json, ['id'])) ?? 0,
      deviceName: plate,
      plateNumber: plate,
      date: _first(json, ['datetime', 'device_time', 'created_at']),
      type: type,
      content: _first(json, ['content']),
      alertKey: _first(json, ['alert']),
      address: address,
      lat: (lat == 0 && lng == 0) ? null : lat,
      lng: (lat == 0 && lng == 0) ? null : lng,
      isIgnitionOn: isOn,
    );
  }
}

class AlertsController extends GetxController {
  /// Page size the alerts API returns; it reports `limit: 50` for the request.
  static const int pageSize = 50;

  /// Safety cap for a download: 200 pages is 10,000 alerts.
  static const int _maxDownloadPages = 200;

  /// True while a download is being prepared.
  final isDownloading = false.obs;

  final ScrollController scrollController = ScrollController();
  /// Everything loaded from the server.
  final allAlerts = <AlertModel>[].obs;

  /// What the list shows: [allAlerts] after search and filters.
  var alerts = <AlertModel>[].obs;

  final searchQuery = ''.obs;
  final selectedTypes = <String>{}.obs;
  final selectedVehicles = <String>{}.obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();
  var isLoading = false.obs;
  var hasMore = true.obs;
  var currentPage = 1;

  /// Event types present in the loaded alerts, for the filter sheet.
  List<String> get eventTypes => _distinct(allAlerts.map((a) => a.type));

  /// Every alert type from `alert_types` (key + label). The filter sheet
  /// always lists all of them. Starts with the built-in list so the sheet is
  /// never empty while the request is in flight or if it fails.
  final alertTypeOptions = <AlertTypeOption>[
    ...ConfigureAlertsController.defaultAlertTypes,
  ].obs;

  /// True when [selectedTypes] covers every alert type, i.e. "All Events".
  bool get allTypesSelected =>
      alertTypeOptions.every((o) => selectedTypes.contains(o.key));

  /// Vehicle whose `vehicle_alerts` set the event ticks; empty when the page
  /// is not for one vehicle (then Apply only filters, nothing is saved).
  String vehicleImei = '';

  /// Plate of [vehicleImei], for the saved message.
  String get vehiclePlate =>
      (Get.parameters['trackPlate'] ?? Get.parameters['vehicleId'] ?? '')
          .trim();

  /// Alert keys last loaded from or saved to `vehicle_alerts`, so Apply only
  /// calls `update_vehicle_alerts` when the ticks really changed.
  final Set<String> _savedVehicleTypes = {};

  final isSavingTypes = false.obs;

  /// True when [types] differ from what the vehicle has saved.
  bool vehicleTypesChanged(Set<String> types) =>
      vehicleImei.isNotEmpty &&
      (types.length != _savedVehicleTypes.length ||
          !types.every(_savedVehicleTypes.contains));

  /// Saves [types] as the vehicle's switched-on alerts with
  /// `update_vehicle_alerts` (form data: imei plus repeated `alerts[]`, the
  /// same request Configure Alerts sends). Returns false when it failed.
  Future<bool> saveVehicleAlertTypes(Set<String> types) async {
    if (vehicleImei.isEmpty) return true;
    isSavingTypes.value = true;
    try {
      await ensureApiToken();
      final form = FormData();
      form.fields.add(MapEntry('imei', vehicleImei));
      for (final key in types) {
        form.fields.add(MapEntry('alerts[]', key));
      }
      final response = await DioClient().post(
        ApiEndPoints.updateVehicleAlerts,
        body: form,
      );
      final body = response.data;
      final ok = body is! Map || body['status'] != false;
      if (!ok) {
        showErrorMessage(body['message'] ?? 'Could not save alerts');
        return false;
      }
      _savedVehicleTypes
        ..clear()
        ..addAll(types);
      return true;
    } catch (e) {
      showErrorMessage(e);
      return false;
    } finally {
      isSavingTypes.value = false;
    }
  }

  /// Vehicle numbers present in the loaded alerts, for the filter sheet.
  List<String> get vehicleNumbers =>
      _distinct(allAlerts.map((a) => a.plateNumber));

  List<String> _distinct(Iterable<String> values) {
    final list = values.where((v) => v.isNotEmpty).toSet().toList();
    list.sort();
    return list;
  }

  @override
  void onInit() {
    super.onInit();
    log("AlertsController: onInit called");
    // Until the types arrive, every built-in type is ticked ("All Events").
    selectedTypes.addAll(alertTypeOptions.map((o) => o.key));
    loadAlerts();
    unawaited(_loadEventTypeFilter());
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

  /// Lists every type from `alert_types`, then ticks the ones switched on for
  /// this vehicle in `vehicle_alerts`. Without a vehicle (all vehicles), or if
  /// that request fails or returns nothing usable, every type stays ticked.
  Future<void> _loadEventTypeFilter() async {
    try {
      await ensureApiToken();
      final response = await DioClient().get(ApiEndPoints.alertTypes);
      final data = response.data is Map ? response.data['data'] : null;
      final list = data is Map ? data['alerts'] : null;
      final parsed = <AlertTypeOption>[];
      if (list is List) {
        for (final item in list.whereType<Map>()) {
          final key = (item['key'] ?? '').toString();
          if (key.isEmpty) continue;
          parsed.add(AlertTypeOption(key, (item['label'] ?? key).toString()));
        }
      }
      if (parsed.isNotEmpty) alertTypeOptions.assignAll(parsed);
    } catch (e) {
      log('[Alerts] alert_types failed, using built-in list: $e');
    }

    final allKeys = alertTypeOptions.map((o) => o.key).toSet();
    var initial = allKeys;

    // The vehicle this page was opened for: `imei` when the list is for one
    // vehicle, `trackImei` when opened from that vehicle's live track (the
    // list then shows every vehicle, but the ticks follow this vehicle).
    var imei = (Get.parameters['imei'] ?? '').trim();
    if (imei.isEmpty) imei = (Get.parameters['trackImei'] ?? '').trim();
    if (imei.isNotEmpty) {
      try {
        final response = await DioClient().get(
          ApiEndPoints.vehicleAlerts,
          query: {'imei': imei},
        );
        final body = response.data;
        final data = body is Map ? body['data'] : body;
        final list =
            data is List ? data : (data is Map ? data['alerts'] : null);
        final onKeys = <String>{};
        if (list is List) {
          for (final item in list) {
            if (item is String) {
              onKeys.add(item);
            } else if (item is Map && item['alert'] != null) {
              onKeys.add(item['alert'].toString());
            }
          }
        }
        final vehicleKeys = allKeys.intersection(onKeys);
        if (vehicleKeys.isNotEmpty) initial = vehicleKeys;
        // Saving is only safe once we know what the vehicle has today.
        vehicleImei = imei;
        _savedVehicleTypes
          ..clear()
          ..addAll(vehicleKeys);
      } catch (e) {
        log('[Alerts] vehicle_alerts failed, ticking all events: $e');
      }
    }

    if (isClosed) return;
    selectedTypes
      ..clear()
      ..addAll(initial);
    applyFilters();
  }

  Future<void> loadAlerts() async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      currentPage = 1;
      final page = await _fetchPage(1);
      allAlerts.assignAll(page);
      applyFilters();
      unawaited(_fillMissingAddresses());
    } catch (e) {
      log("[Alerts] Load failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMoreAlerts() async {
    if (isLoading.value || !hasMore.value) return;
    try {
      isLoading.value = true;
      final page = await _fetchPage(currentPage + 1);
      allAlerts.addAll(page);
      applyFilters();
      unawaited(_fillMissingAddresses());
    } catch (e) {
      log("[Alerts] Load more failed: $e");
      hasMore.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Requests one page with imei, limit and page, and reads the server's
  /// pagination block to know whether another page exists.
  Future<List<AlertModel>> _fetchPage(int page) async {
    final result = await _requestPage(page);
    currentPage = result.current;
    hasMore.value = result.current < result.last;
    return result.items;
  }

  /// One page from the server. Does not touch the list state, so downloads
  /// can read other pages without disturbing scrolling.
  Future<({List<AlertModel> items, int current, int last})> _requestPage(
    int page,
  ) async {
    final token = await getSavedObject('token');
    if (token != null) {
      DioClient().updateToken(token.toString().trim());
    }

    final response = await DioClient().get(
      ApiEndPoints.alerts,
      query: {
        'imei': Get.parameters['imei'] ?? '',
        'limit': '$pageSize',
        'page': '$page',
      },
      options: Options(
        headers: {"Accept": "application/json"},
        validateStatus: (status) => true,
      ),
    );

    final body = response.data;
    final data = body is Map ? body['data'] : null;
    if (response.statusCode != 200 || data is! Map) {
      throw Exception('Alerts request failed: ${response.statusCode}');
    }

    // Without pagination info, treat this as the only page.
    var current = page;
    var last = page;
    final pagination = data['pagination'];
    if (pagination is Map) {
      current = int.tryParse('${pagination['current_page']}') ?? page;
      last = int.tryParse('${pagination['last_page']}') ?? current;
    }

    final list = data['alerts'];
    final items = list is List
        ? list
            .map((json) => AlertModel.fromJson(Map<String, dynamic>.from(json)))
            .toList()
        : <AlertModel>[];
    return (items: items, current: current, last: last);
  }

  /// Alerts from [from] to [to] (both days included), newest first.
  /// The server sends newest first, so paging stops once a page runs past [from].
  Future<List<AlertModel>> alertsBetween(DateTime from, DateTime to) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day + 1);
    final result = <AlertModel>[];

    var page = 1;
    while (page <= _maxDownloadPages) {
      final response = await _requestPage(page);
      var passedStart = false;
      for (final a in response.items) {
        final d = DateTime.tryParse(a.date);
        if (d == null) continue;
        if (d.isBefore(start)) {
          passedStart = true;
          continue;
        }
        if (d.isBefore(end)) result.add(a);
      }
      if (passedStart || response.items.isEmpty) break;
      if (response.current >= response.last) break;
      page = response.current + 1;
    }
    return result;
  }

  /// Builds the CSV and opens the share sheet, so the user can save or send it.
  Future<void> downloadAlerts(DateTime from, DateTime to) async {
    if (isDownloading.value) return;
    isDownloading.value = true;
    try {
      final items = await alertsBetween(from, to);
      if (items.isEmpty) {
        Get.snackbar(
          'No alerts',
          'No alerts found for this date range',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd');
      final name = 'alerts_${stamp.format(from)}_${stamp.format(to)}.pdf';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(await _buildPdf(items, from, to));

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: name,
        ),
      );
    } catch (e) {
      log("[Alerts] Download failed: $e");
      Get.snackbar(
        'Error',
        'Could not prepare the alerts file. Try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isDownloading.value = false;
    }
  }

  /// A4 table: Vehicle Number, Event, Content, Date Time.
  Future<Uint8List> _buildPdf(
    List<AlertModel> items,
    DateTime from,
    DateTime to,
  ) async {
    final dateFormat = DateFormat('dd MMM yyyy');
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text(
            'Alerts  ${dateFormat.format(from)} - ${dateFormat.format(to)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Vehicle Number', 'Event', 'Content', 'Date Time'],
            data: [
              for (final a in items)
                [a.plateNumber, a.type, a.content, a.date],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(4),
              3: const pw.FlexColumnWidth(2),
            },
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// Rebuilds [alerts] from [allAlerts] using the search text, event types,
  /// vehicles and date range. Empty filters match everything.
  void applyFilters() {
    final query = searchQuery.value.trim().toLowerCase();
    // Every type ticked ("All Events") or none ticked: no event filter.
    final types = allTypesSelected
        ? <String>{}
        : selectedTypes.map((e) => e.toLowerCase()).toSet();
    final from = fromDate.value;
    final to = toDate.value;

    bool matches(AlertModel a) {
      if (query.isNotEmpty) {
        final haystack =
            '${a.plateNumber} ${a.deviceName} ${a.type} ${a.content} ${a.address}'
                .toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      if (types.isNotEmpty) {
        if (!types.contains(a.alertKey.toLowerCase())) return false;
      }
      if (selectedVehicles.isNotEmpty &&
          !selectedVehicles.contains(a.plateNumber)) {
        return false;
      }
      if (from != null || to != null) {
        final d = DateTime.tryParse(a.date);
        if (d != null) {
          if (from != null &&
              d.isBefore(DateTime(from.year, from.month, from.day))) {
            return false;
          }
          if (to != null &&
              !d.isBefore(DateTime(to.year, to.month, to.day + 1))) {
            return false;
          }
        }
      }
      return true;
    }

    alerts.assignAll(allAlerts.where(matches));
  }

  final Map<String, String> _addressCache = {};

  /// Alerts that arrive without an address text get one from their position.
  Future<void> _fillMissingAddresses() async {
    final pending = allAlerts
        .where((a) => a.address.isEmpty && a.lat != null && a.lng != null)
        .toList();
    for (final a in pending) {
      final key = '${a.lat!.toStringAsFixed(4)},${a.lng!.toStringAsFixed(4)}';
      var place = _addressCache[key];
      if (place == null) {
        try {
          place = await ReverseGeocodeService.instance.reverse(a.lat!, a.lng!);
        } catch (_) {}
        if (place == null || place.trim().isEmpty) continue;
        _addressCache[key] = place;
      }
      a.address = place;
      alerts.refresh();
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
