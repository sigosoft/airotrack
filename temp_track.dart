import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/LiveTrackModel.dart';
import 'package:airotrack/Utils/Utils.dart';

class TrackController extends GetxController {
  // ÔöÇÔöÇÔöÇ Bottom-sheet visibility ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  final showBottomSheet = true.obs;

  void toggleBottomSheet() {
    showBottomSheet.value = !showBottomSheet.value;
  }

  // ÔöÇÔöÇÔöÇ Map Control ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  final mapController = MapController();
  final isFirstPosition = true.obs;

  void moveMapToVehicle({bool force = false}) {
    if (_disposed) return;

    // Smooth camera: prioritize animated coords if available
    final lat = animatedLat.value != 0.0
        ? animatedLat.value
        : double.tryParse(displayLatitude);
    final lng = animatedLng.value != 0.0
        ? animatedLng.value
        : double.tryParse(displayLongitude);

    if (lat != null && lng != null) {
      try {
        double zoom = 15.0;
        try {
          zoom = mapController.camera.zoom;
        } catch (_) {}

        final now = DateTime.now();
        final isFirst = isFirstPosition.value;

        // Smooth camera follow: Match car's 25ms animation loop for zero-snap movement
        final throttleMs = animatedLat.value != 0.0 ? 0 : 1000;
        final delta = now.difference(_lastMapUpdate).inMilliseconds;

        if (isFirst || force || delta >= throttleMs) {
          if (isFirst) zoom = 15.0;
          // Use direct move instead of post-frame callback if it's safe to eliminate one-frame lag
          try {
            mapController.move(LatLng(lat, lng), zoom);
          } catch (_) {
            // Fallback for rare cases where map is not ready
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_disposed) {
                try {
                  mapController.move(LatLng(lat, lng), zoom);
                } catch (_) {}
              }
            });
          }
          isFirstPosition.value = false;
          _lastMapUpdate = now;
        }
      } catch (e) {
        // Map might not be fully built/ready yet. Retry shortly once rendered.
        Future.delayed(const Duration(milliseconds: 100), () {
          try {
            if (isFirstPosition.value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_disposed) {
                  try {
                    mapController.move(LatLng(lat, lng), 15.0);
                  } catch (_) {}
                }
              });
              isFirstPosition.value = false;
              _lastMapUpdate = DateTime.now();
            }
          } catch (_) {}
        });
      }
    }
  }

  // ÔöÇÔöÇÔöÇ Share-location dialog option ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  final selectedShareOption = 'Only Once'.obs;

  void updateShareOption(String option) {
    selectedShareOption.value = option;
  }

  // ÔöÇÔöÇÔöÇ Geofence form (used by AddGeofenceView) ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
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

  // ÔöÇÔöÇÔöÇ Vehicle identity (passed via route parameters) ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  final vehiclePlate = ''.obs;
  final vehicleImei = ''.obs;

  // ÔöÇÔöÇÔöÇ Live tracking state ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  final isLiveLoading = false.obs;

  /// Full parsed response from live_track API.
  final liveTrackData = Rxn<LiveTrackData>();
  final vehicleRotation = 0.0.obs;
  final reactiveMarkers = <Marker>[].obs;

  // Animated position for smooth movement
  final animatedLat = 0.0.obs;
  final animatedLng = 0.0.obs;
  final animatedRotation = 0.0.obs; // Smooth rotation to avoid snapping

  Timer? _interpolationTimer;
  Timer? _rotationTimer;
  Timer? _pollingTimer;

  LatLng? _previousLatLng;
  DateTime? _lastDataTime;

  // ÔöÇÔöÇÔöÇ Convenience getters ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
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
      'ÔÇô';

  /// Device time from current_position.
  String get displayDeviceTime =>
      liveTrackData.value?.currentPosition?.deviceTime ?? 'ÔÇô';

  /// last_update from current_position_api.data (server time).
  String get displayLastUpdate =>
      liveTrackData.value?.currentPositionApi?.data?.lastUpdate ?? 'ÔÇô';

  /// Latitude from current_position. Optimized for smooth animation focus.
  String get displayLatitude => animatedLat.value != 0.0
      ? animatedLat.value.toStringAsFixed(7)
      : (liveTrackData.value?.currentPosition?.latitude ?? 'ÔÇô');

  /// Longitude from current_position. Optimized for smooth animation focus.
  String get displayLongitude => animatedLng.value != 0.0
      ? animatedLng.value.toStringAsFixed(7)
      : (liveTrackData.value?.currentPosition?.longitude ?? 'ÔÇô');

  /// Ignition state from current_position.
  bool get isIgnitionOn =>
      liveTrackData.value?.currentPosition?.isIgnitionOn ?? false;

  /// GSM signal strength from currentPositionApi.data.
  String get displayGsmSignal =>
      liveTrackData.value?.currentPositionApi?.data?.gsmSignalStrength ?? 'ÔÇô';

  /// Network type from currentPositionApi.data.
  String get displayNetwork =>
      liveTrackData.value?.currentPositionApi?.data?.network ?? 'ÔÇô';

  /// Altitude from currentPositionApi.data.
  String get displayAltitude =>
      liveTrackData.value?.currentPositionApi?.data?.altitude ?? 'ÔÇô';

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

  void _updateMarkers() {
    final lat = animatedLat.value;
    final lng = animatedLng.value;
    if (lat == 0.0 || lng == 0.0) {
      reactiveMarkers.clear();
      return;
    }

    reactiveMarkers.value = [
      Marker(
        point: LatLng(lat, lng),
        width: 100,
        height: 100,
        child: GestureDetector(
          onTap: () => toggleBottomSheet(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: displayStatusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    displayPlate,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                size: 12,
                color: Colors.black54,
              ),
              Obx(
                () => Transform.rotate(
                  angle: (animatedRotation.value - 45) * (math.pi / 180),
                  child: Image.asset(
                    'lib/Asset/Icons/Track Vehicle.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// Optimized marker builder to avoid full map rebuilds on every WebSocket update.
  RxList<Marker> get mapMarkers => reactiveMarkers;

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
  String get displayRunningDuration => "ÔÇô";
  String get displayInactiveDuration => "ÔÇô";

  String _formatHours(num? hours) {
    if (hours == null) return '00:00 hrs';
    int h = hours.toInt();
    int m = ((hours - h) * 60).toInt();
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} hrs";
  }

  // ÔöÇÔöÇÔöÇ WebSocket state ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ
  WebSocket? _socket;
  StreamSubscription? _socketSubscription;
  bool _disposed = false;

  // Throttling for map updates to prevent Signal 3 (ANR) during rapid WebSocket data
  DateTime _lastMapUpdate = DateTime.now();

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
    log("TrackController onClose for IMEI: ${vehicleImei.value}");
    _disposed = true;
    _interpolationTimer?.cancel();
    _pollingTimer?.cancel();
    _stopLiveTracking();
    fenceNameController.dispose();
    super.onClose();
  }

  // ÔöÇÔöÇÔöÇ Live tracking control ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

  /// Starts live tracking:
  ///  1. Fetches vehicle info + statistics from the legacy API (once).
  ///  2. Fetches the latest real-time position from the TCP API (once).
  ///  3. Opens the WebSocket and subscribes ÔÇö all subsequent updates are push-only.
  void _startLiveTracking(String imei) {
    _stopLiveTracking();
    _fetchLiveTrack(imei); // vehicle info + today statistics (legacy API)
    _fetchTcpPosition(imei); // initial real-time position (new TCP API)
    _connectWebSocket(imei); // push updates
    _ensurePolling(imei); // Robust 1s polling fallback active FROM START
  }

  void _stopLiveTracking() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();
    _socket = null;
  }

  void _connectWebSocket(String imei) async {
    if (_disposed || imei.trim().isEmpty) return;

    const wsUrl = "wss://dev-api.airotrack.in/app/airotrack-key";
    try {
      _socket = await WebSocket.connect(wsUrl);
      if (_disposed) {
        _socket?.close();
        return;
      }
      log('WebSocket connected: $wsUrl');

      final subscribeMsg = jsonEncode({
        "event": "pusher:subscribe",
        "data": {"channel": "device.$imei"},
      });
      log('WebSocket Sending: $subscribeMsg');
      _socket?.add(subscribeMsg);

      _socketSubscription = _socket?.listen(
        (message) {
          // Log only the first 100 chars to avoid crashing the console buffer
          final msgStr = message.toString();
          log(
            'WS Received: ${msgStr.substring(0, math.min(100, msgStr.length))}...',
          );
          _handleSocketMessage(message, imei);
        },
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
      _ensurePolling(imei); // Fallback to REST polling if WS fails
    }
  }

  /// Ensures REST polling is active as a fallback.
  void _ensurePolling(String imei) {
    if (_disposed || imei.trim().isEmpty) return;
    if (_pollingTimer != null && _pollingTimer!.isActive) return;
    // We start polling immediately when called, then periodic
    _fetchTcpPosition(imei);
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      _fetchTcpPosition(imei);
    });
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
      log('Handling Socket Message Event: $event');

      // Keep the connection alive
      if (event == 'pusher:ping') {
        _socket?.add(jsonEncode({"event": "pusher:pong", "data": {}}));
        return;
      }

      if (event == 'device.update') {
        _pollingTimer?.cancel(); // Reset polling timer as WS is working
        _ensurePolling(imei); // Reschedule next fallback poll
        // Per API guide: 'data' is a JSON string.
        // Parsed outer shape: { "imei": "...", "data": { ...device fields... }, "timestamp": "..." }
        // The actual device fields are inside the nested 'data' key.
        final dataRaw = decoded['data'];
        final outer = dataRaw is String ? jsonDecode(dataRaw) : dataRaw;

        if (outer is Map<String, dynamic>) {
          final inner = outer['data'];
          final payloadImei = outer['imei']?.toString() ?? 'Unknown';

          // Only process updates if this is the active route to prevent Signal 3 (ANR)
          // Background controllers shouldn't move maps or rebuild UI.
          final currentRoute = Get.currentRoute;
          if (currentRoute.contains('track') || currentRoute.contains('home')) {
            log('WebSocket: Processing update for IMEI: $payloadImei');
            if (inner is Map<String, dynamic>) {
              _processUpdate(inner);
            }
          }
        }
      }
    } catch (e) {
      log('Error parsing WebSocket message: $e');
    }
  }

  /// Maps flat TCP device data (from REST or WebSocket) into [LiveTrackData],
  /// preserving vehicle_info and today_statistics from any prior data.
  LiveTrackData _mergeTcpData(
    Map<String, dynamic> tcp, {
    LiveTrackData? existing,
  }) {
    final pos = LiveCurrentPosition(
      imei: tcp['imei']?.toString(),
      latitude: tcp['latitude']?.toString(),
      longitude: tcp['longitude']?.toString(),
      speed: tcp['speed'] as num?,
      deviceTime: tcp['devicetime']?.toString(),
      ignition: tcp['ignition'] as int?,
      power: tcp['power'] as int?,
      mode: tcp['mode']?.toString(),
      kilometer: null,
    );

    final posApi = LiveCurrentPositionApi(
      success: true,
      data: LiveCurrentPositionApiData(
        imei: tcp['imei']?.toString(),
        deviceId: tcp['deviceid'] as int?,
        latitude: tcp['latitude']?.toString(),
        longitude: tcp['longitude']?.toString(),
        speed: tcp['speed'] as num?,
        deviceTime: tcp['devicetime']?.toString(),
        ignition: tcp['ignition'] as int?,
        power: tcp['power'] as int?,
        altitude: tcp['altitude']?.toString(),
        gsmSignalStrength: tcp['gsm_signal_strength']?.toString(),
        mode: tcp['mode']?.toString(),
        network: tcp['network']?.toString(),
        lastUpdate: tcp['last_update']?.toString(),
      ),
    );

    return LiveTrackData(
      vehicleInfo: existing?.vehicleInfo, // kept from legacy API
      currentPosition: pos,
      currentStatus: pos.derivedStatus,
      todayStatistics: existing?.todayStatistics, // kept from legacy API
      currentPositionApi: posApi,
    );
  }

  /// Updates [liveTrackData] from a parsed TCP device data map (WebSocket push).
  void _processUpdate(Map<String, dynamic> tcp) {
    if (_disposed) return;
    liveTrackData.value = _mergeTcpData(tcp, existing: liveTrackData.value);
    _onDataUpdated();
  }

  void _onDataUpdated() {
    // Calculate rotation if coordinates changed
    final pos = liveTrackData.value?.currentPosition;
    if (pos == null) return;

    final dynamic latRaw = pos.latitude;
    final dynamic lngRaw = pos.longitude;

    double? lat;
    double? lng;

    if (latRaw is double) {
      lat = latRaw;
    } else if (latRaw is String) {
      lat = double.tryParse(latRaw);
    } else if (latRaw is int) {
      lat = latRaw.toDouble();
    }

    if (lngRaw is double) {
      lng = lngRaw;
    } else if (lngRaw is String) {
      lng = double.tryParse(lngRaw);
    } else if (lngRaw is int) {
      lng = lngRaw.toDouble();
    }

    if (lat != null && lng != null) {
      final target = LatLng(lat, lng);
      final now = DateTime.now();

      // Fully Continuous Glide (Zomato-style): use 5s baseline to fill intervals.
      int durationMs = 5000;
      if (_lastDataTime != null) {
        int intervalMs = now.difference(_lastDataTime!).inMilliseconds;
        // Stretch 1.1x to bridge the gap gracefully
        durationMs = (intervalMs * 1.1).toInt();
        if (durationMs < 5000) durationMs = 5000;
        if (durationMs > 60000) durationMs = 60000;
      }
      _lastDataTime = now;

      // Smoothed target: mix with current to avoid "offset road" jitter
      double smoothedLat = target.latitude;
      double smoothedLng = target.longitude;
      if (animatedLat.value != 0.0) {
        // Weighted average for smoother road tracking (80% new, 20% current)
        smoothedLat = (target.latitude * 0.8) + (animatedLat.value * 0.2);
        smoothedLng = (target.longitude * 0.8) + (animatedLng.value * 0.2);
      }
      final smoothedTarget = LatLng(smoothedLat, smoothedLng);

      // Initialize animated pos if first load
      if (animatedLat.value == 0.0) {
        animatedLat.value = target.latitude;
        animatedLng.value = target.longitude;
      }

      // Smooth interpolation over the dynamically calculated duration
      _animateTo(smoothedTarget, target, Duration(milliseconds: durationMs));

      if (_previousLatLng != null && _previousLatLng != target) {
        _animateRotation(_getBearing(_previousLatLng!, target));
      } else if (animatedRotation.value == 0.0) {
        // Initial rotation
        final bearing = _getBearing(
          LatLng(target.latitude - 0.0001, target.longitude),
          target,
        );
        animatedRotation.value = bearing;
      }
      _previousLatLng = target;
    }
  }

  void _animateRotation(double targetRotation) {
    if (_disposed) return;
    _rotationTimer?.cancel();

    double start = animatedRotation.value;
    double diff = targetRotation - start;

    // Normalize rotation diff to shortest path
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;

    const int steps = 20; // Fast rotation over 500ms
    int currentStep = 0;

    _rotationTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      currentStep++;
      if (currentStep >= steps) {
        animatedRotation.value = targetRotation % 360;
        timer.cancel();
      } else {
        double t = currentStep / steps;
        animatedRotation.value = (start + diff * t) % 360;
      }
    });
  }

  void _animateTo(LatLng smoothedTarget, LatLng rawTarget, Duration duration) {
    if (_disposed) return;
    _interpolationTimer?.cancel();

    final startLat = animatedLat.value;
    final startLng = animatedLng.value;
    final destLat = smoothedTarget.latitude;
    final destLng = smoothedTarget.longitude;

    // Per-step drift delta to avoid stopping after target is reached.
    // Synchronized to 25ms (40fps) refresh.
    final double driftLat =
        (destLat - startLat) / (duration.inMilliseconds / 25);
    final double driftLng =
        (destLng - startLng) / (duration.inMilliseconds / 25);

    // No change? Just ensure markers up to date
    if (startLat == destLat && startLng == destLng) {
      _updateMarkers();
      moveMapToVehicle();
      return;
    }

    final int totalMs = duration.inMilliseconds;
    final int stepMs = 25; // Professional-grade 40fps refresh rate
    final int steps = (totalMs / stepMs).floor();
    int currentStep = 0;

    _interpolationTimer = Timer.periodic(Duration(milliseconds: stepMs), (
      timer,
    ) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      currentStep++;
      if (currentStep >= steps) {
        // Continuous Drift: Keep moving in the same direction until next update arrives
        animatedLat.value += driftLat;
        animatedLng.value += driftLng;
        _updateMarkers();
        moveMapToVehicle();
      } else {
        // Constant Velocity (Zomato-style): use Linear interpolation
        double t = currentStep / steps;
        animatedLat.value = startLat + (destLat - startLat) * t;
        animatedLng.value = startLng + (destLng - startLng) * t;
        _updateMarkers();
        moveMapToVehicle(); // Follow the animated car
      }
    });
  }

  // ÔöÇÔöÇÔöÇ Fetch helpers ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ

  /// Fetches vehicle info + today statistics from the legacy REST API.
  /// Used once at tracking start to populate plate, total km, and daily stats.
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
      if (raw == null || raw is! Map<String, dynamic>) return;

      final model = LiveTrackModel.fromJson(raw);
      if (model.data != null) {
        // Merge vehicle info + statistics into existing (may already have position)
        final current = liveTrackData.value;
        liveTrackData.value = LiveTrackData(
          vehicleInfo: model.data!.vehicleInfo,
          currentPosition:
              current?.currentPosition ?? model.data!.currentPosition,
          currentStatus: current?.currentStatus ?? model.data!.currentStatus,
          todayStatistics: model.data!.todayStatistics,
          currentPositionApi:
              current?.currentPositionApi ?? model.data!.currentPositionApi,
        );
        _onDataUpdated();
      }
    } catch (e, st) {
      if (!_disposed) log('LiveTrack fetch error: $e\n$st');
    } finally {
      if (!_disposed) isLiveLoading.value = false;
    }
  }

  /// Fetches the latest real-time position from the new TCP API.
  /// This matches the data shape sent by the WebSocket device.update events.
  /// URL: GET {tcpBaseUrl}/api/live-tracking/device/{imei}
  Future<void> _fetchTcpPosition(String imei) async {
    if (_disposed || imei.trim().isEmpty) return;
    try {
      final url =
          '${ApiConfig.tcpBaseUrl}/api/live-tracking/device/${imei.trim()}';
      log('Fetching TCP Position from: $url');
      final response = await DioClient().dio.get<Map<String, dynamic>>(url);
      if (_disposed) return;

      final body = response.data;
      if (body == null) return;
      if (body['success'] == true && body['data'] is Map<String, dynamic>) {
        final tcp = body['data'] as Map<String, dynamic>;
        liveTrackData.value = _mergeTcpData(tcp, existing: liveTrackData.value);
        _onDataUpdated();
      }
    } catch (e) {
      if (!_disposed) log('TCP position fetch error: $e');
    }
  }

  /// Called from the Track button if the IMEI changes (re-entering the screen).
  void startTrackingForImei(String imei, {String plate = ''}) {
    if (imei.trim().isEmpty) return;

    // Idempotent check: if already tracking this imei, do nothing
    if (vehicleImei.value == imei &&
        !isLiveLoading.value &&
        (animatedLat.value != 0.0 || liveTrackData.value != null)) {
      // Already tracking and have data, ensure polling/WS is active but don't reset state
      _ensurePolling(imei);
      return;
    }

    vehicleImei.value = imei;
    if (plate.isNotEmpty) vehiclePlate.value = plate;
    liveTrackData.value = null;
    animatedLat.value = 0.0;
    animatedLng.value = 0.0;
    _interpolationTimer?.cancel();
    _pollingTimer?.cancel();
    _stopLiveTracking();
    _startLiveTracking(imei);
  }
}
