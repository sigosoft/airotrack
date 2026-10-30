import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../../../../Configs/ApiConfigs.dart';
import '../../../../Models/LiveTrackModel.dart';
import '../../../../Configs/DioClient.dart';
import '../../../../Utils/Utils.dart';
import '../../../../Utils/vehicle_geofence_map_overlay.dart';
import '../../../../Services/LiveTrackWebSocketService.dart';
import '../../../../Services/DirectionsService.dart';
import '../../home/controllers/home_controller.dart';

/// Live tracking flow (snapshot once + WebSocket only):
/// 1. User selects vehicle on live track screen (IMEI from route).
/// 2. GET /website/live_track_snapshot?imei= once (Bearer via DioClient).
/// 3. Parse position.lat/lng, websocket.channel/event,
///    websocket_config.websocket_url + app_key.
/// 4. Show map immediately from snapshot position.
/// 5. Connect WebSocket using websocket_config (no Bearer).
/// 6. Subscribe pusher channel (e.g. device.<imei>).
/// 7. Listen for device.update on that channel.
/// 8. On each device.update, refresh the Mapbox road buffer (no polling).
/// 9. On socket drop, reconnect, resubscribe, optional snapshot catch-up.
/// 10. onClose, disconnect WebSocket.
///
/// MOTION MODEL (this is the part that kills vibration):
/// * There is exactly ONE position: [_pathLat]/[_pathLng]. It only ever moves
///   forward along the Mapbox polyline, so it physically cannot jitter
///   sideways or backwards.
/// * There is NO second EMA on position. Smoothing is applied to SPEED only.
/// * The car is always ON the road polyline. Route replacements re-project the
///   car onto the new geometry, so it never floats beside the road.
/// * A vsync Ticker drives the loop. Ticker callbacks run in the transient
///   phase, before build and paint, so the marker point and the camera centre
///   always commit in the same frame. Timer.periodic could not guarantee that
///   and caused the car to shift one frame against the map.
/// * While locked, the camera centre IS the marker point. Any residual noise
///   cancels out visually because both move together.
/// * The car is a native Google Maps marker, not a Flutter overlay. The map
///   engine draws it in the same pass as the road tiles, so it can never
///   drift off the road even when a platform camera update lands late.
class TrackController extends GetxController {
  final vehicleImei = ''.obs;
  final vehiclePlate = ''.obs;

  final liveTrackData = Rxn<LiveTrackData>();
  final isLiveLoading = false.obs;

  /// Low-rate readouts for text widgets. Not used for the marker.
  final animatedLat = 0.0.obs;
  final animatedLng = 0.0.obs;
  final animatedRotation = 0.0.obs;

  /// Screen position (map-local, logical px) of the car centre.
  ///
  /// The car is a Flutter widget over the map, not a native Google marker.
  /// The native marker re-applies its bitmap on every position update, which
  /// made the car blink at 60 fps. A Flutter overlay keeps the exact same
  /// image, size and rotation as before and never reloads.
  final ValueNotifier<Offset?> vehicleScreenOffset = ValueNotifier<Offset?>(null);

  /// Linked geofences drawn on the live map (`GET vehicle_geofences`).
  final vehicleGeofenceCircles = <gmaps.Circle>[].obs;
  final vehicleGeofencePolygons = <gmaps.Polygon>[].obs;

  // ---------------------------------------------------------------------
  // Single motion state
  // ---------------------------------------------------------------------

  /// The one true animated position. Always sits exactly on the road polyline.
  double _pathLat = 0.0;
  double _pathLng = 0.0;

  /// Raw travel bearing from the road ahead.
  double _lockedBearing = 0.0;

  /// Rate limited on-screen heading.
  double _uiHeading = 0.0;
  bool _hasHeading = false;
  final ValueNotifier<double> _headingNotifier = ValueNotifier<double>(0);

  gmaps.GoogleMapController? _mapController;
  final showBottomSheet = true.obs;
  final isLocked = true.obs;

  static const double _followZoom = 17.2;
  bool _userAdjustedZoom = false;
  bool _hasInitialCameraFocus = false;

  /// Camera the map is showing. While locked this is what we pushed; while
  /// the user pans it comes from onCameraMove. Used to place the car overlay.
  double _cameraZoom = _followZoom;
  LatLng? _cameraTarget;

  /// Size of the map viewport, reported by the view's LayoutBuilder.
  Size _mapSize = Size.zero;

  /// World size at zoom 0, in dp. Starts at Google's documented 256 and is
  /// corrected from Google's own projection, so the car overlay lands exactly
  /// where Google draws that coordinate.
  double _tileSize = 256.0;
  bool _calibBusy = false;
  DateTime? _lastCalibAt;

  /// Last camera we pushed, so an idle car does not spam the platform channel.
  LatLng? _lastSentCameraTarget;
  double? _lastSentCameraZoom;

  /// Pointer tracking used to tell user pans/pinches from our own follow moves.
  final Map<int, Offset> _mapPointerDown = {};
  static const double _panSlopPx = 10.0;

  /// True from the moment a second finger touches until all fingers lift, so
  /// the finger left after a pinch never counts as a pan.
  bool _pinching = false;

  /// Two-finger zoom is done by the app, not by Google Maps (its zoom gesture
  /// is off), so it zooms around the car exactly like + and -. The view turns
  /// Google's two-finger scroll off while this is true.
  final pinchActive = false.obs;
  final Map<int, Offset> _pointerNow = {};
  double? _pinchStartDist;
  double _pinchStartZoom = _followZoom;

  /// Stable marker child. Rebuilding Image/Obx every frame causes flicker.
  Widget? _vehicleMarkerChild;

  /// Streets map by default; user can switch to satellite via the map button.
  final mapType = gmaps.MapType.normal.obs;

  void toggleMapStyle() {
    mapType.value = mapType.value == gmaps.MapType.normal
        ? gmaps.MapType.hybrid
        : gmaps.MapType.normal;
  }

  bool _isFetchingSnapshot = false;
  bool _disposed = false;

  final LiveTrackWebSocketService _webSocketService =
      LiveTrackWebSocketService();
  LiveWebsocketConfig? _wsConfig;
  LiveWebsocketInfo? _wsInfo;

  Ticker? _ticker;
  Duration _lastTickStamp = Duration.zero;

  LatLng? _liveTarget;
  LatLng? _lastAcceptedGps;

  // ---------------------------------------------------------------------
  // Tuning
  // ---------------------------------------------------------------------

  /// Speed low pass time constant. Higher is smoother, lower is more reactive.
  static const double _speedTau = 0.50;

  static const double _maxGlideSpeedMs = 45.0;

  /// Minimum roll while the device reports movement (~2.2 km/h).
  static const double _minRollSpeedMs = 0.6;

  /// Slow forward roll while the device reports speed 0 (~1.3 km/h).
  static const double _stoppedCreepMs = 0.35;

  /// Ignore GPS noise while stopped.
  static const double _stoppedGpsDeadbandM = 6.0;

  /// Heading is taken this far down the road, not from the next vertex.
  /// Looking ahead is what removes the per-vertex rotation twitch.
  static const double _headingLookAheadM = 14.0;
  static const double _headingTau = 0.22;
  static const double _maxUiHeadingDegPerSec = 120.0;

  /// Minimum spacing between road waypoints.
  static const double _roadWaypointMinM = 4.0;

  /// Skip Mapbox for tiny hops.
  static const double _minRoadRouteMeters = 8.0;

  static const double _maxBackwardBearingDeg = 95.0;

  /// Consecutive GPS fixes that landed behind the car. One or two are stale or
  /// late fixes and are ignored; this many in a row is real reversing.
  static const int _reverseConfirmFixes = 3;

  /// Fix-to-fix movement against the heading that counts as real reversing.
  static const double _reverseGpsStepMeters = 6.0;
  int _behindStreak = 0;
  bool get _reverseConfirmed => _behindStreak >= _reverseConfirmFixes;

  /// A road whose first stretch runs this far off the travel heading is a
  /// backward road, not the way the car is going.
  static const double _maxRoadTurnBackDeg = 100.0;

  /// GPS target whose road was rejected. Mapbox gives the same answer again,
  /// so it is not re-requested every frame; the next fix asks fresh.
  LatLng? _rejectedRoadTarget;
  static const double _snapBackMinLagMeters = 4.0;
  static const double _reconnectSnapMeters = 150.0;
  static const double _minGpsBearingMoveM = 10.0;
  static const int _gpsTraceMaxPoints = 8;

  /// Readout throttling. Text fields do not need 60 fps.
  static const int _readoutIntervalMs = 250;
  static const int _rotationReadoutIntervalMs = 120;

  double _expectedPingSec = 6.0;
  double _glideSpeedMs = 0.0;
  int _routeRequestId = 0;
  DateTime? _lastRoadFetchAt;
  bool _roadFetchInFlight = false;
  LatLng? _pendingRoadTarget;

  /// Road-snapped waypoints the marker walks along (Mapbox only).
  final List<LatLng> _roadQueue = [];

  /// Last Mapbox geometry, kept so a stopped car can still sit on the road.
  final List<LatLng> _lastRoadCorridor = [];

  /// Device GPS samples, used ONLY to build Mapbox match/route requests.
  final List<LatLng> _gpsTrace = [];

  final DirectionsService _directionsService = DirectionsService();

  double _lastReportedSpeedKmh = 0.0;
  double _lastInferredSpeedKmh = 0.0;
  bool _isMovingVehicle = false;
  DateTime? _lastGpsTime;

  DateTime? _lastReadoutAt;
  DateTime? _lastRotationReadoutAt;

  final fenceNameController = TextEditingController();
  final fenceNameError = RxnString();
  final selectedShareOption = '24h'.obs;
  final isUpdatingOdometer = false.obs;

  /// Light odometer source for UI.
  final odometerKm = Rxn<num>();

  /// Pause marker UI while an input sheet is open (prevents ANR with IME).
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

  // ---------------------------------------------------------------------
  // Snapshot + WebSocket
  // ---------------------------------------------------------------------

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
        debugPrint('LiveTrack: invalid snapshot response');
        return;
      }
      final body = Map<String, dynamic>.from(rawBody);

      final snapshot = LiveTrackSnapshotModel.fromJson(body);
      final data = snapshot.data;
      if (data == null) {
        debugPrint('LiveTrack: snapshot missing data');
        return;
      }

      _wsConfig = data.websocketConfig;
      _wsInfo = data.websocket;

      liveTrackData.value = data.toLiveTrackData();
      _syncOdometerKm(liveTrackData.value?.currentPosition?.odometer);

      if (!reconnectOnly) {
        unawaited(loadVehicleGeofences());
      }

      if (reconnectOnly) {
        final pos = liveTrackData.value?.currentPosition;
        final lat = double.tryParse(pos?.latitude ?? '');
        final lng = double.tryParse(pos?.longitude ?? '');
        if (lat != null && lng != null && _pathLat != 0.0) {
          final snap = LatLng(lat, lng);
          final current = _publishedPoint();
          final lag = _calculateDistance(current, snap);
          if (lag > _reconnectSnapMeters && _isForwardOf(snap, current)) {
            _snapMarkerTo(snap, pos?.speed?.toDouble() ?? 0.0);
          } else if (lag > 1.0) {
            _onDevicePosition(
              snap,
              pos?.speed?.toDouble() ?? 0.0,
              status: pos?.derivedStatus,
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
      debugPrint('Live track snapshot error: $e');
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

    if (isInitial || (_pathLat == 0.0 && _pathLng == 0.0)) {
      _setPathPosition(location);
      _liveTarget = location;
      _lastAcceptedGps = location;
      _lastGpsTime = DateTime.now();
      _lastReportedSpeedKmh = speed;
      _lastInferredSpeedKmh = speed;
      _isMovingVehicle = speed > 0;
      _glideSpeedMs = speed > 0 ? (speed / 3.6).clamp(0.0, _maxGlideSpeedMs) : 0.0;
      _gpsTrace
        ..clear()
        ..add(location);

      // Seed Mapbox so animation starts on-road, not on raw GPS.
      _requestRoadPath(location, force: true);

      if (!_hasInitialCameraFocus && isLocked.value) {
        _hasInitialCameraFocus = true;
        moveMapToVehicle(snap: true, resetZoom: true);
      }
      _publishFrame(force: true);
      return;
    }

    _onDevicePosition(location, speed, status: pos?.derivedStatus);
  }

  Future<void> _connectWebSocket(String imei) async {
    if (_wsConfig == null) {
      debugPrint('LiveTrack: websocket_config missing from API');
      return;
    }

    final snapshot = LiveTrackSnapshotData(
      websocket: _wsInfo,
      websocketConfig: _wsConfig,
    );

    if (!snapshot.hasWebSocketConnectionConfig) {
      debugPrint('LiveTrack: websocket_config.websocket_url or app_key missing');
      return;
    }
    if (snapshot.channelFor(imei) == null) {
      debugPrint('LiveTrack: channel missing');
      return;
    }
    if (snapshot.eventNameFor() == null) {
      debugPrint('LiveTrack: event missing');
      return;
    }

    final connected = await _webSocketService.connect(
      imei: imei,
      websocketConfig: _wsConfig,
      websocket: _wsInfo,
      onDeviceUpdate: _handleDeviceUpdate,
      onReconnected: () {
        if (_disposed || vehicleImei.value.isEmpty) return;
        debugPrint('[LiveTrack] WS reconnected, refreshing snapshot');
        _fetchLiveTrackSnapshot(vehicleImei.value, reconnectOnly: true);
      },
    );

    if (!connected) {
      debugPrint('LiveTrack: WebSocket connection setup failed');
    }
  }

  void _handleDeviceUpdate(Map<String, dynamic> data) {
    if (_disposed) return;

    try {
      final coords = _readLatLngFromMap(data);
      if (coords == null) {
        debugPrint('LiveTrack: device.update missing lat/lng: $data');
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
        altitude:
            data['altitude']?.toString() ?? existing?.currentPosition?.altitude,
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
      );
    } catch (e, st) {
      debugPrint('LiveTrack device update error: $e\n$st');
    }
  }

  // ---------------------------------------------------------------------
  // GPS intake. GPS never moves the marker directly, it only retargets Mapbox.
  // ---------------------------------------------------------------------

  void _onDevicePosition(
    LatLng location,
    double speedKmH, {
    String? status,
    double? courseDeg,
  }) {
    final now = DateTime.now();
    final previousGps = _lastAcceptedGps;
    final previousGpsTime = _lastGpsTime;

    final reportedKmH = speedKmH;
    final inferredKmH = _inferSpeedKmh(location, speedKmH, now);
    _lastReportedSpeedKmh = reportedKmH;
    _lastInferredSpeedKmh = inferredKmH;

    // Learn the real ping interval so the speed target stays honest.
    if (previousGpsTime != null) {
      final interval = now.difference(previousGpsTime).inMilliseconds / 1000.0;
      if (interval >= 0.8 && interval < 60.0) {
        _expectedPingSec = _expectedPingSec * 0.7 + interval * 0.3;
      }
    }

    // Device speed decides moving vs stopped. GPS jitter alone must not
    // flip the car into chase mode, that was a vibration source.
    _isMovingVehicle = reportedKmH > 0;

    if (!_isMovingVehicle) {
      final gpsDeltaM =
          previousGps == null ? 0.0 : _calculateDistance(previousGps, location);
      if (previousGps != null && gpsDeltaM < _stoppedGpsDeadbandM) {
        _lastGpsTime = now;
        return;
      }
      if (!_hasHeading &&
          courseDeg != null &&
          courseDeg >= 0 &&
          courseDeg <= 360) {
        _setLockedBearing(courseDeg % 360);
      }
      _lastAcceptedGps = location;
      _lastGpsTime = now;
      _liveTarget = location;
      _requestRoadPath(location, force: true);
      return;
    }

    if (_hasHeading && _pathLat != 0.0) {
      final behind = _isBehind(LatLng(_pathLat, _pathLng), location);
      _behindStreak = behind ? _behindStreak + 1 : 0;

      // A late fix still moves forward from the previous fix. Real reversing
      // or a U-turn moves backward from fix to fix, so accept it at once.
      if (behind &&
          previousGps != null &&
          _calculateDistance(previousGps, location) >= _reverseGpsStepMeters &&
          !_isForwardOf(location, previousGps)) {
        _behindStreak = _reverseConfirmFixes;
      }
    }

    if (previousGps != null && _isLikelySnapBack(location, previousGps)) {
      _lastGpsTime = now;
      return;
    }

    _updateHeadingFromMovement(
      location,
      previousGps: previousGps,
      courseDeg: courseDeg,
    );

    _lastAcceptedGps = location;
    _lastGpsTime = now;
    _liveTarget = location;

    _requestRoadPath(location, force: _roadQueue.length < 2);
  }

  void _snapMarkerTo(LatLng location, double speedKmH) {
    _roadQueue.clear();
    _gpsTrace.clear();
    _setPathPosition(_snapToKnownRoad(location));
    _liveTarget = location;
    _lastAcceptedGps = location;
    _lastGpsTime = DateTime.now();
    _lastReportedSpeedKmh = speedKmH;
    _lastInferredSpeedKmh = speedKmH;
    _isMovingVehicle = speedKmH > 0;
    _requestRoadPath(location, force: true);
    _publishFrame(force: true);
  }

  /// A raw GPS fix can sit beside the road. When we already know the road
  /// nearby, start from its closest point instead of the raw fix.
  LatLng _snapToKnownRoad(LatLng p) {
    if (_lastRoadCorridor.length < 2) return p;
    final onRoad = _closestPointOnPolyline(p, _lastRoadCorridor);
    return _calculateDistance(p, onRoad) <= 60.0 ? onRoad : p;
  }

  /// Hard reset of the animated position.
  void _setPathPosition(LatLng p) {
    _pathLat = p.latitude;
    _pathLng = p.longitude;
  }

  LatLng _publishedPoint() => LatLng(_pathLat, _pathLng);

  // ---------------------------------------------------------------------
  // Frame loop
  // ---------------------------------------------------------------------

  void _startAnimationLoop() {
    _stopAnimationLoop();
    _lastTickStamp = Duration.zero;
    _ticker = Ticker(_onTick)..start();
  }

  void _stopAnimationLoop() {
    final t = _ticker;
    _ticker = null;
    if (t != null) {
      t.stop(canceled: true);
      t.dispose();
    }
  }

  void _onTick(Duration elapsed) {
    if (_disposed) return;

    var dt = _lastTickStamp == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTickStamp).inMicroseconds / 1000000.0;
    _lastTickStamp = elapsed;

    // Clamp so a backgrounded app does not resume with a huge jump.
    dt = dt.clamp(1 / 240, 0.1);
    _glide(dt);
  }

  void _glide(double dt) {
    if (_pathLat == 0.0 && _pathLng == 0.0) return;
    if (_liveTarget == null) return;

    if (_isMovingVehicle) {
      final pos = LatLng(_pathLat, _pathLng);
      final remaining = _remainingPathMeters(pos);
      final target = _targetSpeedMs(remaining);

      // Single symmetric low pass. No separate accel/decel caps, no additive
      // catch-up. Those produced the rise, brake, surge cycle.
      final alpha = 1.0 - math.exp(-dt / _speedTau);
      _glideSpeedMs += (target - _glideSpeedMs) * alpha;
      if (_glideSpeedMs < _minRollSpeedMs && remaining > 1.0) {
        _glideSpeedMs = _minRollSpeedMs;
      }
      if (_glideSpeedMs < 0) _glideSpeedMs = 0;

      var step = _glideSpeedMs * dt;
      if (step > remaining) step = remaining;

      if (_roadQueue.isEmpty) _reseedQueueFromCorridor();
      if (_roadQueue.isEmpty && !_roadFetchInFlight) {
        _fallbackPathTo(_liveTarget!);
      }
      if (step > 0.0005 && _roadQueue.isNotEmpty) {
        _advanceAlongRoad(step);
      }

      _maybePrefetchRoad(remaining);
    } else {
      _creepWhileStopped(dt);
    }

    _updateHeading(dt);
    _publishFrame();
  }

  /// Target speed = how fast we must move to consume the buffered road before
  /// the next WebSocket ping arrives, fenced by what the device reports.
  /// This is what keeps the car in step with reality without catch-up spikes.
  double _targetSpeedMs(double remaining) {
    final reported =
        math.max(_lastReportedSpeedKmh, _lastInferredSpeedKmh) / 3.6;
    final horizon = _expectedPingSec.clamp(1.5, 8.0);

    var v = remaining / horizon;

    if (reported > 0.4) {
      // Never crawl far below the real speed, never sprint far above it.
      v = v.clamp(reported * 0.6, reported * 1.8);
    } else {
      v = v.clamp(0.0, 14.0);
    }

    // Ease into the end of the buffer instead of stopping dead.
    if (remaining < 2.0) {
      v = math.min(v, math.max(remaining * 1.2, _minRollSpeedMs));
    }

    return v.clamp(0.0, _maxGlideSpeedMs);
  }

  /// Walk forward along the polyline. Position stays exactly on the road, so
  /// there is no lateral noise to smooth away in the first place.
  void _advanceAlongRoad(double step) {
    var pos = LatLng(_pathLat, _pathLng);
    var remaining = step;

    while (remaining > 0.001 && _roadQueue.isNotEmpty) {
      final next = _roadQueue.first;
      final dist = _calculateDistance(pos, next);

      if (dist < 0.05) {
        _roadQueue.removeAt(0);
        continue;
      }

      if (dist <= remaining) {
        pos = next;
        remaining -= dist;
        _roadQueue.removeAt(0);
      } else {
        final f = remaining / dist;
        pos = LatLng(
          pos.latitude + (next.latitude - pos.latitude) * f,
          pos.longitude + (next.longitude - pos.longitude) * f,
        );
        remaining = 0;
      }
    }

    _pathLat = pos.latitude;
    _pathLng = pos.longitude;
  }

  void _creepWhileStopped(double dt) {
    _glideSpeedMs = 0.0;
    if (_roadQueue.isEmpty && !_roadFetchInFlight) {
      _fallbackPathTo(_liveTarget!);
    }
    if (_roadQueue.isEmpty) return;

    final pos = LatLng(_pathLat, _pathLng);
    final remaining = _remainingPathMeters(pos);
    if (remaining <= 1.5) return;

    _advanceAlongRoad(math.min(_stoppedCreepMs * dt, remaining));
  }

  void _maybePrefetchRoad(double remaining) {
    final t = _liveTarget;
    if (t == null) return;

    final threshold = math.max(25.0, _glideSpeedMs * 3.0);
    if (remaining < threshold || _roadQueue.length < 2) {
      _requestRoadPath(t, force: _roadQueue.length < 2);
    }
  }

  // ---------------------------------------------------------------------
  // Heading
  // ---------------------------------------------------------------------

  void _updateHeading(double dt) {
    if (_roadQueue.isNotEmpty) {
      final ahead = _bearingLookAhead(
        LatLng(_pathLat, _pathLng),
        _headingLookAheadM,
      );
      if (ahead != null) _lockedBearing = ahead;
    }

    if (!_hasHeading) return;

    // Ease toward the road bearing with a low pass, then cap the turn rate.
    // Together these turn the car like a real vehicle instead of snapping at
    // each road vertex.
    final delta = _shortestBearingDelta(_uiHeading, _lockedBearing);
    final alpha = 1.0 - math.exp(-dt / _headingTau);
    final maxStep = _maxUiHeadingDegPerSec * dt;
    final step = (delta * alpha).clamp(-maxStep, maxStep);
    if (step.abs() < 0.02) return;

    _uiHeading = _normalizeBearing(_uiHeading + step);
    if (_shortestBearingDelta(_headingNotifier.value, _uiHeading).abs() >=
        0.12) {
      _headingNotifier.value = _uiHeading;
    }
  }

  /// Bearing toward a point [meters] down the queued road. Looking ahead
  /// instead of at the next vertex is what removes rotation twitch.
  double? _bearingLookAhead(LatLng from, double meters) {
    if (_roadQueue.isEmpty) return null;

    var traveled = 0.0;
    var prev = from;
    LatLng? pick;

    for (final p in _roadQueue) {
      traveled += _calculateDistance(prev, p);
      prev = p;
      pick = p;
      if (traveled >= meters) break;
    }

    if (pick == null) return null;
    if (_calculateDistance(from, pick) < 1.5) return null;
    return _getBearing(from, pick);
  }

  void _setLockedBearing(double bearing) {
    bearing = _normalizeBearing(bearing);
    if (!_hasHeading) {
      _lockedBearing = bearing;
      _uiHeading = bearing;
      _headingNotifier.value = bearing;
      animatedRotation.value = bearing;
      _hasHeading = true;
      return;
    }
    _lockedBearing = bearing;
  }

  void _updateHeadingFromMovement(
    LatLng location, {
    LatLng? previousGps,
    double? courseDeg,
  }) {
    // With a road queue the frame loop owns heading. GPS only seeds it.
    if (_roadQueue.length >= 2 && _hasHeading) return;

    double? movementBearing;
    var movedM = 0.0;

    if (previousGps != null) {
      movedM = _calculateDistance(previousGps, location);
      if (movedM >= _minGpsBearingMoveM) {
        movementBearing = _getBearing(previousGps, location);
      }
    }

    if (movementBearing == null && _pathLat != 0.0) {
      final current = LatLng(_pathLat, _pathLng);
      movedM = _calculateDistance(current, location);
      if (movedM >= _minGpsBearingMoveM * 1.5) {
        movementBearing = _getBearing(current, location);
      }
    }

    if (movementBearing != null) {
      if (_hasHeading) {
        final flip =
            _shortestBearingDelta(_lockedBearing, movementBearing).abs();
        if (flip > 55.0 && movedM < 25.0) return;
      }
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

  // ---------------------------------------------------------------------
  // Publishing. Marker and camera commit in the SAME frame, every frame.
  // ---------------------------------------------------------------------

  void _publishFrame({bool force = false}) {
    if (_pauseMarkerUi && !force) return;
    if (_pathLat == 0.0 && _pathLng == 0.0) return;

    final point = _publishedPoint();

    // Camera first, so the overlay projects against this frame's camera.
    if (isLocked.value) _followCamera(point);
    _syncMarkerPosition(point);
    _publishReadouts(point, force: force);
  }

  /// While locked the camera centre is the marker point. Because both are
  /// written in the same frame from the same value, the car sits perfectly
  /// still on screen and only the map slides. Two separate EMAs, one on the
  /// marker and one on the camera, is exactly what produced the wobble.
  void _followCamera(LatLng point) {
    var zoom = _followZoom;
    if (_userAdjustedZoom) {
      zoom = _readMapZoom();
    }

    var target = point;
    if (showBottomSheet.value) {
      final latOffset = 0.0012 * math.pow(2, 15.0 - zoom).toDouble();
      target = LatLng(point.latitude - latOffset, point.longitude);
    }

    _moveCamera(target, zoom);
  }

  /// Instant (non-animated) north-up, top-down camera move. Skipped when
  /// nothing changed so a parked car does not flood the platform channel.
  void _moveCamera(LatLng target, double zoom) {
    final controller = _mapController;
    if (controller == null) return;

    _cameraTarget = target;
    _cameraZoom = zoom;

    final last = _lastSentCameraTarget;
    if (last != null &&
        _lastSentCameraZoom == zoom &&
        (last.latitude - target.latitude).abs() < 1e-9 &&
        (last.longitude - target.longitude).abs() < 1e-9) {
      return;
    }
    _lastSentCameraTarget = target;
    _lastSentCameraZoom = zoom;
    _cameraZoom = zoom;

    controller
        .moveCamera(
          gmaps.CameraUpdate.newCameraPosition(
            gmaps.CameraPosition(
              target: gmaps.LatLng(target.latitude, target.longitude),
              zoom: zoom,
            ),
          ),
        )
        .catchError((_) {});
  }

  void _publishReadouts(LatLng point, {bool force = false}) {
    final now = DateTime.now();

    if (force ||
        _lastReadoutAt == null ||
        now.difference(_lastReadoutAt!).inMilliseconds >= _readoutIntervalMs) {
      _lastReadoutAt = now;
      animatedLat.value = point.latitude;
      animatedLng.value = point.longitude;
    }

    if (force ||
        _lastRotationReadoutAt == null ||
        now.difference(_lastRotationReadoutAt!).inMilliseconds >=
            _rotationReadoutIntervalMs) {
      if ((animatedRotation.value - _uiHeading).abs() >= 0.5) {
        _lastRotationReadoutAt = now;
        animatedRotation.value = _uiHeading;
      }
    }
  }

  double _readMapZoom() => _cameraZoom;

  void setInputSheetOpen(bool open) {
    _pauseMarkerUi = open;
    if (open) {
      _stopAnimationLoop();
      return;
    }
    if (!_disposed) {
      _startAnimationLoop();
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (!_disposed && !_pauseMarkerUi) {
          _publishFrame(force: true);
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

  // ---------------------------------------------------------------------
  // Mapbox road buffer
  // ---------------------------------------------------------------------

  void _requestRoadPath(LatLng to, {bool force = false}) {
    _pushGpsTrace(to);
    _pendingRoadTarget = to;

    if (_pathLat == 0.0 && _pathLng == 0.0) return;

    if (_roadFetchInFlight) return;

    final rejected = _rejectedRoadTarget;
    if (rejected != null && _calculateDistance(rejected, to) < 1.0) return;

    final now = DateTime.now();
    final queueEmpty = _roadQueue.length < 2;
    final minGapMs = queueEmpty ? 250 : 700;
    if (!force &&
        !queueEmpty &&
        _lastRoadFetchAt != null &&
        now.difference(_lastRoadFetchAt!).inMilliseconds < minGapMs) {
      return;
    }

    final from = LatLng(_pathLat, _pathLng);
    final straightM = _calculateDistance(from, to);

    if (straightM < _minRoadRouteMeters) return;
    if (!queueEmpty && straightM < 15.0 && _remainingPathMeters(from) > 20.0) {
      return;
    }
    // Never ask for a road back to a point behind the car, at any distance,
    // unless the car is really reversing.
    if (_hasHeading &&
        _isMovingVehicle &&
        !_reverseConfirmed &&
        _isBehind(from, to)) {
      return;
    }

    _lastRoadFetchAt = now;
    _roadFetchInFlight = true;
    final requestId = ++_routeRequestId;
    final fromPt = from;
    final toPt = to;
    final traceCopy = <LatLng>[..._gpsTrace];

    () async {
      try {
        List<LatLng> road = const [];

        road = await _directionsService.getRoute(fromPt, toPt, smooth: false);

        // No road, or a route that U-turns (typical on a divided highway when
        // the car sits on the other carriageway): follow the GPS trace instead.
        if (traceCopy.length >= 2 &&
            (road.length < 2 || _roadStartsBackward(road))) {
          final matched = await _directionsService.matchTrace(
            traceCopy,
            radiusMeters: 25,
          );
          if (matched.length >= 2) road = matched;
        }

        if (_disposed) return;
        if (requestId != _routeRequestId && _roadQueue.length >= 2) return;
        if (road.length < 2) {
          debugPrint(
            '[LiveTrack] Mapbox returned no road '
            '(${straightM.toStringAsFixed(1)}m)',
          );
          return;
        }

        final routeLenM = _pathLengthMeters(road);

        if (straightM > 0.5 &&
            routeLenM > straightM * 4.5 &&
            routeLenM > 40.0) {
          debugPrint(
            '[LiveTrack] Mapbox detour ignored '
            'road=${routeLenM.toStringAsFixed(0)}m '
            'straight=${straightM.toStringAsFixed(0)}m',
          );
          return;
        }

        final oriented = _orientPathWithTravel(road);
        var prepared = oriented;
        prepared = _decimatePath(prepared, _roadWaypointMinM);
        final trimmed = _trimRouteToUpdate(prepared, toPt);
        if (trimmed.length >= 2) prepared = trimmed;
        if (prepared.length < 2) return;

        if (_adoptRoadQueue(prepared, target: toPt)) {
          // Remember the road in travel direction, never the raw one.
          _lastRoadCorridor
            ..clear()
            ..addAll(oriented);
        }
      } catch (e) {
        debugPrint('[LiveTrack] Mapbox road path failed: $e');
      } finally {
        _roadFetchInFlight = false;
        final pending = _pendingRoadTarget;
        if (!_disposed &&
            pending != null &&
            _calculateDistance(pending, toPt) > _minRoadRouteMeters) {
          _requestRoadPath(pending, force: _roadQueue.length < 2);
        }
      }
    }();
  }

  /// Swap in new geometry without a single pixel of snap.
  ///
  /// The car is re-projected onto the new road line, so it stays on the road.
  /// Only the along-road distance matters; no lateral offset is ever kept.
  /// Returns true when the road was taken, false when it was rejected.
  bool _adoptRoadQueue(List<LatLng> path, {LatLng? target}) {
    if (path.length < 2) return false;

    final published = _publishedPoint();
    final onNew = _closestPointOnPolyline(published, path);
    final ahead = _trimRouteAhead(onNew, path);
    if (ahead.length < 2) return false;

    // A road that starts out backward is a U-turn route, not the way the car
    // is going. Never take it: the frame loop carries the car forward to the
    // fix along the known road instead (see [_fallbackPathTo]).
    if (_runsBackward(ahead)) {
      _rejectedRoadTarget = target;
      debugPrint('[LiveTrack] backward road ignored');
      return false;
    }
    _rejectedRoadTarget = null;

    // Ignore stale or shorter replacements while we still have good road left.
    if (_roadQueue.length >= 2) {
      final remainingNow = _remainingPathMeters(LatLng(_pathLat, _pathLng));
      final newRemaining = _pathLengthMeters(ahead);
      if (remainingNow > 20.0 &&
          newRemaining + 1.0 < remainingNow &&
          _calculateDistance(published, onNew) < 3.0) {
        return false;
      }
    }

    _roadQueue
      ..clear()
      ..addAll(ahead);

    // Always land on the new road line. The car never floats off the road.
    _pathLat = onNew.latitude;
    _pathLng = onNew.longitude;
    return true;
  }

  /// True when [path] heads against the car's travel direction while the
  /// device says it is moving forward.
  bool _runsBackward(List<LatLng> path) {
    if (!_hasHeading || !_isMovingVehicle || _reverseConfirmed) return false;
    final b = _pathBearingOverMeters(path, 15.0);
    if (b == null) return false;
    return _shortestBearingDelta(_lockedBearing, b).abs() > _maxRoadTurnBackDeg;
  }

  /// [_runsBackward] for a raw Mapbox road, measured from where the car is.
  bool _roadStartsBackward(List<LatLng> road) {
    final onRoad = _closestPointOnPolyline(_publishedPoint(), road);
    final ahead = _trimRouteAhead(onRoad, road);
    return ahead.length >= 2 && _runsBackward(ahead);
  }

  /// No road is queued (Mapbox still in flight). Continue along the last road
  /// we received, from the car's current position, instead of driving straight
  /// toward GPS across buildings and off the road.
  void _reseedQueueFromCorridor() {
    if (_lastRoadCorridor.length < 2) return;
    final pos = LatLng(_pathLat, _pathLng);
    final onRoad = _closestPointOnPolyline(pos, _lastRoadCorridor);
    final ahead = _trimRouteAhead(onRoad, _lastRoadCorridor);
    if (ahead.length < 2) return;
    if (_runsBackward(ahead)) return;
    _roadQueue
      ..clear()
      ..addAll(ahead);
  }

  /// Mapbox gave no usable road for the latest device.update. The car still
  /// goes there instead of stopping: along the last known road when the fix
  /// lies on it, otherwise straight to the fix.
  void _fallbackPathTo(LatLng target) {
    final pos = _publishedPoint();
    if (_calculateDistance(pos, target) < _minRoadRouteMeters) return;

    // A fix behind the car is a late fix, not a reason to back up. Wait for
    // the car's next fix instead, unless it is really reversing.
    if (_hasHeading && !_reverseConfirmed && _isBehind(pos, target)) return;

    // Mapbox already answered for this fix; do not ask again every frame.
    _rejectedRoadTarget = target;

    if (_lastRoadCorridor.length >= 2) {
      final onRoad = _snapToKnownRoad(target);
      if (!identical(onRoad, target)) {
        final ahead = _trimRouteAhead(
          _closestPointOnPolyline(pos, _lastRoadCorridor),
          _lastRoadCorridor,
        );
        final along = _trimRouteToUpdate(ahead, onRoad);
        if (along.length >= 2 && _calculateDistance(along.last, onRoad) < 15.0) {
          _roadQueue
            ..clear()
            ..addAll(along);
          return;
        }
      }
    }

    _roadQueue
      ..clear()
      ..add(target);
  }

  double _pathLengthMeters(List<LatLng> path) {
    if (path.length < 2) return 0.0;
    var total = 0.0;
    for (var i = 1; i < path.length; i++) {
      total += _calculateDistance(path[i - 1], path[i]);
    }
    return total;
  }

  double _remainingPathMeters(LatLng current) {
    if (_roadQueue.isEmpty) {
      if (_liveTarget == null) return 0.0;
      return _calculateDistance(current, _liveTarget!);
    }
    var total = _calculateDistance(current, _roadQueue.first);
    for (var i = 1; i < _roadQueue.length; i++) {
      total += _calculateDistance(_roadQueue[i - 1], _roadQueue[i]);
    }
    return total;
  }

  /// Drop dense Map Matching vertices that cause left/right vibration.
  List<LatLng> _decimatePath(List<LatLng> path, double minMeters) {
    if (path.length <= 2) return path;
    final out = <LatLng>[path.first];
    for (var i = 1; i < path.length - 1; i++) {
      if (_calculateDistance(out.last, path[i]) >= minMeters) {
        out.add(path[i]);
      }
    }
    if (_calculateDistance(out.last, path.last) >= 1.0 || out.length < 2) {
      out.add(path.last);
    } else {
      out[out.length - 1] = path.last;
    }
    return out;
  }

  /// Keep road geometry only up to the latest GPS, projected on the route.
  List<LatLng> _trimRouteToUpdate(List<LatLng> path, LatLng update) {
    if (path.length < 2) return path;

    var bestIdx = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < path.length; i++) {
      final d = _calculateDistance(path[i], update);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }

    final onSeg = bestIdx < path.length - 1
        ? _projectOnSegment(update, path[bestIdx], path[bestIdx + 1])
        : (bestIdx > 0
            ? _projectOnSegment(update, path[bestIdx - 1], path[bestIdx])
            : path[bestIdx]);

    final out = <LatLng>[];
    final endIdx =
        bestIdx < path.length - 1 ? bestIdx : math.max(0, bestIdx - 1);
    for (var i = 0; i <= endIdx; i++) {
      out.add(path[i]);
    }
    if (out.isEmpty || _calculateDistance(out.last, onSeg) >= 0.5) {
      out.add(onSeg);
    } else {
      out[out.length - 1] = onSeg;
    }
    return out.length >= 2 ? out : path;
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

  /// If [path] runs opposite recent travel, return it reversed.
  List<LatLng> _orientPathWithTravel(List<LatLng> path) {
    if (path.length < 2) return path;

    final pathBearing = _pathBearingOverMeters(path, 30.0);
    if (pathBearing == null) return path;

    // The locked heading is steadier than the last two GPS fixes, which jitter.
    double? travelBearing = _hasHeading ? _lockedBearing : null;
    if (travelBearing == null && _gpsTrace.length >= 2) {
      final prev = _gpsTrace[_gpsTrace.length - 2];
      final curr = _gpsTrace.last;
      if (_calculateDistance(prev, curr) >= 5.0) {
        travelBearing = _getBearing(prev, curr);
      }
    }
    if (travelBearing == null) return path;

    final vsTravel = _shortestBearingDelta(travelBearing, pathBearing).abs();
    if (vsTravel <= 100.0) return path;

    final reversed = path.reversed.toList();
    final revBearing = _pathBearingOverMeters(reversed, 30.0);
    if (revBearing == null) return path;

    final vsRev = _shortestBearingDelta(travelBearing, revBearing).abs();
    if (vsRev + 25.0 < vsTravel) return reversed;
    return path;
  }

  double? _pathBearingOverMeters(List<LatLng> path, double meters) {
    if (path.length < 2) return null;
    var traveled = 0.0;
    var i = 1;
    while (i < path.length && traveled < meters) {
      traveled += _calculateDistance(path[i - 1], path[i]);
      i++;
    }
    final end = path[math.min(i - 1, path.length - 1)];
    if (_calculateDistance(path.first, end) < 2.0) {
      return _getBearing(path[path.length - 2], path.last);
    }
    return _getBearing(path.first, end);
  }

  LatLng _closestPointOnPolyline(LatLng p, List<LatLng> poly) {
    if (poly.isEmpty) return p;
    if (poly.length == 1) return poly.first;

    var best = poly.first;
    var bestDist = _calculateDistance(p, best);

    for (var i = 0; i < poly.length - 1; i++) {
      final projected = _projectOnSegment(p, poly[i], poly[i + 1]);
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

    final out = <LatLng>[];
    var start = closestIdx;

    if (closestIdx < route.length - 1) {
      final projected = _projectOnSegment(
        from,
        route[closestIdx],
        route[closestIdx + 1],
      );
      out.add(projected);
      start = closestIdx + 1;
    } else if (closestDist < 3.0) {
      start = closestIdx + 1;
    }

    for (var i = start; i < route.length; i++) {
      if (out.isEmpty || _calculateDistance(out.last, route[i]) >= 0.6) {
        out.add(route[i]);
      }
    }
    return out;
  }

  bool _isForwardOf(LatLng point, LatLng origin) {
    if (!_hasHeading) return true;
    final bearing = _getBearing(origin, point);
    return _shortestBearingDelta(_lockedBearing, bearing).abs() <=
        _maxBackwardBearingDeg;
  }

  bool _isBehind(LatLng current, LatLng point) {
    if (!_hasHeading) return false;
    final bearing = _getBearing(current, point);
    return _shortestBearingDelta(_lockedBearing, bearing).abs() >
        _maxBackwardBearingDeg;
  }

  /// Stale GPS that would pull the marker backward after we have glided ahead.
  /// Genuine reverse still gets through.
  bool _isLikelySnapBack(LatLng location, LatLng previousGps) {
    if (!_hasHeading || _pathLat == 0.0) return false;

    final animated = LatLng(_pathLat, _pathLng);
    if (!_isBehind(animated, location)) return false;

    final lagM = _calculateDistance(animated, location);
    if (lagM < _snapBackMinLagMeters) return false;

    // Behind the car: stale or late unless several fixes in a row say so.
    return !_reverseConfirmed;
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

  // ---------------------------------------------------------------------
  // WebSocket payload parsers
  // ---------------------------------------------------------------------

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

  // ---------------------------------------------------------------------
  // Map gestures / camera controls
  // ---------------------------------------------------------------------

  void onMapCreated(gmaps.GoogleMapController controller) {
    _mapController = controller;
    _lastSentCameraTarget = null;
    _lastSentCameraZoom = null;
    if (_disposed) return;
    if (isLocked.value && !(_pathLat == 0.0 && _pathLng == 0.0)) {
      _followCamera(_publishedPoint());
    }
  }

  /// Mirrors the live camera so zoom reads stay synchronous. Also catches
  /// gestures with no pointer travel (double tap zoom) while locked.
  ///
  /// While locked, the camera state is what we pushed; echoes of our own
  /// moves arrive late and would drag the car backwards, so they are not
  /// adopted. Once unlocked, the reported camera drives the car overlay.
  /// While following, the camera is what we push, so its echoes are ignored.
  /// Once unlocked, the reported camera drives the car overlay.
  void onCameraMove(gmaps.CameraPosition position) {
    if (isLocked.value) return;
    _cameraZoom = position.zoom;
    _cameraTarget = LatLng(position.target.latitude, position.target.longitude);
    _syncMarkerPosition(_publishedPoint());
  }

  void onMapPointerDown(PointerDownEvent e) {
    _mapPointerDown[e.pointer] = e.position;
    _pointerNow[e.pointer] = e.position;
    if (_pointerNow.length >= 2) {
      _pinching = true;
      _startPinch();
    }
  }

  void _startPinch() {
    final d = _pinchDistance();
    if (d == null || d < 10) return;
    _pinchStartDist = d;
    _pinchStartZoom = _cameraZoom;
    pinchActive.value = true;
  }

  double? _pinchDistance() {
    if (_pointerNow.length < 2) return null;
    final p = _pointerNow.values.take(2).toList();
    return (p[0] - p[1]).distance;
  }

  /// Two fingers: zoom by the change in finger spread, through the same path
  /// as + and -, so the car stays centred and the map does not shake.
  /// One finger past the touch slop: a pan, which stops following.
  /// A plain tap is neither, so tapping the map still only hides the sheet.
  void onMapPointerMove(PointerMoveEvent e) {
    if (!_pointerNow.containsKey(e.pointer)) return;
    _pointerNow[e.pointer] = e.position;

    if (pinchActive.value) {
      final start = _pinchStartDist;
      final d = _pinchDistance();
      if (start != null && d != null && d > 0) {
        final z = (_pinchStartZoom + math.log(d / start) / math.ln2)
            .clamp(3.0, 20.0)
            .toDouble();
        _setZoom(z);
      }
      return;
    }

    if (_pinching) return;
    final start = _mapPointerDown[e.pointer];
    if (start != null && (e.position - start).distance > _panSlopPx) {
      onUserMapGesture();
    }
  }

  void onMapPointerUp(PointerEvent e) {
    _mapPointerDown.remove(e.pointer);
    _pointerNow.remove(e.pointer);
    if (_pointerNow.length < 2 && pinchActive.value) {
      pinchActive.value = false;
      _pinchStartDist = null;
    }
    if (_pointerNow.isEmpty) _pinching = false;
  }

  /// Zoom without moving the centre. While following, the follow loop applies
  /// it centred on the car on the next frame, exactly like + and -.
  void _setZoom(double z) {
    if ((z - _cameraZoom).abs() < 0.001) return;
    _userAdjustedZoom = true;
    _cameraZoom = z;
    if (isLocked.value) {
      _publishFrame(force: true);
      return;
    }
    _mapController
        ?.moveCamera(gmaps.CameraUpdate.zoomTo(z))
        .catchError((_) {});
  }

  /// Called when the user manually pans or zooms the map.
  void onUserMapGesture() {
    if (isLocked.value) {
      isLocked.value = false;
    }
    _userAdjustedZoom = true;
  }

  void zoomIn() => _applyZoomDelta(1.0);

  void zoomOut() => _applyZoomDelta(-1.0);

  void _applyZoomDelta(double delta) {
    final controller = _mapController;
    if (controller == null) return;
    final nextZoom = (_cameraZoom + delta).clamp(3.0, 20.0);
    _userAdjustedZoom = true;
    _cameraZoom = nextZoom;
    _lastSentCameraZoom = nextZoom;
    _lastSentCameraTarget = null;
    controller
        .moveCamera(gmaps.CameraUpdate.zoomTo(nextZoom))
        .catchError((_) {});
    if (isLocked.value) _publishFrame(force: true);
  }

  void moveMapToVehicle({bool snap = false, bool resetZoom = false}) {
    isLocked.value = true;
    if (resetZoom) _userAdjustedZoom = false;
    if (_pathLat == 0.0 && _pathLng == 0.0) return;
    _followCamera(_publishedPoint());
  }

  void toggleBottomSheet() => showBottomSheet.value = !showBottomSheet.value;

  // ---------------------------------------------------------------------
  // Geofences
  // ---------------------------------------------------------------------

  int? get resolvedVehicleId {
    final fromSnapshot = liveTrackData.value?.vehicleInfo?.id;
    if (fromSnapshot != null && fromSnapshot > 0) return fromSnapshot;
    if (vehicleImei.value.trim().isEmpty) return null;
    if (Get.isRegistered<HomeController>()) {
      for (final v in Get.find<HomeController>().vehicles) {
        if (v.deviceId.trim() == vehicleImei.value.trim()) return v.id;
      }
    }
    return null;
  }

  Future<void> loadVehicleGeofences() async {
    if (_disposed) return;
    final vehicleId = resolvedVehicleId;
    if (vehicleId == null || vehicleId <= 0) {
      vehicleGeofenceCircles.clear();
      vehicleGeofencePolygons.clear();
      return;
    }
    try {
      final response = await DioClient().get(
        ApiEndPoints.vehicleGeofences,
        query: {'vehicle_id': vehicleId.toString()},
      );
      final circles = <gmaps.Circle>[];
      final polygons = <gmaps.Polygon>[];
      VehicleGeofenceMapOverlay.parseApiResponse(
        response.data,
        circles: circles,
        polygons: polygons,
      );
      vehicleGeofenceCircles.assignAll(circles);
      vehicleGeofencePolygons.assignAll(polygons);
    } catch (e) {
      debugPrint('vehicle_geofences: $e');
    }
  }

  Future<void> refreshVehicleGeofences() => loadVehicleGeofences();

  // ---------------------------------------------------------------------
  // Display getters
  // ---------------------------------------------------------------------

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
      liveTrackData.value?.currentPosition?.deviceTime ?? '-';
  String get displayLastUpdate =>
      liveTrackData.value?.currentPosition?.lastUpdate ??
      liveTrackData.value?.currentPositionApi?.data?.lastUpdate ??
      '-';

  String get displayLatitude => animatedLat.value != 0.0
      ? animatedLat.value.toStringAsFixed(7)
      : (liveTrackData.value?.currentPosition?.latitude ?? '-');
  String get displayLongitude => animatedLng.value != 0.0
      ? animatedLng.value.toStringAsFixed(7)
      : (liveTrackData.value?.currentPosition?.longitude ?? '-');

  bool get isIgnitionOn =>
      liveTrackData.value?.currentPosition?.isIgnitionOn ?? false;
  bool get isPowerOn =>
      liveTrackData.value?.currentPosition?.isPowerOn ?? false;

  String get displayGsmSignal {
    final raw = liveTrackData.value?.currentPosition?.gsmSignalStrength;
    if (raw == null) return '-';
    final value = raw.trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return '-';
    return value;
  }

  String get displayNetwork {
    final raw = liveTrackData.value?.currentPosition?.network;
    if (raw == null) return '-';
    final value = raw.trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return '-';
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
    return '-';
  }

  String get displayTodayKm =>
      liveTrackData.value?.todayStatistics?.totalKilometersToday
          ?.toStringAsFixed(2) ??
      '0.00';

  String get displayOdometer {
    final value =
        odometerKm.value ?? liveTrackData.value?.currentPosition?.odometer;
    if (value == null) return '0.00';
    return value.toStringAsFixed(2);
  }

  String get displayOdometerDigits {
    final value =
        odometerKm.value ?? liveTrackData.value?.currentPosition?.odometer ?? 0;
    final wholeKm = value.floor().clamp(0, 99999999);
    return wholeKm.toString().padLeft(8, '0');
  }

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
      liveTrackData.value?.todayStatistics?.avgSpeed?.toStringAsFixed(2) ?? '-';
  String get displayMaxSpeed =>
      liveTrackData.value?.todayStatistics?.maxSpeed?.toStringAsFixed(0) ?? '-';

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

  // ---------------------------------------------------------------------
  // Marker
  // ---------------------------------------------------------------------

  static const double _vehicleMarkerSize = 48.0;

  /// Called from the view's build. Only stores the size; the next frame
  /// publishes the car position, so nothing notifies during build.
  void setMapSize(Size size) {
    _mapSize = size;
  }

  void _syncMarkerPosition(LatLng point) {
    if (point.latitude == 0.0 && point.longitude == 0.0) {
      vehicleScreenOffset.value = null;
      return;
    }
    vehicleScreenOffset.value = _projectToScreen(point);
    _calibrateProjection(point);
  }

  /// Asks Google where it draws [point] and corrects [_tileSize] to match. Needs
  /// the point to be away from the screen centre to measure the scale, which is
  /// the case while the bottom sheet shifts the camera, or after a pan.
  void _calibrateProjection(LatLng point) {
    final controller = _mapController;
    final cam = _cameraTarget;
    if (controller == null || cam == null || _mapSize.isEmpty) return;
    final now = DateTime.now();
    final last = _lastCalibAt;
    if (_calibBusy || (last != null && now.difference(last).inMilliseconds < 1500)) {
      return;
    }
    final mine = _projectToScreen(point);
    if (mine == null) return;
    final centre = Offset(_mapSize.width / 2, _mapSize.height / 2);
    final mineVec = mine - centre;
    if (mineVec.distance < 15) return;

    _calibBusy = true;
    _lastCalibAt = now;
    final tileAtAsk = _tileSize;
    controller
        .getScreenCoordinate(gmaps.LatLng(point.latitude, point.longitude))
        .then((sc) {
      final dpr =
          WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      final nativeVec = Offset(sc.x / dpr, sc.y / dpr) - centre;
      final ratio = nativeVec.distance / mineVec.distance;
      if (!ratio.isFinite || ratio < 0.4 || ratio > 2.6) {
        debugPrint('[LiveTrack] projection check skipped ratio=$ratio dpr=$dpr '
            'native=(${sc.x},${sc.y}) mine=$mine');
        return;
      }
      if ((ratio - 1).abs() > 0.03 && tileAtAsk == _tileSize) {
        debugPrint('[LiveTrack] projection corrected tile='
            '${_tileSize.toStringAsFixed(1)} ratio=${ratio.toStringAsFixed(3)}');
        _tileSize = (_tileSize * (0.5 + 0.5 * ratio)).clamp(100.0, 1100.0);
      }
    }).catchError((_) {}).whenComplete(() => _calibBusy = false);
  }

  /// Web Mercator, the same projection Google Maps renders with (256 dp world
  /// tile at zoom 0, camera target at the viewport centre, north-up, no tilt).
  Offset? _projectToScreen(LatLng p) {
    final cam = _cameraTarget;
    if (cam == null || _mapSize.isEmpty) return null;

    final scale = _tileSize * math.pow(2, _cameraZoom).toDouble();
    double worldX(double lng) => (lng + 180.0) / 360.0 * scale;
    double worldY(double lat) {
      final s = math.sin(lat * math.pi / 180).clamp(-0.9999, 0.9999);
      return (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * scale;
    }

    return Offset(
      _mapSize.width / 2 + (worldX(p.longitude) - worldX(cam.longitude)),
      _mapSize.height / 2 + (worldY(p.latitude) - worldY(cam.latitude)),
    );
  }

  /// Car layer stacked over the GoogleMap. Only the Positioned is rebuilt per
  /// frame; the image and its rotation live in a stable child.
  Widget buildVehicleOverlay() {
    _vehicleMarkerChild ??= _buildStableVehicleMarkerChild();
    return ValueListenableBuilder<Offset?>(
      valueListenable: vehicleScreenOffset,
      child: _vehicleMarkerChild,
      builder: (context, offset, child) {
        if (offset == null) return const SizedBox.shrink();
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: offset.dx - _vehicleMarkerSize / 2,
              top: offset.dy - _vehicleMarkerSize / 2,
              width: _vehicleMarkerSize,
              height: _vehicleMarkerSize,
              child: child!,
            ),
          ],
        );
      },
    );
  }

  /// Built once and reused. Rotation runs off a ValueNotifier inside a
  /// RepaintBoundary, so turning the icon never rebuilds the marker layer.
  Widget _buildStableVehicleMarkerChild() {
    return GestureDetector(
      onTap: toggleBottomSheet,
      behavior: HitTestBehavior.deferToChild,
      child: RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: _headingNotifier,
          builder: (context, heading, child) {
            return Transform.rotate(
              angle: heading * (math.pi / 180),
              filterQuality: FilterQuality.medium,
              child: child,
            );
          },
          child: Image.asset(
            'lib/Asset/Icons/Track Vehicle Top.png',
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            color: null,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Geometry helpers
  // ---------------------------------------------------------------------

  double _normalizeBearing(double bearing) => (bearing % 360 + 360) % 360;

  double _getBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lon1 = start.longitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final lon2 = end.longitude * math.pi / 180;
    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const radius = 6371000.0;
    final dLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final dLon = (p2.longitude - p1.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1.latitude * math.pi / 180) *
            math.cos(p2.latitude * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radius * (2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)));
  }

  // ---------------------------------------------------------------------
  // Odometer / lifecycle
  // ---------------------------------------------------------------------

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

      final msg =
          (raw is Map ? raw['message']?.toString() : null) ?? 'Odometer updated';
      return (ok: true, value: value, message: msg);
    } catch (e) {
      showErrorMessage(e);
      clearOdometerUpdating();
      return (ok: false, value: null, message: e.toString());
    }
  }

  /// Pull to refresh: snapshot catch-up only, keeps the WebSocket alive.
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
    _userAdjustedZoom = false;

    _liveTarget = null;
    _lastAcceptedGps = null;
    _lastGpsTime = null;
    _lastReportedSpeedKmh = 0;
    _lastInferredSpeedKmh = 0;
    _isMovingVehicle = false;
    _glideSpeedMs = 0.0;
    _expectedPingSec = 6.0;

    _routeRequestId = 0;
    _roadQueue.clear();
    _gpsTrace.clear();
    _lastRoadCorridor.clear();
    _roadFetchInFlight = false;
    _pendingRoadTarget = null;
    _lastRoadFetchAt = null;

    _pathLat = 0;
    _pathLng = 0;
    _lockedBearing = 0;
    _uiHeading = 0;
    _hasHeading = false;
    _behindStreak = 0;
    _rejectedRoadTarget = null;
    _headingNotifier.value = 0;

    vehicleScreenOffset.value = null;
    _vehicleMarkerChild = null;
    _cameraTarget = null;
    _lastSentCameraTarget = null;
    _lastSentCameraZoom = null;
    _cameraZoom = _followZoom;
    _lastReadoutAt = null;
    _lastRotationReadoutAt = null;
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
    _stopAnimationLoop();
    _mapController = null;
    _headingNotifier.dispose();
    vehicleScreenOffset.dispose();
    unawaited(_webSocketService.disconnect());
    fenceNameController.dispose();
    super.onClose();
  }
}