import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../../Configs/ApiConfigs.dart';
import '../../../../Models/LiveTrackModel.dart';
import '../../../../Configs/DioClient.dart';
import '../../../../Utils/Utils.dart';
import '../../../../Utils/vehicle_geofence_map_overlay.dart';
import '../../../../Services/LiveTrackWebSocketService.dart';
import '../../../../Services/DirectionsService.dart';
import '../../home/controllers/home_controller.dart';
import '../../../../widgets/map_widget.dart';

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
/// * Route replacements never teleport. The visual difference is stored in
///   [_corrLat]/[_corrLng] and decays to zero, so the car slides onto the new
///   geometry over ~0.4s instead of snapping.
/// * A vsync Ticker drives the loop. Ticker callbacks run in the transient
///   phase, before build and paint, so the marker point and the camera centre
///   always commit in the same frame. Timer.periodic could not guarantee that
///   and caused the car to shift one frame against the map.
/// * While locked, the camera centre IS the marker point. Any residual noise
///   cancels out visually because both move together.
class TrackController extends GetxController {
  final vehicleImei = ''.obs;
  final vehiclePlate = ''.obs;

  final liveTrackData = Rxn<LiveTrackData>();
  final isLiveLoading = false.obs;

  /// Low-rate readouts for text widgets. Not used for the marker.
  final animatedLat = 0.0.obs;
  final animatedLng = 0.0.obs;
  final animatedRotation = 0.0.obs;
  final reactiveMarkers = <Marker>[].obs;

  /// Linked geofences drawn on the live map (`GET vehicle_geofences`).
  final vehicleGeofenceCircles = <CircleMarker>[].obs;
  final vehicleGeofencePolygons = <Polygon>[].obs;

  // ---------------------------------------------------------------------
  // Single motion state
  // ---------------------------------------------------------------------

  /// The one true animated position. Always sits exactly on the road polyline.
  double _pathLat = 0.0;
  double _pathLng = 0.0;

  /// Decaying visual offset applied on top of [_pathLat]/[_pathLng].
  /// Set whenever we adopt new road geometry so the swap is invisible.
  double _corrLat = 0.0;
  double _corrLng = 0.0;

  /// Raw travel bearing from the road ahead.
  double _lockedBearing = 0.0;

  /// Rate limited on-screen heading.
  double _uiHeading = 0.0;
  bool _hasHeading = false;
  final ValueNotifier<double> _headingNotifier = ValueNotifier<double>(0);

  final MapController mapController = MapController();
  final showBottomSheet = true.obs;
  final isLocked = true.obs;

  static const double _followZoom = 18.0;
  bool _userAdjustedZoom = false;
  bool _hasInitialCameraFocus = false;

  /// Streets map by default; user can switch to satellite via the map button.
  final mapStyle = AiroMapStyle.mapboxStreets.obs;

  void toggleMapStyle() {
    mapStyle.value = mapStyle.value == AiroMapStyle.mapboxStreets
        ? AiroMapStyle.mapboxSatellite
        : AiroMapStyle.mapboxStreets;
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

  /// How fast a road correction offset fades out.
  static const double _correctionTau = 0.40;

  /// Never slide more than this to reach new geometry. Beyond it we teleport.
  static const double _maxCorrectionM = 30.0;
  static const double _teleportCorrectionM = 90.0;

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
  static const double _maxUiHeadingDegPerSec = 60.0;

  /// Minimum spacing between road waypoints.
  static const double _roadWaypointMinM = 4.0;

  /// Skip Mapbox for tiny hops.
  static const double _minRoadRouteMeters = 8.0;

  static const double _maxBackwardBearingDeg = 95.0;
  static const double _snapBackMinLagMeters = 4.0;
  static const double _reverseGpsStepMeters = 4.0;
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

  DateTime? _ignoreMapGestureUntil;
  DateTime? _lastReadoutAt;
  DateTime? _lastRotationReadoutAt;

  /// Stable marker child. Rebuilding Image/Obx every frame causes flicker.
  Widget? _vehicleMarkerChild;

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
    _setPathPosition(location);
    _liveTarget = location;
    _lastAcceptedGps = location;
    _lastGpsTime = DateTime.now();
    _lastReportedSpeedKmh = speedKmH;
    _lastInferredSpeedKmh = speedKmH;
    _isMovingVehicle = speedKmH > 0;
    _requestRoadPath(location, force: true);
    _publishFrame(force: true);
  }

  /// Hard reset of the animated position. Clears any pending correction.
  void _setPathPosition(LatLng p) {
    _pathLat = p.latitude;
    _pathLng = p.longitude;
    _corrLat = 0.0;
    _corrLng = 0.0;
  }

  LatLng _publishedPoint() => LatLng(_pathLat + _corrLat, _pathLng + _corrLng);

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

    _decayCorrection(dt);

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

      if (step > 0.0005) {
        if (_roadQueue.isNotEmpty) {
          _advanceAlongRoad(step);
        } else {
          _bridgeForward(step);
        }
      }

      _maybePrefetchRoad(remaining);
    } else {
      _creepWhileStopped(dt);
    }

    _updateHeading(dt);
    _publishFrame();
  }

  void _decayCorrection(double dt) {
    if (_corrLat == 0.0 && _corrLng == 0.0) return;
    final k = math.exp(-dt / _correctionTau);
    _corrLat *= k;
    _corrLng *= k;
    if (_corrLat.abs() < 1e-9) _corrLat = 0.0;
    if (_corrLng.abs() < 1e-9) _corrLng = 0.0;
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

  /// Mapbox is still in flight. Roll straight ahead so the car never freezes,
  /// but never past the latest known GPS.
  void _bridgeForward(double step) {
    final t = _liveTarget;
    if (t == null) return;

    final pos = LatLng(_pathLat, _pathLng);
    final dist = _calculateDistance(pos, t);
    if (dist < 1.0) return;
    if (_isBehind(pos, t)) return;

    final bearing = _hasHeading ? _lockedBearing : _getBearing(pos, t);
    final s = math.min(step, dist * 0.6);
    final next = _offsetMeters(pos, bearing, s);
    _pathLat = next.latitude;
    _pathLng = next.longitude;
  }

  void _creepWhileStopped(double dt) {
    _glideSpeedMs = 0.0;
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

    final delta = _shortestBearingDelta(_uiHeading, _lockedBearing);
    final maxStep = _maxUiHeadingDegPerSec * dt;
    final step = delta.clamp(-maxStep, maxStep);
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

    _syncMarkerPosition(point);
    if (isLocked.value) _followCamera(point);
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

    try {
      _ignoreMapGestureUntil =
          DateTime.now().add(const Duration(milliseconds: 120));
      mapController.move(target, zoom);
    } catch (_) {}
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

  double _readMapZoom() {
    try {
      return mapController.camera.zoom;
    } catch (_) {
      return _followZoom;
    }
  }

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
    if (_hasHeading && _isBehind(from, to) && straightM < 50.0) return;

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

        if (road.length < 2 && traceCopy.length >= 2) {
          road = await _directionsService.matchTrace(
            traceCopy,
            radiusMeters: 25,
          );
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

        _lastRoadCorridor
          ..clear()
          ..addAll(road);

        var prepared = _orientPathWithTravel(road);
        prepared = _decimatePath(prepared, _roadWaypointMinM);
        final trimmed = _trimRouteToUpdate(prepared, toPt);
        if (trimmed.length >= 2) prepared = trimmed;
        if (prepared.length < 2) return;

        _adoptRoadQueue(prepared);
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
  /// The visible point stays exactly where it was; the difference between it
  /// and the projection onto the new road is parked in the correction offset
  /// and bled off over [_correctionTau]. That is the whole trick that replaced
  /// the old blend / hard-snap ladder.
  void _adoptRoadQueue(List<LatLng> path) {
    if (path.length < 2) return;

    final published = _publishedPoint();
    final onNew = _closestPointOnPolyline(published, path);
    final ahead = _trimRouteAhead(onNew, path);
    if (ahead.length < 2) return;

    // Ignore stale or shorter replacements while we still have good road left.
    if (_roadQueue.length >= 2) {
      final remainingNow = _remainingPathMeters(LatLng(_pathLat, _pathLng));
      final newRemaining = _pathLengthMeters(ahead);
      if (remainingNow > 20.0 &&
          newRemaining + 1.0 < remainingNow &&
          _calculateDistance(published, onNew) < 3.0) {
        return;
      }
    }

    final offsetM = _calculateDistance(published, onNew);

    _roadQueue
      ..clear()
      ..addAll(ahead);

    _pathLat = onNew.latitude;
    _pathLng = onNew.longitude;

    if (offsetM > _teleportCorrectionM) {
      _corrLat = 0.0;
      _corrLng = 0.0;
      return;
    }

    var dLat = published.latitude - onNew.latitude;
    var dLng = published.longitude - onNew.longitude;
    if (offsetM > _maxCorrectionM && offsetM > 0) {
      final k = _maxCorrectionM / offsetM;
      dLat *= k;
      dLng *= k;
    }
    _corrLat = dLat;
    _corrLng = dLng;
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

    double? travelBearing;
    if (_gpsTrace.length >= 2) {
      final prev = _gpsTrace[_gpsTrace.length - 2];
      final curr = _gpsTrace.last;
      if (_calculateDistance(prev, curr) >= 5.0) {
        travelBearing = _getBearing(prev, curr);
      }
    }
    travelBearing ??= _hasHeading ? _lockedBearing : null;
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

    final gpsStepM = _calculateDistance(previousGps, location);
    if (gpsStepM < 1.0) return true;

    final gpsMovingBackward = !_isForwardOf(location, previousGps) &&
        gpsStepM >= _reverseGpsStepMeters;
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

  /// Called when the user manually pans or zooms the map.
  ///
  /// Do NOT apply the [_ignoreMapGestureUntil] filter here. While locked the
  /// camera moves every frame and keeps extending that window, which would
  /// stop the user from ever unlocking follow mode.
  void onUserMapGesture() {
    if (isLocked.value) {
      isLocked.value = false;
    }
    _userAdjustedZoom = true;
    _ensureNorthUp();
  }

  void onMapGesture() {
    final until = _ignoreMapGestureUntil;
    if (until != null && DateTime.now().isBefore(until)) return;
    if (isLocked.value) {
      isLocked.value = false;
    }
    _userAdjustedZoom = true;
    _ensureNorthUp();
  }

  void _ensureNorthUp() {
    try {
      final cam = mapController.camera;
      if (cam.rotation.abs() < 0.05) return;
      _ignoreMapGestureUntil =
          DateTime.now().add(const Duration(milliseconds: 200));
      mapController.moveAndRotate(cam.center, cam.zoom, 0);
    } catch (_) {}
  }

  void zoomIn() => _applyZoomDelta(1.0);

  void zoomOut() => _applyZoomDelta(-1.0);

  void _applyZoomDelta(double delta) {
    try {
      final camera = mapController.camera;
      final nextZoom = (camera.zoom + delta).clamp(3.0, 20.0);
      _userAdjustedZoom = true;
      _ignoreMapGestureUntil =
          DateTime.now().add(const Duration(milliseconds: 200));
      mapController.moveAndRotate(camera.center, nextZoom, 0);
    } catch (_) {}
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
      final circles = <CircleMarker>[];
      final polygons = <Polygon>[];
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

  void _syncMarkerPosition(LatLng point) {
    if (point.latitude == 0.0 && point.longitude == 0.0) {
      if (reactiveMarkers.isNotEmpty) reactiveMarkers.clear();
      _vehicleMarkerChild = null;
      return;
    }

    _vehicleMarkerChild ??= _buildStableVehicleMarkerChild();

    final marker = Marker(
      key: const ValueKey('live_vehicle_marker'),
      point: point,
      width: 48,
      height: 48,
      alignment: Alignment.center,
      child: _vehicleMarkerChild!,
    );

    if (reactiveMarkers.isEmpty) {
      reactiveMarkers.add(marker);
      return;
    }

    // Index assign notifies Obx once. An extra refresh() would double rebuild.
    reactiveMarkers[0] = marker;
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

  RxList<Marker> get mapMarkers => reactiveMarkers;

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
    _corrLat = 0;
    _corrLng = 0;
    _lockedBearing = 0;
    _uiHeading = 0;
    _hasHeading = false;
    _headingNotifier.value = 0;

    _vehicleMarkerChild = null;
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
    _headingNotifier.dispose();
    unawaited(_webSocketService.disconnect());
    fenceNameController.dispose();
    super.onClose();
  }
}