import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../../Configs/ApiConfigs.dart';
import '../../../../Models/LiveTrackModel.dart';
import '../../../../Configs/DioClient.dart';
import '../../../../Utils/Utils.dart';
import '../../../../Configs/PusherConfig.dart';
import '../../../../Services/DirectionsService.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class TrackController extends GetxController {
  final vehicleImei = ''.obs;
  final vehiclePlate = ''.obs;

  final liveTrackData = Rxn<LiveTrackData>();
  final isLiveLoading = false.obs;

  final animatedLat = 0.0.obs;
  final animatedLng = 0.0.obs;
  final animatedRotation = 0.0.obs;
  final reactiveMarkers = <Marker>[].obs;

  final MapController mapController = MapController();
  final showBottomSheet = true.obs;

  // 🛰️ Route-Based Strategy (Adapted from Reference)
  final routePoints = <LatLng>[].obs;
  // 🏎️ Vector Velocity Glide Strategy
  double _expectedDurationMs = 5000.0;
  double _latSpeedPerTick = 0.0;
  double _lngSpeedPerTick = 0.0;

  // Polling Control
  String? _lastProcessedDeviceTime;
  bool _isFetchingStatus = false;
  Timer? _pollingTimer;
  bool _disposed = false;

  final DirectionsService _directionsService = DirectionsService();
  PusherChannelsFlutter? _pusher;
  Timer? _animationTimer;

  final animatedDriverLocation = Rxn<LatLng>();
  final destinationLocation = Rxn<LatLng>();
  final mapPolylines = <Polyline>[].obs;

  final fenceNameController = TextEditingController();
  final fenceNameError = RxnString();
  final selectedShareOption = '24h'.obs;

  void updateShareOption(String value) => selectedShareOption.value = value;

  void submitFence() {
    if (fenceNameController.text.isEmpty) {
      fenceNameError.value = "Geofence name is required";
      return;
    }
    debugPrint("Submitting geofence: ${fenceNameController.text}");
    // Fence logic persists
  }

  void _updateTelemetry(LatLng target, double speedKmH) {
    if (animatedLat.value == 0.0 || animatedLng.value == 0.0) {
      animatedLat.value = target.latitude;
      animatedLng.value = target.longitude;
    }

    final now = DateTime.now();

    if (_lastDataTime != null) {
      int intervalMs = now.difference(_lastDataTime!).inMilliseconds;
      _expectedDurationMs = (intervalMs * 1.05)
          .toDouble(); // stretch slightly to maintain momentum
      if (_expectedDurationMs < 2000) _expectedDurationMs = 2000;
      if (_expectedDurationMs > 30000) _expectedDurationMs = 30000;
    } else {
      _expectedDurationMs = 5000;
    }

    // Determine the precise velocity to intercept the exact target over expected duration
    double totalTicks = _expectedDurationMs / 16.0;
    if (totalTicks < 1.0) totalTicks = 1.0;

    _latSpeedPerTick = (target.latitude - animatedLat.value) / totalTicks;
    _lngSpeedPerTick = (target.longitude - animatedLng.value) / totalTicks;

    // Handle idle states
    if (speedKmH < 1.0 && _previousLatLng != null) {
      double dist = _calculateDistance(_previousLatLng!, target);
      if (dist < 2.0) {
        _latSpeedPerTick = 0.0;
        _lngSpeedPerTick = 0.0;
      }
    }

    _lastDataTime = now;
    _previousLatLng = target;
  }

  void _onDataUpdated() {
    final data = liveTrackData.value;
    if (data == null) return;

    final latStr = data.currentPosition?.latitude;
    final lngStr = data.currentPosition?.longitude;
    final speed = data.currentPosition?.speed?.toDouble() ?? 0.0;

    if (latStr != null && lngStr != null) {
      final lat = double.tryParse(latStr) ?? 0.0;
      final lng = double.tryParse(lngStr) ?? 0.0;
      if (lat != 0.0 && lng != 0.0) {
        _updateTelemetry(LatLng(lat, lng), speed);
      }
    }
  }

  bool _isNewerData(LiveTrackData data) {
    final deviceTime = data.currentPosition?.deviceTime;
    if (deviceTime == null) return true;
    if (deviceTime == _lastProcessedDeviceTime) return false;
    _lastProcessedDeviceTime = deviceTime;
    return true;
  }

  void moveMapToVehicle() {
    final lat = animatedLat.value;
    final lng = animatedLng.value;
    if (lat != 0.0 && lng != 0.0) {
      double zoom = 15.0;
      try {
        zoom = mapController.camera.zoom;
      } catch (_) {}
      try {
        mapController.move(LatLng(lat, lng), zoom);
      } catch (_) {}
    }
  }

  void toggleBottomSheet() {
    showBottomSheet.value = !showBottomSheet.value;
  }

  // --- Rx Getters for TrackView ---
  String get displayPlate =>
      liveTrackData.value?.vehicleInfo?.vehicleNumber ?? vehiclePlate.value;
  String get displayImei => vehicleImei.value;
  String get displaySpeed =>
      liveTrackData.value?.currentPosition?.speed?.toStringAsFixed(1) ?? '0.0';
  String get displayStatus =>
      liveTrackData.value?.currentStatus ??
      liveTrackData.value?.currentPosition?.derivedStatus ??
      'Stopped';
  String get displayDeviceTime =>
      liveTrackData.value?.currentPosition?.deviceTime ?? '–';
  String get displayLastUpdate =>
      liveTrackData.value?.currentPositionApi?.data?.lastUpdate ?? '–';

  String get displayLatitude => animatedLat.value != 0.0
      ? animatedLat.value.toStringAsFixed(7)
      : (liveTrackData.value?.currentPosition?.latitude ?? '–');
  String get displayLongitude => animatedLng.value != 0.0
      ? animatedLng.value.toStringAsFixed(7)
      : (liveTrackData.value?.currentPosition?.longitude ?? '–');

  bool get isIgnitionOn =>
      liveTrackData.value?.currentPosition?.isIgnitionOn ?? false;
  bool get isPowerOn =>
      liveTrackData.value?.currentPosition?.isPowerOn ?? false;

  String get displayGsmSignal =>
      liveTrackData.value?.currentPositionApi?.data?.gsmSignalStrength ?? '–';
  String get displayNetwork =>
      liveTrackData.value?.currentPositionApi?.data?.network ?? '–';
  String get displayAltitude =>
      liveTrackData.value?.currentPositionApi?.data?.altitude ?? '–';

  String get displayTodayKm =>
      liveTrackData.value?.todayStatistics?.totalKilometersToday
          ?.toStringAsFixed(2) ??
      '0.00';
  String get displayTotalKm =>
      liveTrackData.value?.vehicleInfo?.totalKilometersTraveled ?? '0.00';
  String get displayStoppedDuration =>
      _formatHours(liveTrackData.value?.todayStatistics?.totalStopHours);
  String get displayIdleDuration =>
      _formatHours(liveTrackData.value?.todayStatistics?.totalIdleHours);
  String get displayRunningDuration => "–";
  String get displayInactiveDuration => "–";

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

    reactiveMarkers.assignAll([
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
    ]);
  }

  RxList<Marker> get mapMarkers => reactiveMarkers;

  @override
  void onInit() {
    super.onInit();
    final imei = Get.parameters['imei'] ?? '';
    final plate = Get.parameters['vehicleId'] ?? '';
    vehicleImei.value = imei;
    vehiclePlate.value = plate;

    if (imei.isNotEmpty) {
      _initAndStartTracking(imei);
      _initializePusher(imei);
    }
    _startSmoothAnimationEngine();
  }

  void _startSmoothAnimationEngine() {
    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_disposed) return;
      _glideMarker();
    });
  }

  void _glideMarker() {
    if (animatedLat.value == 0.0 || animatedLng.value == 0.0) return;

    // Apply continuous, unstoppable velocity directly toward the latest API vector.
    // Completely bypass Mapbox snapping issues!
    animatedLat.value += _latSpeedPerTick;
    animatedLng.value += _lngSpeedPerTick;

    // Smooth tangent bearing
    if (_latSpeedPerTick.abs() > 0.0000001 ||
        _lngSpeedPerTick.abs() > 0.0000001) {
      double targetHeading = _getBearing(
        LatLng(animatedLat.value, animatedLng.value),
        LatLng(
          animatedLat.value + _latSpeedPerTick,
          animatedLng.value + _lngSpeedPerTick,
        ),
      );
      double rDiff = targetHeading - animatedRotation.value;
      if (rDiff > 180) rDiff -= 360;
      if (rDiff < -180) rDiff += 360;
      animatedRotation.value = (animatedRotation.value + (rDiff * 0.15)) % 360;
    }

    _updateMarkers();
    moveMapToVehicle();
  }

  void updateCameraToFitBounds() {
    if (animatedLat.value == 0.0) return;

    // In this project, we primarily focus on the vehicle.
    // If there were other points (Customer, Restaurant), we'd include them in the bounds.
    final LatLng center = LatLng(animatedLat.value, animatedLng.value);
    mapController.move(center, mapController.camera.zoom);
  }

  Future<void> _initializePusher(String imei) async {
    try {
      _pusher = PusherConfig.getInstance();
      await _pusher!.init(
        apiKey: PusherConfig.pusherAppKey,
        cluster: PusherConfig.pusherCluster,
        onEvent: (event) => _handlePusherEvent(event),
      );
      // Subscribe to the tracking channel defined in PusherConfig
      await _pusher!.subscribe(channelName: PusherConfig.getTrackingChannel(0));
      await _pusher!.connect();
      debugPrint(
        '✅ Pusher connected to channel: ${PusherConfig.getTrackingChannel(0)}',
      );
    } catch (e) {
      debugPrint('❌ Pusher Init Error: $e');
    }
  }

  void _handlePusherEvent(PusherEvent event) {
    if (event.eventName == PusherConfig.newLocationUpdated) {
      final data = jsonDecode(event.data);
      final lat = double.tryParse(data['latitude'].toString());
      final lng = double.tryParse(data['longitude'].toString());

      if (lat != null && lng != null) {
        _handleLocationUpdate(LatLng(lat, lng));
      }
    }
  }

  void _handleLocationUpdate(LatLng newLocation) {
    // 1. Validation: Ensure point is not extreme GPS noise
    if (animatedLat.value != 0.0) {
      double dist = _calculateDistance(
        LatLng(animatedLat.value, animatedLng.value),
        newLocation,
      );
      if (dist > 2000) return; // Ignore impossible physical leaps
    }

    // Unify all tracking data into the constant-velocity engine
    double estimatedSpeed =
        liveTrackData.value?.currentPosition?.speed?.toDouble() ?? 10.0;
    _updateTelemetry(newLocation, estimatedSpeed);

    // Maintain visual polyline independently
    if (routePoints.isEmpty) {
      _fetchNewRoute(newLocation);
    } else {
      final snap = getClosestPointOnPolyline(newLocation, routePoints);
      if (snap['distance'] > 50.0) {
        _fetchNewRoute(newLocation);
      }
    }
  }

  Future<void> _fetchNewRoute(LatLng currentPos) async {
    final dest = LatLng(
      currentPos.latitude + 0.001,
      currentPos.longitude + 0.001,
    );

    final points = await _directionsService.getRoute(currentPos, dest);
    if (points.isNotEmpty) {
      routePoints.assignAll(points);
      _updateMapPolylines();
    }
  }

  void _updateMapPolylines() {
    mapPolylines.assignAll([
      Polyline(
        points: routePoints.toList(),
        color: const Color(0xFF009FE3),
        strokeWidth: 4.0,
      ),
    ]);
  }

  Future<void> _initAndStartTracking(String imei) async {
    final token = await getSavedObject('token');
    if (token != null) DioClient().updateToken(token.toString());
    _startLiveTracking(imei);
  }

  void _startLiveTracking(String imei) {
    _fetchLiveTrack(imei);
    _ensurePolling(imei);
  }

  void _ensurePolling(String imei) {
    _pollingTimer?.cancel();
    if (_disposed) return;

    _fetchTcpPosition(imei);

    final speed =
        liveTrackData.value?.currentPosition?.speed?.toDouble() ?? 0.0;
    final interval = (speed > 0) ? 3 : 10;
    _pollingTimer = Timer(
      Duration(seconds: interval),
      () => _ensurePolling(imei),
    );
  }

  @override
  void onClose() {
    _disposed = true;
    _animationTimer?.cancel();
    _pollingTimer?.cancel();
    _pusher?.disconnect();
    _pusher?.unsubscribe(channelName: PusherConfig.getTrackingChannel(0));
    fenceNameController.dispose();
    super.onClose();
  }

  Future<void> _fetchTcpPosition(String imei) async {
    if (_disposed || _isFetchingStatus) return;
    try {
      _isFetchingStatus = true;
      final url =
          '${ApiConfig.tcpBaseUrl}/api/live-tracking/device/${imei.trim()}';
      final response = await DioClient().dio.get<Map<String, dynamic>>(url);

      final body = response.data;
      if (body != null &&
          body['success'] == true &&
          body['data'] is Map<String, dynamic>) {
        final merged = _mergeTcpData(
          body['data'],
          existing: liveTrackData.value,
        );
        if (_isNewerData(merged)) {
          liveTrackData.value = merged;
          _onDataUpdated();
        }
      }
    } catch (_) {
    } finally {
      _isFetchingStatus = false;
    }
  }

  Future<void> _fetchLiveTrack(String imei) async {
    try {
      final url =
          '${ApiConfig.baseUrl}/api/live-tracking/device/${imei.trim()}';
      final response = await DioClient().dio.get<Map<String, dynamic>>(url);
      final body = response.data;
      if (body != null && body['success'] == true) {
        liveTrackData.value = LiveTrackData.fromJson(body['data']);
        _onDataUpdated();
      }
    } catch (_) {}
  }

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
      vehicleInfo: existing?.vehicleInfo,
      currentPosition: pos,
      currentStatus: pos.derivedStatus,
      todayStatistics: existing?.todayStatistics,
      currentPositionApi: posApi,
    );
  }

  // --- Geometry Helpers ---
  LatLng? _previousLatLng;
  DateTime? _lastDataTime;

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
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const double radius = 6371000;
    final dLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final dLon = (p2.longitude - p1.longitude) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1.latitude * math.pi / 180) *
            math.cos(p2.latitude * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radius * (2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)));
  }

  Map<String, dynamic> getClosestPointOnPolyline(
    LatLng current,
    List<LatLng> polyline,
  ) {
    if (polyline.isEmpty)
      return {
        'point': current,
        'distance': double.infinity,
        'idx': -1,
        't': 0.0,
      };
    if (polyline.length == 1)
      return {
        'point': polyline.first,
        'distance': _calculateDistance(current, polyline.first),
        'idx': 0,
        't': 0.0,
      };
    double minD = double.infinity;
    LatLng snapP = polyline.first;
    int cIdx = 0;
    double fT = 0.0;
    for (int i = 0; i < polyline.length - 1; i++) {
      final p1 = polyline[i];
      final p2 = polyline[i + 1];
      final dx = p2.longitude - p1.longitude;
      final dy = p2.latitude - p1.latitude;
      final lenSq = dx * dx + dy * dy;
      if (lenSq < 1e-9) continue;
      final t =
          ((current.longitude - p1.longitude) * dx +
              (current.latitude - p1.latitude) * dy) /
          lenSq;
      final cT = t.clamp(0.0, 1.0);
      final pOnS = LatLng(p1.latitude + cT * dy, p1.longitude + cT * dx);
      final d = _calculateDistance(current, pOnS);
      if (d < minD) {
        minD = d;
        snapP = pOnS;
        cIdx = i;
        fT = cT;
      }
    }
    return {'point': snapP, 'distance': minD, 'idx': cIdx, 't': fT};
  }

  String _formatHours(num? hours) {
    if (hours == null) return '00:00 hrs';
    int h = hours.toInt();
    int m = ((hours - h) * 60).toInt();
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} hrs";
  }

  void startTrackingForImei(String imei, {String? plate}) {
    vehicleImei.value = imei;
    if (plate != null && plate.isNotEmpty) vehiclePlate.value = plate;
    liveTrackData.value = null;
    _lastProcessedDeviceTime = null;
    _startLiveTracking(imei);
  }
}
