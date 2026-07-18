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
import '../../../../Services/LiveTrackWebSocketService.dart';
import '../../../../Services/DirectionsService.dart';
/// Live tracking flow (snapshot once + WebSocket only):
/// 1. User selects vehicle on live track screen (IMEI from route).
/// 2. GET /website/live_track_snapshot?imei= once (Bearer via DioClient).
/// 3. Parse position.lat/lng, websocket.channel/event,
///    websocket_config.websocket_url + app_key.
/// 4. Show map immediately from snapshot position.
/// 5. Connect WebSocket using websocket_config (no Bearer).
/// 6. Subscribe pusher channel (e.g. device.<imei>).
/// 7. Listen for device.update on that channel.
/// 8. On each device.update → update marker (no position API polling).
/// 9. On socket drop → reconnect, resubscribe, optional snapshot catch-up.
/// 10. onClose → disconnect WebSocket.
class TrackController extends GetxController {
  final vehicleImei = ''.obs;
  final vehiclePlate = ''.obs;

  final liveTrackData = Rxn<LiveTrackData>();
  final isLiveLoading = false.obs;

  /// Published to UI (throttled). Glide math uses [_animLat]/[_animLng].
  final animatedLat = 0.0.obs;
  final animatedLng = 0.0.obs;
  final animatedRotation = 0.0.obs;
  final reactiveMarkers = <Marker>[].obs;

  /// High-frequency glide position (does not notify GetX every frame).
  double _animLat = 0.0;
  double _animLng = 0.0;
  DateTime? _lastUiSync;
  LatLng? _lastUiSyncPoint;

  final MapController mapController = MapController();
  final showBottomSheet = true.obs;
  final isLocked = true.obs;

  static const double _followZoom = 16.0;
  bool _userAdjustedZoom = false;
  bool _hasInitialCameraFocus = false;
  double _smoothCameraLat = 0.0;
  double _smoothCameraLng = 0.0;

  bool _isFetchingSnapshot = false;
  bool _disposed = false;

  final LiveTrackWebSocketService _webSocketService = LiveTrackWebSocketService();
  LiveWebsocketConfig? _wsConfig;
  LiveWebsocketInfo? _wsInfo;

  Timer? _animationTimer;
  LatLng? _liveTarget;
  LatLng? _lastAcceptedGps;

  static const double _maxBackwardBearingDeg = 95.0;
  static const double _snapBackMinLagMeters = 4.0;
  static const double _reverseGpsStepMeters = 4.0;
  static const double _maxGlideSpeedMs = 45.0;
  static const double _catchUpMinLagMeters = 6.0;
  static const double _catchUpWindowSec = 3.5;
  static const double _reconnectSnapMeters = 150.0;

  double _expectedPingSec = 6.0;
  double _roadSpeedFactor = 1.0;
  double _targetRoadSpeedFactor = 1.0;
  double _smoothedGlideSpeedMs = 0.0;
  int _routeRequestId = 0;

  /// Road-snapped waypoints the marker walks along (Map Matching).
  final List<LatLng> _roadQueue = [];
  /// Recent raw GPS samples used for Map Matching (keeps path on the road).
  final List<LatLng> _gpsTrace = [];

  final DirectionsService _directionsService = DirectionsService();

  double _currentSpeedMs = 0.0;
  double _smoothedSpeedMs = 0.0;
  DateTime? _lastMovingTime;
  String _movementMode = '';
  double _lockedBearing = 0.0;
  bool _hasHeading = false;
  DateTime? _lastGlideTime;
  DateTime? _lastGpsTime;
  DateTime? _lastCameraMove;
  static const int _cameraMoveIntervalMs = 100;
  /// Cap map/GetX marker rebuilds (~20 fps while moving).
  static const int _uiSyncMinMs = 50;
  static const double _uiSyncMinMeters = 0.15;
  /// Ignore GPS noise while stopped — prevents marker vibration.
  static const double _stoppedGpsDeadbandM = 8.0;
  /// Slow forward roll while device reports speed 0 (~1.3 km/h).
  static const double _stoppedCreepMs = 0.35;
  /// Max distance past last GPS while stopped (avoids endless park drift).
  static const double _stoppedCreepMaxLeadM = 20.0;
  static const double _minRotationChangeDeg = 12.0;
  static const double _minGpsBearingMoveM = 8.0;
  /// GPS must be within this of travel heading to chase it (else go straight).
  static const double _onCourseMaxDeg = 28.0;
  static const double _frameSeconds = 0.033;
  /// Minimum roll speed between WS pings (~1.8 km/h).
  static const double _wsWaitCreepMinMs = 0.5;
  /// Skip Mapbox for tiny hops; stay on last matched road instead of raw GPS.
  static const double _minRoadRouteMeters = 4.0;
  /// Max turn rate while following a road polyline (~deg per frame @30fps).
  static const double _maxRotationStepDeg = 5.0;
  static const int _gpsTraceMaxPoints = 6;

  /// Device-reported speed (km/h) from latest WS ping. Stop only when 0.
  double _lastReportedSpeedKmh = 0.0;
  /// GPS-inferred speed (km/h) — keeps roll rate realistic between pings.
  double _lastInferredSpeedKmh = 0.0;
  /// GPS movement on latest ping (m).
  double _lastGpsDeltaM = 0.0;
  /// Latched on each ping — keeps rolling between WS updates until next ping.
  bool _isMovingVehicle = false;

  final fenceNameController = TextEditingController();
  final fenceNameError = RxnString();
  final selectedShareOption = '24h'.obs;
  final isUpdatingOdometer = false.obs;
  /// Light odometer source for UI (avoids rewriting all liveTrackData on update).
  final odometerKm = Rxn<num>();
  /// Pause marker UI sync while an input sheet is open (prevents ANR with IME).
  bool _pauseMarkerUi = false;

  void updateShareOption(String value) => selectedShareOption.value = value;

  void submitFence() {
    if (fenceNameController.text.isEmpty) {
      fenceNameError.value = "Geofence name is required";
      return;
    }
    debugPrint("Submitting geofence: ${fenceNameController.text}");
  }

  @override
  void onInit() {
    super.onInit();
    _disposed = false;
    final imei = Get.parameters['imei'] ?? '';
    final plate = Get.parameters['vehicleId'] ?? '';
    vehicleImei.value = imei;
    vehiclePlate.value = plate;

    if (imei.isNotEmpty) {
      _initAndStartTracking(imei);
    }
    _startAnimationLoop();
  }

  Future<void> _initAndStartTracking(String imei) async {
    final token = await getSavedObject('token');
    if (token != null) DioClient().updateToken(token.toString());
    if (_disposed) return;
    await _fetchLiveTrackSnapshot(imei);
  }

  /// Snapshot once on entry; reconnectOnly skips WebSocket re-setup.
  Future<void> _fetchLiveTrackSnapshot(
    String imei, {
    bool reconnectOnly = false,
  }) async {
    if (_disposed) return;
    if (_isFetchingSnapshot && !reconnectOnly) return;

    try {
      _isFetchingSnapshot = true;
      if (!reconnectOnly) isLiveLoading.value = true;

      final response = await DioClient().get(
        ApiEndPoints.liveTrackSnapshot,
        query: {'imei': imei.trim()},
      );

      final rawBody = response.data;
      if (rawBody is! Map) {
        debugPrint('❌ LiveTrack: invalid snapshot response');
      return;
    }
      final body = Map<String, dynamic>.from(rawBody);

      final snapshot = LiveTrackSnapshotModel.fromJson(body);
      final data = snapshot.data;
      if (data == null) {
        debugPrint('❌ LiveTrack: snapshot missing data');
        return;
      }

      _wsConfig = data.websocketConfig;
      _wsInfo = data.websocket;

      liveTrackData.value = data.toLiveTrackData();
      _syncOdometerKm(liveTrackData.value?.currentPosition?.odometer);
      if (reconnectOnly) {
        final pos = liveTrackData.value?.currentPosition;
        final lat = double.tryParse(pos?.latitude ?? '');
        final lng = double.tryParse(pos?.longitude ?? '');
        if (lat != null && lng != null && _animLat != 0.0) {
          final snap = LatLng(lat, lng);
          final current = LatLng(_animLat, _animLng);
          final lag = _calculateDistance(current, snap);
          if (lag > _reconnectSnapMeters && _isForwardOf(snap, current)) {
            _snapMarkerTo(
              snap,
              pos?.speed?.toDouble() ?? 0.0,
              status: pos?.derivedStatus,
              mode: pos?.mode,
            );
          } else if (lag > 1.0) {
            _onDevicePosition(
              snap,
              pos?.speed?.toDouble() ?? 0.0,
              status: pos?.derivedStatus,
              mode: pos?.mode,
            );
          }
        }
      } else {
        _applyPositionFromData(isInitial: true);
      }

      if (!reconnectOnly) {
        await _webSocketService.disconnect();
        await _connectWebSocket(imei);
      }
    } catch (e) {
      debugPrint('❌ Live track snapshot error: $e');
    } finally {
      _isFetchingSnapshot = false;
      if (!reconnectOnly) isLiveLoading.value = false;
    }
  }

  void _applyPositionFromData({required bool isInitial}) {
    final pos = liveTrackData.value?.currentPosition;
    final lat = double.tryParse(pos?.latitude ?? '');
    final lng = double.tryParse(pos?.longitude ?? '');
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) return;

    final location = LatLng(lat, lng);
    final speed = pos?.speed?.toDouble() ?? 0.0;

    if (isInitial || _animLat == 0.0 || _animLng == 0.0) {
      _setAnimPosition(lat, lng, publish: true);
      _liveTarget = location;
      _lastAcceptedGps = location;
      _lastGpsTime = DateTime.now();
      _lastReportedSpeedKmh = speed;
      _lastInferredSpeedKmh = speed;
      _lastGpsDeltaM = 0;
      _isMovingVehicle = speed > 0;
      _gpsTrace
        ..clear()
        ..add(location);
      _smoothedGlideSpeedMs = speed > 0
          ? (speed / 3.6).clamp(_wsWaitCreepMinMs, _maxGlideSpeedMs)
          : 0.0;
      _updateMovementSpeed(speed, pos?.derivedStatus ?? 'Stopped', mode: pos?.mode);
      if (!_hasInitialCameraFocus && isLocked.value) {
        _hasInitialCameraFocus = true;
        moveMapToVehicle(snap: true, resetZoom: true);
      }
      return;
    }

    _onDevicePosition(location, speed, status: pos?.derivedStatus, mode: pos?.mode);
  }

  /// Step 4–5: connect using API websocket_config only (Option A).
  Future<void> _connectWebSocket(String imei) async {
    if (_wsConfig == null) {
      debugPrint('❌ LiveTrack: websocket_config missing from API');
      return;
    }

    final snapshot = LiveTrackSnapshotData(
      websocket: _wsInfo,
      websocketConfig: _wsConfig,
    );

    if (!snapshot.hasWebSocketConnectionConfig) {
      debugPrint('❌ LiveTrack: websocket_config.websocket_url or app_key missing');
      return;
    }
    if (snapshot.channelFor(imei) == null) {
      debugPrint(
        '❌ LiveTrack: channel missing (websocket.channel or channel_prefix)',
      );
      return;
    }
    if (snapshot.eventNameFor() == null) {
      debugPrint(
        '❌ LiveTrack: event missing (websocket.event or event_name)',
      );
      return;
    }

    final connected = await _webSocketService.connect(
      imei: imei,
      websocketConfig: _wsConfig,
      websocket: _wsInfo,
      onDeviceUpdate: _handleDeviceUpdate,
      onReconnected: () {
        if (_disposed || vehicleImei.value.isEmpty) return;
        debugPrint('[LiveTrack] WS reconnected — refreshing snapshot');
        _fetchLiveTrackSnapshot(vehicleImei.value, reconnectOnly: true);
      },
    );

    if (!connected) {
      debugPrint('❌ LiveTrack: WebSocket connection setup failed');
    }
  }

  void _handleDeviceUpdate(Map<String, dynamic> data) {
    if (_disposed) return;

    try {
      final coords = _readLatLngFromMap(data);
      if (coords == null) {
        debugPrint('⚠️ LiveTrack: device.update missing lat/lng: $data');
        return;
      }

      final lat = coords.$1;
      final lng = coords.$2;
      final speed = _readSpeedFromMap(data)?.toDouble() ?? 0.0;
      final course = _readCourseFromMap(data);

      final existing = liveTrackData.value;
      final pos = LiveCurrentPosition(
        imei: data['imei']?.toString() ?? vehicleImei.value,
        latitude: lat.toString(),
        longitude: lng.toString(),
        speed: speed,
        deviceTime:
            data['devicetime']?.toString() ?? data['device_time']?.toString(),
        ignition: data['ignition'] is int
            ? data['ignition'] as int
            : int.tryParse(data['ignition']?.toString() ?? ''),
        power: data['power'] is int
            ? data['power'] as int
            : int.tryParse(data['power']?.toString() ?? ''),
        mode: data['mode']?.toString(),
        kilometer: data['kilometer']?.toString() ??
            existing?.currentPosition?.kilometer,
        odometer: data['odometer'] is num
            ? data['odometer'] as num
            : num.tryParse(data['odometer']?.toString() ?? '') ??
                existing?.currentPosition?.odometer,
        altitude: data['altitude']?.toString() ??
            existing?.currentPosition?.altitude,
        gsmSignalStrength: data['gsm_signal_strength']?.toString() ??
            existing?.currentPosition?.gsmSignalStrength ??
            existing?.currentPositionApi?.data?.gsmSignalStrength,
        network: data['network']?.toString() ??
            existing?.currentPosition?.network ??
            existing?.currentPositionApi?.data?.network,
        lastUpdate: data['last_update']?.toString() ??
            existing?.currentPosition?.lastUpdate ??
            existing?.currentPositionApi?.data?.lastUpdate,
      );

      liveTrackData.value = LiveTrackData(
        vehicleInfo: existing?.vehicleInfo,
        currentPosition: pos,
        currentStatus: pos.derivedStatus,
        todayStatistics: existing?.todayStatistics,
        currentPositionApi: existing?.currentPositionApi,
      );
      _syncOdometerKm(pos.odometer);

      _onDevicePosition(
        LatLng(lat, lng),
        speed,
        status: pos.derivedStatus,
        courseDeg: course,
        mode: pos.mode,
      );
    } catch (e, st) {
      debugPrint('⚠️ LiveTrack device update error: $e\n$st');
    }
  }

  void _onDevicePosition(
    LatLng location,
    double speedKmH, {
    String? status,
    double? courseDeg,
    String? mode,
  }) {
    final now = DateTime.now();
    final previousGps = _lastAcceptedGps;
    final previousGpsTime = _lastGpsTime;

    final reportedKmH = speedKmH;
    speedKmH = _inferSpeedKmh(location, speedKmH, now);
    _lastReportedSpeedKmh = reportedKmH;
    _lastInferredSpeedKmh = speedKmH;
    if (mode != null) _movementMode = mode;

    var gpsDeltaM = 0.0;
    if (previousGps != null) {
      gpsDeltaM = _calculateDistance(previousGps, location);
    }
    _lastGpsDeltaM = gpsDeltaM;

    // Device-reported speed gates "live tracking" vs "stopped crawl".
    // GPS jitter alone must not flip into full chase (that caused vibration).
    if (reportedKmH <= 0) {
      _isMovingVehicle = false;
    } else {
      _isMovingVehicle = true;
    }

    _updateMovementSpeed(
      _isMovingVehicle ? math.max(speedKmH, reportedKmH) : 0,
      status ?? 'Stopped',
      mode: mode,
    );

    if (!_isMovingVehicle) {
      // Keep a gentle crawl rate; ignore tiny GPS noise so the marker
      // doesn't vibrate by chasing the target back and forth.
      _smoothedGlideSpeedMs = _stoppedCreepMs;
      _roadQueue.clear();
      _gpsTrace.clear();
      if (previousGps != null && gpsDeltaM < _stoppedGpsDeadbandM) {
        _lastGpsTime = now;
        return;
      }
      // Meaningful update while speed is 0 — accept new track point and
      // slowly follow it (next frames use soft-follow in the glide loop).
      if (previousGpsTime != null) {
        final interval =
            now.difference(previousGpsTime).inMilliseconds / 1000.0;
        if (interval >= 0.8 && interval < 60.0) {
          _expectedPingSec = _expectedPingSec * 0.65 + interval * 0.35;
        }
      }
      // Do not invent heading from park jitter — that causes a bend on pull-away.
      // Only seed heading from device course if we still have none.
      if (!_hasHeading &&
          courseDeg != null &&
          courseDeg >= 0 &&
          courseDeg <= 360) {
        _setLockedBearing(courseDeg % 360);
      }
      _lastAcceptedGps = location;
      _lastGpsTime = now;
      _liveTarget = location;
      return;
    }

    if (previousGps != null) {
      if (previousGpsTime != null) {
        final interval =
            now.difference(previousGpsTime).inMilliseconds / 1000.0;
        if (interval >= 0.8 && interval < 60.0) {
          _expectedPingSec = _expectedPingSec * 0.65 + interval * 0.35;
        }
      }
      // Stale/lag GPS behind the animated marker — not a real reverse.
      if (_isLikelySnapBack(location, previousGps)) {
        _lastGpsTime = now;
        return;
      }
    }

    // Prefer GPS movement direction over device course — course can be stale
    // or offset and would make the car face/dead-reckon the wrong way.
    _updateHeadingFromMovement(
      location,
      previousGps: previousGps,
      courseDeg: courseDeg,
    );

    _lastAcceptedGps = location;
    _lastGpsTime = now;
    _liveTarget = location;
    _smoothedGlideSpeedMs = math.max(
      _smoothedGlideSpeedMs,
      _wsWaitCreepMinMs,
    );

    // Glide along the road between pings (keeps marker on the map roads).
    _requestRoadPath(location);
  }

  void _snapMarkerTo(
    LatLng location,
    double speedKmH, {
    String? status,
    String? mode,
  }) {
    _setAnimPosition(location.latitude, location.longitude, publish: true);
    _liveTarget = location;
    _lastAcceptedGps = location;
    _lastGpsTime = DateTime.now();
    _lastReportedSpeedKmh = speedKmH;
    _lastInferredSpeedKmh = speedKmH;
    _isMovingVehicle = speedKmH > 0;
    _roadQueue.clear();
    _gpsTrace.clear();
    _updateMovementSpeed(speedKmH, status ?? 'Stopped', mode: mode);
    if (isLocked.value) _maybeMoveCameraToVehicle();
  }

  void _setAnimPosition(double lat, double lng, {bool publish = false}) {
    _animLat = lat;
    _animLng = lng;
    if (publish) _publishAnim(force: true);
  }

  /// Push glide position to GetX / map marker at a capped rate.
  void _publishAnim({bool force = false}) {
    if (_animLat == 0.0 && _animLng == 0.0) return;
    if (_pauseMarkerUi && !force) return;

    final point = LatLng(_animLat, _animLng);
    final now = DateTime.now();
    if (!force && _lastUiSyncPoint != null && _lastUiSync != null) {
      final dtMs = now.difference(_lastUiSync!).inMilliseconds;
      final moved = _calculateDistance(_lastUiSyncPoint!, point);
      if (dtMs < _uiSyncMinMs && moved < 1.5) return;
      if (moved < _uiSyncMinMeters && dtMs < 250) return;
    }

    _lastUiSync = now;
    _lastUiSyncPoint = point;
    animatedLat.value = _animLat;
    animatedLng.value = _animLng;
    _syncMarkerPosition();
  }

  void setInputSheetOpen(bool open) {
    _pauseMarkerUi = open;
    if (open) {
      // Fully stop glide while IME/sheet is open — timer+rebuild was ANRing.
      _animationTimer?.cancel();
      _animationTimer = null;
      return;
    }
    if (!_disposed) {
      _startAnimationLoop();
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (!_disposed && !_pauseMarkerUi) {
          _publishAnim(force: true);
        }
      });
    }
  }

  void applyOdometerLocal(num value) {
    odometerKm.value = value;
  }

  void clearOdometerUpdating() {
    if (isUpdatingOdometer.value) {
      isUpdatingOdometer.value = false;
    }
  }

  void _syncOdometerKm(num? value) {
    if (value == null) return;
    if (odometerKm.value == value) return;
    odometerKm.value = value;
  }

  /// Snap latest GPS onto the road (Map Matching) and walk that geometry only.
  void _requestRoadPath(LatLng to) {
    _pushGpsTrace(to);

    if (_animLat == 0.0 && _animLng == 0.0) return;

    final from = LatLng(_animLat, _animLng);
    final straightM = _calculateDistance(from, to);
    // Tiny hops: do not chase raw GPS off-road — keep current road queue.
    if (straightM < _minRoadRouteMeters) {
      _targetRoadSpeedFactor = 1.0;
      return;
    }

    final requestId = ++_routeRequestId;

    // Trace = recent GPS (+ current marker) so Matching snaps the real path.
    final trace = <LatLng>[];
    if (_gpsTrace.length >= 2) {
      trace.addAll(_gpsTrace);
    } else {
      trace.add(from);
      trace.add(to);
    }
    // Prefer starting match near the marker so the path begins on-road.
    if (_calculateDistance(trace.first, from) > 8.0) {
      trace.insert(0, from);
    }

    _directionsService.matchTrace(trace, radiusMeters: 30).then((matched) {
      if (_disposed || requestId != _routeRequestId) return;

      if (matched.length < 2) {
        // Stay on whatever road path we already have — never queue raw GPS.
        return;
      }

      var routeLenM = 0.0;
      for (var i = 1; i < matched.length; i++) {
        routeLenM += _calculateDistance(matched[i - 1], matched[i]);
      }
      if (straightM > 1.0) {
        _targetRoadSpeedFactor = (routeLenM / straightM).clamp(1.0, 1.45);
      }

      // Pull marker onto the road if we're sitting beside it.
      final onRoadStart = _closestPointOnPolyline(from, matched);
      final lateral = _calculateDistance(from, onRoadStart);
      if (lateral > 2.0 && lateral < 40.0) {
        _animLat = onRoadStart.latitude;
        _animLng = onRoadStart.longitude;
      }

      final remaining = _trimRouteAhead(
        LatLng(_animLat, _animLng),
        matched,
      );
      if (remaining.isEmpty) return;

      // Only road-matched points — never append raw GPS (that causes overflow).
      _roadQueue
        ..clear()
        ..addAll(remaining);
    }).catchError((e) {
      debugPrint('[LiveTrack] matchTrace failed: $e');
    });
  }

  void _pushGpsTrace(LatLng point) {
    if (_gpsTrace.isNotEmpty &&
        _calculateDistance(_gpsTrace.last, point) < 1.5) {
      _gpsTrace[_gpsTrace.length - 1] = point;
      return;
    }
    _gpsTrace.add(point);
    while (_gpsTrace.length > _gpsTraceMaxPoints) {
      _gpsTrace.removeAt(0);
    }
  }

  /// Closest vertex (or interpolated segment point) on [poly] to [p].
  LatLng _closestPointOnPolyline(LatLng p, List<LatLng> poly) {
    if (poly.isEmpty) return p;
    if (poly.length == 1) return poly.first;

    var best = poly.first;
    var bestDist = _calculateDistance(p, best);

    for (var i = 0; i < poly.length - 1; i++) {
      final a = poly[i];
      final b = poly[i + 1];
      final projected = _projectOnSegment(p, a, b);
      final d = _calculateDistance(p, projected);
      if (d < bestDist) {
        bestDist = d;
        best = projected;
      }
    }
    return best;
  }

  LatLng _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    final ax = a.longitude;
    final ay = a.latitude;
    final bx = b.longitude;
    final by = b.latitude;
    final px = p.longitude;
    final py = p.latitude;
    final dx = bx - ax;
    final dy = by - ay;
    if (dx == 0 && dy == 0) return a;
    final t = (((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy))
        .clamp(0.0, 1.0);
    return LatLng(ay + dy * t, ax + dx * t);
  }

  /// Keep only the portion of [route] still ahead of [from].
  List<LatLng> _trimRouteAhead(LatLng from, List<LatLng> route) {
    if (route.isEmpty) return route;

    var closestIdx = 0;
    var closestDist = double.infinity;
    for (var i = 0; i < route.length; i++) {
      final d = _calculateDistance(from, route[i]);
      if (d < closestDist) {
        closestDist = d;
        closestIdx = i;
      }
    }

    var start = closestIdx;
    if (closestDist < 3.0 && closestIdx + 1 < route.length) {
      start = closestIdx + 1;
    }

    final out = <LatLng>[];
    for (var i = start; i < route.length; i++) {
      if (out.isEmpty || _calculateDistance(out.last, route[i]) >= 0.8) {
        out.add(route[i]);
      }
    }
    return out;
  }

  bool _shouldKeepMoving() => _isMovingVehicle;

  double _distanceToLiveGps(LatLng current) {
    if (_liveTarget == null) return double.infinity;
    return _calculateDistance(current, _liveTarget!);
  }

  /// Remaining meters along the road queue (falls back to straight GPS distance).
  double _remainingPathMeters(LatLng current) {
    if (_roadQueue.isEmpty) return _distanceToLiveGps(current);

    var total = _calculateDistance(current, _roadQueue.first);
    for (var i = 1; i < _roadQueue.length; i++) {
      total += _calculateDistance(_roadQueue[i - 1], _roadQueue[i]);
    }
    return total;
  }

  double _resolveTravelBearing(LatLng current) {
    if (_roadQueue.isNotEmpty) {
      return _getBearing(current, _roadQueue.first);
    }
    if (_hasHeading) return _lockedBearing;
    if (_liveTarget != null) {
      final bearing = _getBearing(current, _liveTarget!);
      _lockedBearing = bearing;
      _hasHeading = true;
      return bearing;
    }
    return _lockedBearing;
  }

  /// Single continuous speed — catch-up when behind, roll when at GPS dot.
  double _continuousSpeedMs(double distAlongPath) {
    if (!_isMovingVehicle) return 0;

    var ms = _effectiveSpeedMs();
    if (ms < _wsWaitCreepMinMs) {
      ms = math.max(
        math.max(_lastReportedSpeedKmh, _lastInferredSpeedKmh),
        3.0,
      ) / 3.6;
    }

    if (distAlongPath > 0.3) {
      ms = math.max(ms, distAlongPath / math.max(_expectedPingSec, 0.8));
    }

    if (distAlongPath >= _catchUpMinLagMeters) {
      ms = math.max(ms, distAlongPath / _catchUpWindowSec);
    }

    return (ms * _roadSpeedFactor).clamp(_wsWaitCreepMinMs, _maxGlideSpeedMs);
  }

  /// Walk along matched road polyline only — never chase raw GPS off-road.
  void _advanceMarkerContinuously({
    required LatLng current,
    required LatLng gpsTarget,
    required double bearing,
    required double step,
    required double distToGps,
  }) {
    if (step <= 0) return;

    if (_roadQueue.isNotEmpty) {
      _advanceAlongRoad(current, step);
      return;
    }

    // No matched road yet — stay put instead of drifting off-road toward GPS.
  }

  void _advanceAlongRoad(LatLng current, double step) {
    var remaining = step;
    var pos = current;

    while (remaining > 0.01 && _roadQueue.isNotEmpty) {
      final next = _roadQueue.first;
      final dist = _calculateDistance(pos, next);
      if (dist < 0.05) {
        _roadQueue.removeAt(0);
        continue;
      }

      final segmentBearing = _getBearing(pos, next);
      _easeRotationToward(segmentBearing);

      if (dist <= remaining) {
        pos = next;
        remaining -= dist;
        _roadQueue.removeAt(0);
      } else {
        final fraction = remaining / dist;
        pos = LatLng(
          pos.latitude + (next.latitude - pos.latitude) * fraction,
          pos.longitude + (next.longitude - pos.longitude) * fraction,
        );
        remaining = 0;
      }
    }

    _animLat = pos.latitude;
    _animLng = pos.longitude;
  }

  void _easeRotationToward(double bearing) {
    bearing = _normalizeBearing(bearing);
    if (!_hasHeading) {
      _lockedBearing = bearing;
      animatedRotation.value = bearing;
      _hasHeading = true;
      return;
    }

    final delta = _shortestBearingDelta(_lockedBearing, bearing);
    if (delta.abs() < 0.5) return;

    final step = delta.clamp(-_maxRotationStepDeg, _maxRotationStepDeg);
    _lockedBearing = _normalizeBearing(_lockedBearing + step);
    animatedRotation.value = _lockedBearing;
  }

  LatLng _offsetMeters(LatLng from, double bearingDeg, double meters) {
    const metersPerLat = 111320.0;
    final latRad = from.latitude * math.pi / 180;
    final metersPerLng = 111320.0 * math.cos(latRad);
    final rad = bearingDeg * math.pi / 180;
    return LatLng(
      from.latitude + (meters * math.cos(rad)) / metersPerLat,
      from.longitude + (meters * math.sin(rad)) / metersPerLng,
    );
  }

  void _updateHeadingFromMovement(
    LatLng location, {
    LatLng? previousGps,
    double? courseDeg,
  }) {
    double? movementBearing;
    double movedM = 0.0;
    if (previousGps != null) {
      movedM = _calculateDistance(previousGps, location);
      if (movedM >= _minGpsBearingMoveM) {
        movementBearing = _getBearing(previousGps, location);
      }
    }
    if (movementBearing == null && _animLat != 0.0) {
      final current = LatLng(_animLat, _animLng);
      movedM = _calculateDistance(current, location);
      // Prefer GPS→GPS over marker→GPS so park-creep lead doesn't invent a bend.
      if (movedM >= _minGpsBearingMoveM * 1.5) {
        movementBearing = _getBearing(current, location);
      }
    }

    if (movementBearing != null) {
      // Ignore wild heading flips from a single noisy ping unless the step is large.
      if (_hasHeading) {
        final flip =
            _shortestBearingDelta(_lockedBearing, movementBearing).abs();
        if (flip > 55.0 && movedM < 25.0) {
          return;
        }
      }
      _setLockedBearing(movementBearing);
      return;
    }

    // On first move, prefer device course over waiting for a noisy GPS delta.
    if (!_hasHeading &&
        courseDeg != null &&
        courseDeg >= 0 &&
        courseDeg <= 360) {
      _setLockedBearing(courseDeg % 360);
    }
  }

  void _setLockedBearing(double bearing) {
    bearing = _normalizeBearing(bearing);
    if (!_hasHeading) {
      _lockedBearing = bearing;
      animatedRotation.value = bearing;
      _hasHeading = true;
      return;
    }

    final diff = _shortestBearingDelta(_lockedBearing, bearing).abs();
    // Small GPS zigzags must not rotate the car / dead-reckon path.
    if (diff >= _minRotationChangeDeg) {
      // Ease large turns instead of snapping (reduces bend on start/turn).
      final eased = diff > 50.0
          ? _normalizeBearing(
              _lockedBearing + _shortestBearingDelta(_lockedBearing, bearing) * 0.45,
            )
          : bearing;
      _lockedBearing = eased;
      animatedRotation.value = eased;
    }
  }

  /// True when [point] is generally ahead of [origin] along travel heading.
  bool _isForwardOf(LatLng point, LatLng origin) {
    if (!_hasHeading) return true;
    final bearing = _getBearing(origin, point);
    final diff = _shortestBearingDelta(_lockedBearing, bearing);
    return diff.abs() <= _maxBackwardBearingDeg;
  }

  bool _isBehind(LatLng current, LatLng point) {
    if (!_hasHeading) return false;
    final bearing = _getBearing(current, point);
    final diff = _shortestBearingDelta(_lockedBearing, bearing);
    return diff.abs() > _maxBackwardBearingDeg;
  }

  /// Stale GPS that would pull the marker backward after we've already glided ahead.
  /// Does not block genuine reverse — only lag/jitter behind the animated position.
  bool _isLikelySnapBack(LatLng location, LatLng previousGps) {
    if (!_hasHeading || _animLat == 0.0) return false;

    final animated = LatLng(_animLat, _animLng);
    if (!_isBehind(animated, location)) return false;

    final lagM = _calculateDistance(animated, location);
    if (lagM < _snapBackMinLagMeters) return false;

    final gpsStepM = _calculateDistance(previousGps, location);
    if (gpsStepM < 1.0) return true;

    final gpsMovingBackward =
        !_isForwardOf(location, previousGps) && gpsStepM >= _reverseGpsStepMeters;
    return !gpsMovingBackward;
  }

  double _shortestBearingDelta(double from, double to) {
    return ((to - from + 540) % 360) - 180;
  }

  double _inferSpeedKmh(LatLng location, double reportedKmh, DateTime now) {
    if (_lastAcceptedGps == null || _lastGpsTime == null) return reportedKmh;

    final deltaM = _calculateDistance(_lastAcceptedGps!, location);
    if (deltaM < 1.0) return reportedKmh;

    final seconds = now.difference(_lastGpsTime!).inMilliseconds / 1000.0;
    if (seconds <= 0) return reportedKmh;

    final inferred = (deltaM / seconds) * 3.6;
    return math.max(reportedKmh, inferred);
  }

  double _effectiveSpeedMs() {
    if (_currentSpeedMs >= 0.3) return _currentSpeedMs;
    if (_smoothedSpeedMs < 0.3 || _lastMovingTime == null) return _currentSpeedMs;

    final since =
        DateTime.now().difference(_lastMovingTime!).inMilliseconds / 1000.0;
    if (since > 25.0) return _currentSpeedMs;

    final decay = (1.0 - since / 15.0).clamp(0.0, 1.0);
    return math.max(_currentSpeedMs, _smoothedSpeedMs * decay);
  }

  void _nudgeToward(LatLng target, double meters) {
    final lat = _animLat;
    final lng = _animLng;
    if (lat == 0.0 && lng == 0.0) return;

    final dist = _calculateDistance(LatLng(lat, lng), target);
    if (dist < 0.01) return;

    final step = math.min(meters, dist);
    final fraction = step / dist;
    _animLat = lat + (target.latitude - lat) * fraction;
    _animLng = lng + (target.longitude - lng) * fraction;
  }

  void _glideTowardTarget() {
    if (_animLat == 0.0 && _animLng == 0.0) return;

    final now = DateTime.now();
    final dtSec = _lastGlideTime == null
        ? _frameSeconds
        : now.difference(_lastGlideTime!).inMicroseconds / 1000000.0;
    _lastGlideTime = now;
    final dt = dtSec.clamp(0.016, 0.08);

    _roadSpeedFactor +=
        (_targetRoadSpeedFactor - _roadSpeedFactor) * 0.08;

    final current = LatLng(_animLat, _animLng);

    if (_liveTarget == null) return;

    // Device stopped: slow forward crawl, and soft-follow if a new GPS update arrived.
    if (!_shouldKeepMoving()) {
      _advanceWhileStopped(current, dt);
      return;
    }

    final pathMeters = _remainingPathMeters(current);
    final distToGps = _distanceToLiveGps(current);
    final bearing = _resolveTravelBearing(current);
    final targetSpeed = _continuousSpeedMs(pathMeters);

    // Stronger smoothing → less jerky speed changes between pings.
    _smoothedGlideSpeedMs += (targetSpeed - _smoothedGlideSpeedMs) * 0.12;
    _smoothedGlideSpeedMs =
        math.max(_smoothedGlideSpeedMs, _wsWaitCreepMinMs);

    final step = math.max(
      _smoothedGlideSpeedMs * dt,
      _wsWaitCreepMinMs * dt * 0.5,
    );

    _advanceMarkerContinuously(
      current: current,
      gpsTarget: _liveTarget!,
      bearing: bearing,
      step: step,
      distToGps: distToGps,
    );

    _publishAnim();
    if (isLocked.value) _maybeMoveCameraToVehicle();
  }

  /// While speed is 0: slowly roll forward; if GPS was updated, ease toward it.
  void _advanceWhileStopped(LatLng current, double dt) {
    _smoothedGlideSpeedMs = _stoppedCreepMs;
    _roadQueue.clear();
    final distToGps = _distanceToLiveGps(current);

    // New track point while stopped — ease along heading when possible so we
    // don't slide sideways into noisy GPS (that bend shows up on pull-away).
    if (distToGps > 1.5) {
      final step = math.min(_stoppedCreepMs * 1.5 * dt, distToGps);
      if (_hasHeading && _isForwardOf(_liveTarget!, current)) {
        final toGps = _getBearing(current, _liveTarget!);
        final err = _shortestBearingDelta(_lockedBearing, toGps).abs();
        if (err <= _onCourseMaxDeg) {
          _nudgeToward(_liveTarget!, step);
        } else {
          final next = _offsetMeters(current, _lockedBearing, step);
          _animLat = next.latitude;
          _animLng = next.longitude;
        }
      } else {
        _nudgeToward(_liveTarget!, step);
      }
      _publishAnim();
      if (isLocked.value) _maybeMoveCameraToVehicle();
      return;
    }

    // Near last GPS: keep a gentle forward roll so it doesn't look frozen,
    // but don't drift endlessly past the last accepted point.
    if (!_hasHeading) return;
    final lead = _lastAcceptedGps == null
        ? 0.0
        : _calculateDistance(current, _lastAcceptedGps!);
    if (lead >= _stoppedCreepMaxLeadM) return;

    final next = _offsetMeters(current, _lockedBearing, _stoppedCreepMs * dt);
    _animLat = next.latitude;
    _animLng = next.longitude;
    _publishAnim();
    if (isLocked.value) _maybeMoveCameraToVehicle();
  }

  void _startAnimationLoop() {
    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_disposed) return;
      _glideTowardTarget();
    });
  }

  void _maybeMoveCameraToVehicle() {
    final now = DateTime.now();
    if (_lastCameraMove != null &&
        now.difference(_lastCameraMove!).inMilliseconds <
            _cameraMoveIntervalMs) {
      return;
    }
    _lastCameraMove = now;
    moveMapToVehicle();
  }

  void _updateMovementSpeed(double speedKmH, String status, {String? mode}) {
    if (mode != null) _movementMode = mode;

    final speedMs = speedKmH.clamp(0.0, 200.0) / 3.6;

    if (speedKmH <= 0) {
      _currentSpeedMs = 0;
      _smoothedSpeedMs = 0;
      return;
    }

    if (speedMs >= 0.3) {
      _currentSpeedMs = speedMs;
      _smoothedSpeedMs = speedMs;
      _lastMovingTime = DateTime.now();
      return;
    }

    if (_smoothedSpeedMs >= 0.35) {
      _currentSpeedMs = _smoothedSpeedMs;
      return;
    }
    if (_lastMovingTime != null &&
        DateTime.now().difference(_lastMovingTime!).inSeconds < 45) {
      _currentSpeedMs = math.max(_currentSpeedMs, _smoothedSpeedMs * 0.85);
    }
  }

  (double, double)? _readLatLngFromMap(Map<String, dynamic> data) {
    final lat = double.tryParse(
      (data['latitude'] ?? data['lat'])?.toString() ?? '',
    );
    final lng = double.tryParse(
      (data['longitude'] ?? data['lng'] ?? data['lon'])?.toString() ?? '',
    );
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) return null;
    return (lat, lng);
  }

  num? _readSpeedFromMap(Map<String, dynamic> data) {
    final raw = data['speed'];
    if (raw is num) return raw;
    return num.tryParse(raw?.toString() ?? '');
  }

  double? _readCourseFromMap(Map<String, dynamic> data) {
    final raw = data['course'] ??
        data['angle'] ??
        data['heading'] ??
        data['direction'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  void onMapGesture() {
    isLocked.value = false;
    _userAdjustedZoom = true;
  }

  void moveMapToVehicle({bool snap = false, bool resetZoom = false}) {
    isLocked.value = true;
    if (resetZoom) _userAdjustedZoom = false;

    final lat = _animLat != 0.0 ? _animLat : animatedLat.value;
    final lng = _animLng != 0.0 ? _animLng : animatedLng.value;
    if (lat == 0.0 || lng == 0.0) return;

    double zoom = _followZoom;
    if (_userAdjustedZoom) {
      try {
        zoom = mapController.camera.zoom;
      } catch (_) {}
    }

    var center = LatLng(lat, lng);
      if (showBottomSheet.value) {
      final latOffset = 0.006 * math.pow(2, 15.0 - zoom);
        center = LatLng(lat - latOffset, lng);
      }

    if (snap || _smoothCameraLat == 0.0) {
      _smoothCameraLat = center.latitude;
      _smoothCameraLng = center.longitude;
    } else {
      const cameraAlpha = 0.55;
      _smoothCameraLat +=
          (center.latitude - _smoothCameraLat) * cameraAlpha;
      _smoothCameraLng +=
          (center.longitude - _smoothCameraLng) * cameraAlpha;
      }

      try {
      mapController.move(
        LatLng(_smoothCameraLat, _smoothCameraLng),
        zoom,
      );
      } catch (_) {}
  }

  void toggleBottomSheet() => showBottomSheet.value = !showBottomSheet.value;

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
      liveTrackData.value?.currentPosition?.lastUpdate ??
      liveTrackData.value?.currentPositionApi?.data?.lastUpdate ??
      '–';

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

  /// GSM from snapshot/WS `position.gsm_signal_strength` only.
  String get displayGsmSignal {
    final raw = liveTrackData.value?.currentPosition?.gsmSignalStrength;
    if (raw == null) return '–';
    final value = raw.trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return '–';
    return value;
  }

  String get displayNetwork {
    final raw = liveTrackData.value?.currentPosition?.network;
    if (raw == null) return '–';
    final value = raw.trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return '–';
    return value;
  }
  String get displayAltitude {
    final fromPos = liveTrackData.value?.currentPosition?.altitude;
    if (fromPos != null && fromPos.trim().isNotEmpty && fromPos != 'null') {
      return fromPos;
    }
    final fromApi = liveTrackData.value?.currentPositionApi?.data?.altitude;
    if (fromApi != null && fromApi.trim().isNotEmpty && fromApi != 'null') {
      return fromApi;
    }
    return '–';
  }

  String get displayTodayKm =>
      liveTrackData.value?.todayStatistics?.totalKilometersToday
          ?.toStringAsFixed(2) ??
      '0.00';
  /// Odometer km from `position.odometer`.
  String get displayOdometer {
    final value =
        odometerKm.value ?? liveTrackData.value?.currentPosition?.odometer;
    if (value == null) return '0.00';
    return value.toStringAsFixed(2);
  }

  /// 8 digit columns under the plate — whole km from `position.odometer`.
  String get displayOdometerDigits {
    final value =
        odometerKm.value ?? liveTrackData.value?.currentPosition?.odometer ?? 0;
    final wholeKm = value.floor().clamp(0, 99999999);
    return wholeKm.toString().padLeft(8, '0');
  }

  /// Total traveled km (`position.kilometer`), not the device odometer.
  String get displayTotalKm {
    final fromVehicle =
        liveTrackData.value?.vehicleInfo?.totalKilometersTraveled;
    if (fromVehicle != null && fromVehicle.trim().isNotEmpty) {
      return fromVehicle;
    }
    return liveTrackData.value?.currentPosition?.kilometer ?? '0.00';
  }

  String get displayStoppedDuration =>
      liveTrackData.value?.todayStatistics?.displayStoppedDuration ??
      '00:00:00';
  String get displayIdleDuration =>
      liveTrackData.value?.todayStatistics?.displayIdleDuration ?? '00:00:00';
  String get displayRunningDuration =>
      liveTrackData.value?.todayStatistics?.displayRunningDuration ??
      '00:00:00';
  String get displayInactiveDuration =>
      liveTrackData.value?.todayStatistics?.displayInactiveDuration ??
      '00:00:00';

  String get displayAvgSpeed =>
      liveTrackData.value?.todayStatistics?.avgSpeed?.toStringAsFixed(2) ??
      '–';
  String get displayMaxSpeed =>
      liveTrackData.value?.todayStatistics?.maxSpeed?.toStringAsFixed(0) ??
      '–';

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

  void _syncMarkerPosition() {
    final lat = _animLat != 0.0 ? _animLat : animatedLat.value;
    final lng = _animLng != 0.0 ? _animLng : animatedLng.value;
    if (lat == 0.0 && lng == 0.0) {
      if (reactiveMarkers.isNotEmpty) reactiveMarkers.clear();
      return;
    }

    final point = LatLng(lat, lng);
    if (reactiveMarkers.isEmpty) {
      reactiveMarkers.add(_buildVehicleMarker(point));
      return;
    }

    reactiveMarkers[0] = _buildVehicleMarker(point);
    reactiveMarkers.refresh();
  }

  Marker _buildVehicleMarker(LatLng point) {
    return Marker(
      point: point,
        width: 100,
        height: 100,
        child: GestureDetector(
        onTap: toggleBottomSheet,
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
    );
  }

  RxList<Marker> get mapMarkers => reactiveMarkers;

  double _normalizeBearing(double bearing) => (bearing % 360 + 360) % 360;

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
    const radius = 6371000.0;
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

  /// POST update_odometer — body: { imei, odometer }
  /// On success returns the new value; caller must close sheet BEFORE applying UI.
  Future<({bool ok, num? value, String message})> updateOdometer(
    String odometerInput,
  ) async {
    final imei = vehicleImei.value.trim();
    final trimmed = odometerInput.trim();
    final value = num.tryParse(trimmed);

    if (imei.isEmpty) {
      showErrorMessage('Vehicle IMEI is missing');
      return (ok: false, value: null, message: 'Vehicle IMEI is missing');
    }
    if (value == null || value < 0) {
      showErrorMessage('Enter a valid odometer value');
      return (ok: false, value: null, message: 'Enter a valid odometer value');
    }
    if (isUpdatingOdometer.value) {
      return (ok: false, value: null, message: 'Already updating');
    }

    isUpdatingOdometer.value = true;
    try {
      final response = await DioClient().post(
        ApiEndPoints.updateOdometer,
        body: {
          'imei': imei,
          'odometer': value,
        },
      );

      final raw = response.data;
      final ok = raw is Map
          ? (raw['status'] == true ||
              raw['success'] == true ||
              response.statusCode == 200)
          : response.statusCode == 200;

      if (!ok) {
        final msg = raw is Map
            ? (raw['message']?.toString() ?? 'Failed to update odometer')
            : 'Failed to update odometer';
        showErrorMessage(msg);
        clearOdometerUpdating();
        return (ok: false, value: null, message: msg);
      }

      final msg = (raw is Map ? raw['message']?.toString() : null) ??
          'Odometer updated';
      // No UI mutations here — applying while modal is open was freezing the app.
      return (ok: true, value: value, message: msg);
    } catch (e) {
      showErrorMessage(e);
      clearOdometerUpdating();
      return (ok: false, value: null, message: e.toString());
    }
  }

  /// Pull-to-refresh: optional snapshot catch-up only (keeps WebSocket alive).
  Future<void> refreshData() async {
    if (vehicleImei.value.isEmpty || _disposed) return;
    await _fetchLiveTrackSnapshot(vehicleImei.value, reconnectOnly: true);
  }

  Future<void> startTrackingForImei(String imei, {String? plate}) async {
    await _webSocketService.disconnect();
    vehicleImei.value = imei;
    if (plate != null && plate.isNotEmpty) vehiclePlate.value = plate;

    liveTrackData.value = null;
    _wsConfig = null;
    _wsInfo = null;
    _hasInitialCameraFocus = false;
    _smoothCameraLat = 0.0;
    _smoothCameraLng = 0.0;
    _userAdjustedZoom = false;
    _liveTarget = null;
    _lastAcceptedGps = null;
    _lastGlideTime = null;
    _lastGpsTime = null;
    _currentSpeedMs = 0;
    _smoothedSpeedMs = 0;
    _lastMovingTime = null;
    _movementMode = '';
    _lastReportedSpeedKmh = 0;
    _lastInferredSpeedKmh = 0;
    _lastGpsDeltaM = 0;
    _isMovingVehicle = false;
    _roadSpeedFactor = 1.0;
    _targetRoadSpeedFactor = 1.0;
    _smoothedGlideSpeedMs = 0.0;
    _routeRequestId = 0;
    _roadQueue.clear();
    _gpsTrace.clear();
    _lockedBearing = 0;
    _hasHeading = false;
    _animLat = 0;
    _animLng = 0;
    _lastUiSync = null;
    _lastUiSyncPoint = null;
    _pauseMarkerUi = false;
    odometerKm.value = null;
    animatedLat.value = 0;
    animatedLng.value = 0;
    animatedRotation.value = 0;

    await _fetchLiveTrackSnapshot(imei);
  }

  @override
  void onClose() {
    _disposed = true;
    _animationTimer?.cancel();
    _animationTimer = null;
    unawaited(_webSocketService.disconnect());
    fenceNameController.dispose();
    super.onClose();
  }
}
