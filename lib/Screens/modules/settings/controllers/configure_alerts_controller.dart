import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide FormData;

/// One alert type a vehicle can be configured for. [key] is the API value.
class AlertTypeOption {
  final String key;
  final String label;
  const AlertTypeOption(this.key, this.label);
}

class VehicleAlertRow {
  final int id;
  final String plateNumber;
  final String imei;

  const VehicleAlertRow({
    required this.id,
    required this.plateNumber,
    required this.imei,
  });

  factory VehicleAlertRow.fromJson(Map<String, dynamic> json) {
    return VehicleAlertRow(
      id: int.tryParse('${json['id']}') ?? 0,
      plateNumber: (json['vehicle_number'] ?? '').toString(),
      imei: (json['imei'] ?? '').toString(),
    );
  }
}

class ConfigureAlertsController extends GetxController {
  /// Used only if the alert_types request fails.
  static const List<AlertTypeOption> defaultAlertTypes = [
    AlertTypeOption('ignitionOn', 'Ignition On'),
    AlertTypeOption('ignitionOff', 'Ignition Off'),
    AlertTypeOption('emergencyOn', 'Emergency On'),
    AlertTypeOption('emergencyOff', 'Emergency Off'),
    AlertTypeOption('wireDisconnect', 'Wire Disconnect'),
    AlertTypeOption('powerDisconnect', 'Power Disconnect'),
    AlertTypeOption('powerRestored', 'Power Restored'),
    AlertTypeOption('tilt', 'Tilt'),
    AlertTypeOption('boxOpen', 'Box Open'),
    AlertTypeOption('rashTurning', 'Rash Turning'),
    AlertTypeOption('deviceOverspeed', 'Device Overspeed'),
    AlertTypeOption('geofenceEntry', 'Geofence Entry'),
    AlertTypeOption('geofenceExit', 'Geofence Exit'),
    AlertTypeOption('geofenceOverspeed', 'Geofence Overspeed'),
    AlertTypeOption('impactCrash', 'Impact Crash'),
  ];

  /// Alert types from the server (`alert_types`), with the labels it sends.
  final alertOptions = <AlertTypeOption>[].obs;


  final vehicles = <VehicleAlertRow>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final searchQuery = ''.obs;

  /// Alert keys switched on for the vehicle being edited.
  final selectedAlerts = <String>{}.obs;

  List<VehicleAlertRow> get filteredVehicles {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return vehicles.toList();
    return vehicles
        .where(
          (v) =>
              v.plateNumber.toLowerCase().contains(q) ||
              v.imei.toLowerCase().contains(q),
        )
        .toList();
  }

  /// True when every alert type is switched on.
  bool get allSelected =>
      alertOptions.isNotEmpty &&
      alertOptions.every((o) => selectedAlerts.contains(o.key));

  /// Server label for [key], or the key itself when the list has no label.
  String labelFor(String key) => alertOptions
      .firstWhere((o) => o.key == key, orElse: () => AlertTypeOption(key, key))
      .label;

  /// True when some, but not all, alert types are switched on.
  bool get someSelected => selectedAlerts.isNotEmpty && !allSelected;

  @override
  void onInit() {
    super.onInit();
    loadVehicles();
  }

  /// Reads the alert list from the server. Falls back to the built-in list.
  Future<void> loadAlertTypes() async {
    try {
      await ensureApiToken();
      final response = await DioClient().get(ApiEndPoints.alertTypes);
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      final list = data is Map ? data['alerts'] : null;
      final parsed = <AlertTypeOption>[];
      if (list is List) {
        for (final item in list.whereType<Map>()) {
          final key = (item['key'] ?? '').toString();
          if (key.isEmpty) continue;
          parsed.add(AlertTypeOption(key, (item['label'] ?? key).toString()));
        }
      }
      alertOptions.assignAll(parsed.isEmpty ? defaultAlertTypes : parsed);
    } catch (e) {
      debugPrint('[ConfigureAlerts] alert_types failed: $e');
      alertOptions.assignAll(defaultAlertTypes);
    }
  }

  Future<void> loadVehicles() async {
    try {
      isLoading.value = true;
      await ensureApiToken();
      final response = await DioClient().get(ApiEndPoints.vehicles);
      final data = response.data is Map ? response.data['data'] : null;
      final list = data is Map ? data['vehicles'] : null;
      if (list is List) {
        vehicles.assignAll(
          list
              .whereType<Map>()
              .map((e) => VehicleAlertRow.fromJson(Map<String, dynamic>.from(e))),
        );
      }
    } catch (e) {
      showErrorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Loads the alerts already switched on for [imei].
  /// The response shape is not confirmed; this accepts a list of keys, or of
  /// objects with an `alert` field, under `data` or `data.alerts`.
  /// Ticks every alert type (from `alert_types`) that is in the vehicle's
  /// `vehicle_alerts` list. Types not in that list stay unticked. Returns false
  /// if the request failed, so the checklist is not opened with a wrong state.
  Future<bool> loadVehicleAlerts(String imei) async {
    selectedImei = imei;
    selectedAlerts.clear();
    try {
      await ensureApiToken();
      final response = await DioClient().get(
        ApiEndPoints.vehicleAlerts,
        query: {'imei': imei},
      );
      final body = response.data;
      final data = body is Map ? body['data'] : body;
      final list = data is List ? data : (data is Map ? data['alerts'] : null);
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
      selectedAlerts.assignAll(
        alertOptions.map((o) => o.key).where(onKeys.contains),
      );
      return true;
    } catch (e) {
      showErrorMessage(e);
      return false;
    }
  }

  /// IMEI of the vehicle whose checklist is open.
  String selectedImei = '';

  /// Ticking or unticking changes the list only. Nothing is sent until Submit.
  void toggleAlert(String key) {
    if (!selectedAlerts.remove(key)) selectedAlerts.add(key);
  }

  /// All Alerts: ticks every alert the vehicle has, or clears them all.
  void toggleAll() {
    if (allSelected) {
      selectedAlerts.clear();
    } else {
      selectedAlerts.assignAll(alertOptions.map((o) => o.key));
    }
  }

  /// Saves the switched-on alerts for [imei] as form data, the same as the
  /// `update_vehicle_alerts` Postman request (imei plus repeated `alerts[]`).
  Future<bool> saveVehicleAlerts(String imei) async {
    isSaving.value = true;
    try {
      await ensureApiToken();
      final form = FormData();
      form.fields.add(MapEntry('imei', imei));
      for (final key in selectedAlerts) {
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
      return true;
    } catch (e) {
      showErrorMessage(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
