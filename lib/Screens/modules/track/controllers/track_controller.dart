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

  final animatedLat = 0.0.obs;
  final animatedLng = 0.0.obs;
  final animatedRotation = 0.0.obs;
  final reactiveMarkers = <Marker>[].obs;

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
  static const int _cameraMoveIntervalMs = 50;
  static const double _gpsJitterMeters = 2.0;
  static const double _minRotationChangeDeg = 22.0;
  static const double _minGpsBearingMoveM = 5.0;
  static const double _frameSeconds = 0.016;
  /// Minimum roll speed between WS pings (~1.8 km/h).
  static const double _wsWaitCreepMinMs = 0.5;
  static const double _movingGpsDeltaM = 0.4;

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
      if (reconnectOnly) {
        final pos = liveTrackData.value?.currentPosition;
        final lat = double.tryParse(pos?.latitude ?? '');
        final lng = double.tryParse(pos?.longitude ?? '');
        if (lat != null && lng != null && animatedLat.value != 0.0) {
          final snap = LatLng(lat, lng);
          final current = LatLng(animatedLat.value, animatedLng.value);
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

    if (isInitial || animatedLat.value == 0.0 || animatedLng.value == 0.0) {
      animatedLat.value = lat;
      animatedLng.value = lng;
      _liveTarget = location;
      _lastAcceptedGps = location;
      _lastGpsTime = DateTime.now();
      _lastReportedSpeedKmh = speed;
      _lastInferredSpeedKmh = speed;
      _lastGpsDeltaM = 0;
      _isMovingVehicle = speed > 0;
      _smoothedGlideSpeedMs = speed > 0
          ? (speed / 3.6).clamp(_wsWaitCreepMinMs, _maxGlideSpeedMs)
          : 0.0;
      _updateMovementSpeed(speed, pos?.derivedStatus ?? 'Stopped', mode: pos?.mode);
      _updateMarkers();
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

    _isMovingVehicle = reportedKmH > 0 ||
        speedKmH >= 1.5 ||
        gpsDeltaM >= _movingGpsDeltaM;

    _updateMovementSpeed(
      _isMovingVehicle ? math.max(speedKmH, reportedKmH) : 0,
      status ?? 'Stopped',
      mode: mode,
    );

    if (previousGps != null) {
      final delta = gpsDeltaM;
      if (delta < _gpsJitterMeters && !_isMovingVehicle) {
        _lastGpsTime = now;
        return;
      }
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
    if (_isMovingVehicle) {
      _smoothedGlideSpeedMs = math.max(
        _smoothedGlideSpeedMs,
        _wsWaitCreepMinMs,
      );
    }

    if (previousGps != null) {
      _requestRoadSpeedFactor(previousGps, location);
    }
  }

  void _snapMarkerTo(
    LatLng location,
    double speedKmH, {
    String? status,
    String? mode,
  }) {
    animatedLat.value = location.latitude;
    animatedLng.value = location.longitude;
    _liveTarget = location;
    _lastAcceptedGps = location;
    _lastGpsTime = DateTime.now();
    _lastReportedSpeedKmh = speedKmH;
    _lastInferredSpeedKmh = speedKmH;
    _isMovingVehicle = speedKmH > 0;
    _updateMovementSpeed(speedKmH, status ?? 'Stopped', mode: mode);
    _syncMarkerPosition();
    if (isLocked.value) _maybeMoveCameraToVehicle();
  }

  /// Mapbox route length vs straight GPS line — roads are longer, so boost glide speed.
  void _requestRoadSpeedFactor(LatLng from, LatLng to) {
    final straightM = _calculateDistance(from, to);
    if (straightM < 8.0) {
      _targetRoadSpeedFactor = 1.0;
      return;
    }

    final requestId = ++_routeRequestId;
    _directionsService.getRoute(from, to).then((route) {
      if (_disposed || requestId != _routeRequestId) return;
      if (route.length < 2) {
        _targetRoadSpeedFactor = 1.0;
        return;
      }

      var routeLenM = 0.0;
      for (var i = 1; i < route.length; i++) {
        routeLenM += _calculateDistance(route[i - 1], route[i]);
      }
      if (straightM > 1.0) {
        _targetRoadSpeedFactor = (routeLenM / straightM).clamp(1.0, 1.35);
      }
    }).catchError((_) {
      if (!_disposed && requestId == _routeRequestId) {
        _targetRoadSpeedFactor = 1.0;
      }
    });
  }

  bool _shouldKeepMoving() => _isMovingVehicle;

  double _distanceToLiveGps(LatLng current) {
    if (_liveTarget == null) return double.infinity;
    return _calculateDistance(current, _liveTarget!);
  }

  double _resolveTravelBearing(LatLng current) {
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
  double _continuousSpeedMs(double distToGps) {
    if (!_isMovingVehicle) return 0;

    var ms = _effectiveSpeedMs();
    if (ms < _wsWaitCreepMinMs) {
      ms = math.max(
        math.max(_lastReportedSpeedKmh, _lastInferredSpeedKmh),
        3.0,
      ) / 3.6;
    }

    if (distToGps > 0.3) {
      ms = math.max(ms, distToGps / math.max(_expectedPingSec, 0.8));
    }

    if (_liveTarget != null &&
        animatedLat.value != 0.0 &&
        distToGps >= _catchUpMinLagMeters) {
      final current = LatLng(animatedLat.value, animatedLng.value);
      if (!_hasHeading || !_isBehind(current, _liveTarget!)) {
        ms = math.max(ms, distToGps / _catchUpWindowSec);
      }
    }

    return (ms * _roadSpeedFactor).clamp(_wsWaitCreepMinMs, _maxGlideSpeedMs);
  }

  void _advanceMarkerContinuously({
    required LatLng current,
    required LatLng gpsTarget,
    required double bearing,
    required double step,
    required double distToGps,
  }) {
    if (step <= 0) return;

    if (distToGps > 0.2) {
      final before = LatLng(animatedLat.value, animatedLng.value);
      _nudgeToward(gpsTarget, math.min(step, distToGps));
      final after = LatLng(animatedLat.value, animatedLng.value);
      if (_calculateDistance(before, after) >= 0.001) return;
    }

    final anchor = LatLng(animatedLat.value, animatedLng.value);
    final next = _offsetMeters(anchor, bearing, step);
    animatedLat.value = next.latitude;
    animatedLng.value = next.longitude;
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
    if (previousGps != null) {
      final moved = _calculateDistance(previousGps, location);
      if (moved >= _minGpsBearingMoveM) {
        movementBearing = _getBearing(previousGps, location);
      }
    }
    if (movementBearing == null && animatedLat.value != 0.0) {
      final current = LatLng(animatedLat.value, animatedLng.value);
      final moved = _calculateDistance(current, location);
      if (moved >= _minGpsBearingMoveM) {
        movementBearing = _getBearing(current, location);
      }
    }

    if (movementBearing != null) {
      _setLockedBearing(movementBearing);
      return;
    }

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
    if (diff >= _minRotationChangeDeg) {
      _lockedBearing = bearing;
      animatedRotation.value = bearing;
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
    if (!_hasHeading || animatedLat.value == 0.0) return false;

    final animated = LatLng(animatedLat.value, animatedLng.value);
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
    final lat = animatedLat.value;
    final lng = animatedLng.value;
    if (lat == 0.0 && lng == 0.0) return;

    final dist = _calculateDistance(LatLng(lat, lng), target);
    if (dist < 0.01) return;

    final step = math.min(meters, dist);
    final fraction = step / dist;
    animatedLat.value = lat + (target.latitude - lat) * fraction;
    animatedLng.value = lng + (target.longitude - lng) * fraction;
  }

  void _glideTowardTarget() {
    if (animatedLat.value == 0.0 && animatedLng.value == 0.0) return;

    final now = DateTime.now();
    final dtSec = _lastGlideTime == null
        ? _frameSeconds
        : now.difference(_lastGlideTime!).inMicroseconds / 1000000.0;
    _lastGlideTime = now;
    final dt = dtSec.clamp(0.008, 0.05);

    _roadSpeedFactor +=
        (_targetRoadSpeedFactor - _roadSpeedFactor) * 0.06;

    final current = LatLng(animatedLat.value, animatedLng.value);

    if (_liveTarget == null) return;

    if (!_shouldKeepMoving()) {
      final settleDist = _distanceToLiveGps(current);
      if (settleDist > 0.05) {
        _nudgeToward(_liveTarget!, math.min(0.6 * dt, settleDist));
      }
      _smoothedGlideSpeedMs = 0;
      _syncMarkerPosition();
      if (isLocked.value) _maybeMoveCameraToVehicle();
      return;
    }

    final distToGps = _distanceToLiveGps(current);
    final bearing = _resolveTravelBearing(current);
    final targetSpeed = _continuousSpeedMs(distToGps);

    _smoothedGlideSpeedMs += (targetSpeed - _smoothedGlideSpeedMs) * 0.2;
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

    _syncMarkerPosition();
    if (isLocked.value) _maybeMoveCameraToVehicle();
  }

  void _startAnimationLoop() {
    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
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

    final lat = animatedLat.value;
    final lng = animatedLng.value;
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
    final lat = animatedLat.value;
    final lng = animatedLng.value;
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

  void _updateMarkers() => _syncMarkerPosition();

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
    _lockedBearing = 0;
    _hasHeading = false;
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
