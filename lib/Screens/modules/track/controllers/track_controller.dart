import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/LiveTrackModel.dart';
import 'package:airotrack/Utils/Utils.dart';

class TrackController extends GetxController {
  // ─── Bottom-sheet visibility ───────────────────────────────────────────────
  final showBottomSheet = true.obs;

  void toggleBottomSheet() {
    showBottomSheet.value = !showBottomSheet.value;
  }

  // ─── Map Control ────────────────────────────────────────────────────────
  final mapController = MapController();
  final isFirstPosition = true.obs;

  void moveMapToVehicle() {
    final lat = double.tryParse(displayLatitude);
    final lng = double.tryParse(displayLongitude);
    if (lat != null && lng != null) {
      double zoom = mapController.camera.zoom;
      if (isFirstPosition.value) {
        zoom = 15.0; // Zoom in on first load
        isFirstPosition.value = false;
      }
      mapController.move(LatLng(lat, lng), zoom);
    }
  }

  // ─── Share-location dialog option ─────────────────────────────────────────
  final selectedShareOption = 'Only Once'.obs;

  void updateShareOption(String option) {
    selectedShareOption.value = option;
  }

  // ─── Geofence form (used by AddGeofenceView) ──────────────────────────────
  final TextEditingController fenceNameController = TextEditingController();
  final fenceNameError = ''.obs;

  void submitFence() {
    final name = fenceNameController.text.trim();
    if (name.isEmpty) {
      fenceNameError.value = 'Please enter a fence name';
      return;
    }
    fenceNameError.value = '';
    // TODO: implement geofence submission API call
  }

  // ─── Vehicle identity (passed via route parameters) ────────────────────────
  final vehiclePlate = ''.obs;
  final vehicleImei = ''.obs;

  // ─── Live tracking state ───────────────────────────────────────────────────
  final isLiveLoading = false.obs;

  /// Full parsed response from live_track API.
  final liveTrackData = Rxn<LiveTrackData>();
  final vehicleRotation = 0.0.obs;
  LatLng? _previousLatLng;

  // ─── Convenience getters ──────────────────────────────────────────────────
  /// Vehicle number from vehicle_info, fallback to route param.
  String get displayPlate =>
      liveTrackData.value?.vehicleInfo?.vehicleNumber ?? vehiclePlate.value;

  String get displayImei => vehicleImei.value;

  /// Speed from current_position.
  String get displaySpeed =>
      liveTrackData.value?.currentPosition?.speed?.toStringAsFixed(1) ?? '0.0';

  /// Status string directly from API ("Running", "Idle", etc.),
  /// fallback to derived status from current_position.
  String get displayStatus =>
      liveTrackData.value?.currentStatus ??
      liveTrackData.value?.currentPosition?.derivedStatus ??
      '–';

  /// Device time from current_position.
  String get displayDeviceTime =>
      liveTrackData.value?.currentPosition?.deviceTime ?? '–';

  /// last_update from current_position_api.data (server time).
  String get displayLastUpdate =>
      liveTrackData.value?.currentPositionApi?.data?.lastUpdate ?? '–';

  /// Latitude from current_position.
  String get displayLatitude =>
      liveTrackData.value?.currentPosition?.latitude ?? '–';

  /// Longitude from current_position.
  String get displayLongitude =>
      liveTrackData.value?.currentPosition?.longitude ?? '–';

  /// Ignition state from current_position.
  bool get isIgnitionOn =>
      liveTrackData.value?.currentPosition?.isIgnitionOn ?? false;

  /// GSM signal strength from currentPositionApi.data.
  String get displayGsmSignal =>
      liveTrackData.value?.currentPositionApi?.data?.gsmSignalStrength ?? '–';

  /// Network type from currentPositionApi.data.
  String get displayNetwork =>
      liveTrackData.value?.currentPositionApi?.data?.network ?? '–';

  /// Altitude from currentPositionApi.data.
  String get displayAltitude =>
      liveTrackData.value?.currentPositionApi?.data?.altitude ?? '–';

  /// Power state from current_position.
  bool get isPowerOn =>
      liveTrackData.value?.currentPosition?.isPowerOn ?? false;

  /// Derived status color.
  Color get displayStatusColor {
    final status =
        liveTrackData.value?.currentPosition?.derivedStatus ?? 'Stopped';
    switch (status) {
      case 'Running':
        return const Color(0xFF28A745);
      case 'Idle':
        return const Color(0xFFFFC107);
      case 'Inactive':
        return const Color(0xFF6C757D);
      case 'Stopped':
      default:
        return const Color(0xFFDC3545);
    }
  }

  /// Total km today from today_statistics.
  String get displayTodayKm =>
      liveTrackData.value?.todayStatistics?.totalKilometersToday
          ?.toStringAsFixed(2) ??
      '0.00';

  /// Total km traveled from vehicle_info.
  String get displayTotalKm =>
      liveTrackData.value?.vehicleInfo?.totalKilometersTraveled ?? '0.00';

  /// Today stop hours from today_statistics formatted as HH:mm.
  String get displayStoppedDuration =>
      _formatHours(liveTrackData.value?.todayStatistics?.totalStopHours);

  /// Today idle hours from today_statistics formatted as HH:mm.
  String get displayIdleDuration =>
      _formatHours(liveTrackData.value?.todayStatistics?.totalIdleHours);

  double _getBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lon1 = start.longitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final lon2 = end.longitude * math.pi / 180;
    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi + 360) % 360;
  }

  /// Running and Inactive durations are not yet provided by the API, using placeholders.
  String get displayRunningDuration => "–";
  String get displayInactiveDuration => "–";

  String _formatHours(num? hours) {
    if (hours == null) return '00:00 hrs';
    int h = hours.toInt();
    int m = ((hours - h) * 60).toInt();
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} hrs";
  }

  // ─── WebSocket state ──────────────────────────────────────────────────────
  WebSocket? _socket;
  StreamSubscription? _socketSubscription;
  bool _disposed = false;

  // ──────────────────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    final imei = Get.parameters['imei'] ?? '';
    final plate = Get.parameters['vehicleId'] ?? '';
    vehicleImei.value = imei;
    vehiclePlate.value = plate;

    if (imei.trim().isNotEmpty) {
      _initAndStartTracking(imei);
    }
  }

  Future<void> _initAndStartTracking(String imei) async {
    final token = await getSavedObject('token');
    if (token != null) {
      DioClient().updateToken(token is String ? token : token.toString());
    }
    _startLiveTracking(imei);
  }

  @override
  void onClose() {
    _disposed = true;
    _stopLiveTracking();
    fenceNameController.dispose();
    super.onClose();
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Starts live tracking for [imei] (fetches immediately, then connects via WebSocket).
  void _startLiveTracking(String imei) {
    _stopLiveTracking();
    _fetchLiveTrack(imei); // immediate first fetch for initial state
    _connectWebSocket(imei);
  }

  void _stopLiveTracking() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();
    _socket = null;
  }

  void _connectWebSocket(String imei) async {
    if (_disposed || imei.trim().isEmpty) return;

    final wsUrl = "wss://dev-api.airotrack.in/app/airotrack-key";
    try {
      _socket = await WebSocket.connect(wsUrl);
      log('WebSocket connected: $wsUrl');

      // Pusher subscribe message
      final subscribeMsg = jsonEncode({
        "event": "pusher:subscribe",
        "data": {"channel": "device.$imei"},
      });
      _socket?.add(subscribeMsg);

      _socketSubscription = _socket?.listen(
        (message) => _handleSocketMessage(message, imei),
        onError: (err) {
          log('WebSocket error: $err');
          _reconnect(imei);
        },
        onDone: () {
          log('WebSocket connection closed');
          _reconnect(imei);
        },
      );
    } catch (e) {
      log('WebSocket connection failed: $e');
      _reconnect(imei);
    }
  }

  void _reconnect(String imei) {
    if (_disposed) return;
    _socketSubscription?.cancel();
    _socket?.close();
    // Reconnect after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (!_disposed) _connectWebSocket(imei);
    });
  }

  void _handleSocketMessage(dynamic message, String imei) {
    if (_disposed || message is! String) return;

    try {
      final decoded = jsonDecode(message);
      final event = decoded['event'];

      // Handle Pusher ping/pong to keep connection alive
      if (event == 'pusher:ping') {
        _socket?.add(jsonEncode({"event": "pusher:pong", "data": {}}));
        return;
      }

      if (event == 'device.update') {
        final dataRaw = decoded['data'];
        final data = dataRaw is String ? jsonDecode(dataRaw) : dataRaw;

        if (data != null && data is Map<String, dynamic>) {
          _processUpdate(data);
        }
      }
    } catch (e) {
      log('Error parsing WebSocket message: $e');
    }
  }

  void _processUpdate(Map<String, dynamic> data) {
    if (_disposed) return;

    // Merge WS data into liveTrackData.
    // If WS data has full state (vehicle_info, current_position), use it directly.
    if (data.containsKey('current_position') ||
        data.containsKey('vehicle_info')) {
      liveTrackData.value = LiveTrackData.fromJson(data);
    } else {
      // Otherwise, update position and status selectively
      final current = liveTrackData.value;
      if (current == null) return;

      final newPosJson = data; // Assuming data itself contains pos fields
      final updatedPos = LiveCurrentPosition(
        id: newPosJson['id'] ?? current.currentPosition?.id,
        imei: newPosJson['imei'] ?? current.currentPosition?.imei,
        deviceTime:
            newPosJson['devicetime'] ??
            newPosJson['device_time'] ??
            current.currentPosition?.deviceTime,
        latitude:
            newPosJson['latitude']?.toString() ??
            current.currentPosition?.latitude,
        longitude:
            newPosJson['longitude']?.toString() ??
            current.currentPosition?.longitude,
        mode: newPosJson['mode'] ?? current.currentPosition?.mode,
        speed: newPosJson['speed'] != null
            ? num.tryParse(newPosJson['speed'].toString()) ??
                  current.currentPosition?.speed
            : current.currentPosition?.speed,
        ignition: newPosJson['ignition'] ?? current.currentPosition?.ignition,
        power: newPosJson['power'] ?? current.currentPosition?.power,
        kilometer:
            newPosJson['kilometer']?.toString() ??
            current.currentPosition?.kilometer,
      );

      liveTrackData.value = LiveTrackData(
        vehicleInfo: current.vehicleInfo,
        currentPosition: updatedPos,
        currentStatus:
            newPosJson['current_status'] ??
            newPosJson['status'] ??
            current.currentStatus,
        todayStatistics: current.todayStatistics,
        currentPositionApi: current.currentPositionApi,
      );
    }

    _onDataUpdated();
  }

  void _onDataUpdated() {
    // Calculate rotation if coordinates changed
    final lat = double.tryParse(displayLatitude);
    final lng = double.tryParse(displayLongitude);
    if (lat != null && lng != null) {
      final current = LatLng(lat, lng);
      if (_previousLatLng != null && _previousLatLng != current) {
        vehicleRotation.value = _getBearing(_previousLatLng!, current);
      }
      _previousLatLng = current;
    }

    moveMapToVehicle();
    update();
  }

  // ─── Internal fetch ────────────────────────────────────────────────────────

  Future<void> _fetchLiveTrack(String imei) async {
    if (_disposed || imei.trim().isEmpty) return;
    try {
      isLiveLoading.value = true;
      final response = await DioClient().get(
        ApiEndPoints.liveTrack,
        query: {'imei': imei.trim()},
      );

      if (_disposed) return;

      final raw = response.data;
      if (raw == null) return;

      if (raw is! Map<String, dynamic>) return;

      final model = LiveTrackModel.fromJson(raw);

      if (model.data != null) {
        liveTrackData.value = model.data;
        _onDataUpdated();
      }
    } catch (e, st) {
      if (!_disposed) {
        log('LiveTrack fetch error: $e\n$st');
      }
    } finally {
      if (!_disposed) isLiveLoading.value = false;
    }
  }

  /// Called from the Track button if the IMEI changes (re-entering the screen).
  void startTrackingForImei(String imei, {String plate = ''}) {
    if (imei.trim().isEmpty) return;
    vehicleImei.value = imei;
    if (plate.isNotEmpty) vehiclePlate.value = plate;
    liveTrackData.value = null;
    _startLiveTracking(imei);
  }
}
