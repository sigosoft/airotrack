import 'dart:async';
import 'dart:math' as math;

import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/HistoryModel.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

Future<Map<String, dynamic>> _getHistoryInIsolate(
  Map<String, dynamic> params,
) async {
  try {
    final dio = Dio(
      BaseOptions(
        baseUrl: params['baseUrl'] as String,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: <String, dynamic>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (params['token'] != null)
            'Authorization': params['token'] as String,
        },
      ),
    );
    final response = await dio.get<Map<String, dynamic>>(
      params['path'] as String,
      queryParameters: params['query'] as Map<String, dynamic>,
    );
    return <String, dynamic>{
      'data': response.data,
      'statusCode': response.statusCode,
    };
  } catch (e, st) {
    return <String, dynamic>{
      'error': e.toString(),
      'stackTrace': st.toString(),
    };
  }
}

/// Top-level for isolate: build polyline points with deviceTime for pipeline (sendable types only).
List<Map<String, dynamic>> _buildPolylinePointsInIsolate(Map<String, dynamic>? responseBody) {
  if (responseBody == null) {
    debugPrint('[History] Isolate: no responseBody, returning []');
    return [];
  }
  final model = HistoryModel.fromJson(responseBody);
  final list = model.data?.locationHistory ?? [];
  debugPrint('[History] Isolate: location_history count from backend = ${list.length}');
  final points = <Map<String, dynamic>>[];
  for (final item in list) {
    final lat = item.latitude != null
        ? double.tryParse(item.latitude!.trim())
        : null;
    final lng = item.longitude != null
        ? double.tryParse(item.longitude!.trim())
        : null;
    if (lat != null &&
        lng != null &&
        lat.abs() <= 90 &&
        lng.abs() <= 180 &&
        (lat != 0 || lng != 0)) {
      points.add({
        'lat': lat,
        'lng': lng,
        'deviceTime': item.deviceTime ?? '',
      });
    }
  }
  debugPrint('[History] Isolate: valid points (lat/lng parsed) = ${points.length}');
  if (points.isNotEmpty) {
    debugPrint('[History] Isolate: first point lat=${points.first['lat']} lng=${points.first['lng']} deviceTime=${points.first['deviceTime']}');
    debugPrint('[History] Isolate: last point lat=${points.last['lat']} lng=${points.last['lng']} deviceTime=${points.last['deviceTime']}');
  }
  return points;
}

/// Bearing in degrees (0-360) from [start] to [end] for marker rotation.
double _getBearing(LatLng start, LatLng end) {
  final lat1 = start.latitude * math.pi / 180;
  final lon1 = start.longitude * math.pi / 180;
  final lat2 = end.latitude * math.pi / 180;
  final lon2 = end.longitude * math.pi / 180;
  final dLon = lon2 - lon1;
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  final bearing = math.atan2(y, x);
  return (bearing * 180 / math.pi + 360) % 360;
}

/// Mapbox Map Matching API (snaps GPS track to road). Max 100 points per request.
const String _mapboxMatchBase = 'https://api.mapbox.com/matching/v5/mapbox/driving';

/// Top-level: parse Mapbox match response to list of [lat, lng]. Geometry is GeoJSON [lng, lat].
List<List<double>> _processMapboxChunk(Map<String, dynamic> data) {
  final result = <List<double>>[];
  if (data['code']?.toString() != 'Ok') return result;
  final matchings = data['matchings'];
  if (matchings == null || matchings is! List || matchings.isEmpty) return result;
  for (final m in matchings) {
    if (m is! Map<String, dynamic>) continue;
    final geometry = m['geometry'];
    if (geometry == null || geometry is! Map) continue;
    final coords = geometry['coordinates'];
    if (coords == null || coords is! List) continue;
    for (final c in coords) {
      if (c is List && c.length >= 2) {
        final lng = (c[0] is num) ? (c[0] as num).toDouble() : null;
        final lat = (c[1] is num) ? (c[1] as num).toDouble() : null;
        if (lat != null && lng != null) result.add([lat, lng]);
      }
    }
  }
  return result;
}

class HistoryController extends GetxController {
  var showBottomSheet = true.obs;
  final List<String> dateRangeOptions = [
    "1 hour",
    "Today",
    "Yesterday",
    "Week",
    "Custom",
  ];
  var selectedDateRange = "Today".obs;
  var isLoading = false.obs;

  void updateDateRange(String value) {
    selectedDateRange.value = value;
    // Here you would typically also update fromDate and toDate based on the selection
  }

  var fromDate = "-:-".obs;
  var toDate = "-:-".obs;
  var vehicleId = "KL 07 D 0518".obs;

  @override
  void onInit() {
    super.onInit();
    final imeiParam = Get.parameters['imei'];
    final nameParam = Get.parameters['vehicleId'];
    if (imeiParam != null && imeiParam.isNotEmpty) {
      vehicleId.value = nameParam ?? imeiParam;
    }
  }

  var currentSpeed = "0 Kmph".obs;
  var duration = "00:00:00".obs;
  var totalDistance = "12.5 Km".obs;

  var playbackSpeed = "1X".obs;
  var isPlaying = false.obs;
  var progress = 0.0.obs;

  void toggleBottomSheet() {
    showBottomSheet.value = !showBottomSheet.value;
  }

  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _apiDateFormat = DateFormat('yyyy-MM-dd');

  DateTime _parseDisplayDate(String value) {
    try {
      return _dateFormat.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<void> pickFromDate(BuildContext context) async {
    final initial = _parseDisplayDate(fromDate.value);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      fromDate.value = _dateFormat.format(picked);
      if (toDate.value != '-:-') {
        final imei = Get.parameters['imei'] ?? '';
        getHistory(imei);
      }
    }
  }

  Future<void> pickToDate(BuildContext context) async {
    final initial = _parseDisplayDate(toDate.value);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      toDate.value = _dateFormat.format(picked);
      if (fromDate.value != '-:-') {
        final imei = Get.parameters['imei'] ?? '';
        getHistory(imei);
      }
    }
  }

  HistoryModel historyModel = HistoryModel();

  /// Cached after parsing in isolate; avoids recomputing on every build.
  List<LatLng> _cachedPolylinePoints = [];
  /// Incremented when starting a new progressive load; stale runs skip updates.
  int _progressiveRunId = 0;
  /// Set when controller is closed; prevents timer/async from touching state and avoids crashes.
  bool _disposed = false;

  static const LatLng _defaultMapCenter = LatLng(11.8745, 75.3704);
  static const double _defaultMapZoom = 13;

  /// Polyline points from location_history (cached; set when history is loaded).
  List<LatLng> get polylinePoints => _cachedPolylinePoints;

  /// Initial map center: center of polyline bounds when 2+ points, else first point or default.
  LatLng get initialMapCenter {
    final points = polylinePoints;
    if (points.length < 2) return points.isNotEmpty ? points.first : _defaultMapCenter;
    double south = points.first.latitude, north = south;
    double west = points.first.longitude, east = west;
    for (final p in points) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    return LatLng((south + north) / 2, (west + east) / 2);
  }

  /// Initial map zoom level (only used before camera fits to polyline).
  double get initialMapZoom => _defaultMapZoom;

  /// Whether to draw the route polyline (need at least 2 points).
  bool get showMapPolyline => polylinePoints.length > 1;

  /// Points to show as markers (start and end when different).
  List<LatLng> get mapMarkerPoints {
    final points = polylinePoints;
    if (points.isEmpty) return [];
    if (points.length == 1) return [points.first];
    if (points.first == points.last) return [points.first];
    return [points.first, points.last];
  }

  // --- Moving marker along polyline (reactive to avoid full GetBuilder rebuilds) ---
  final Rxn<LatLng> movingMarkerPosition = Rxn<LatLng>();
  /// Bearing in degrees (0-360) for rotating the vehicle marker along the route.
  final Rxn<double> movingMarkerBearing = Rxn<double>();
  Timer? _movingMarkerTimer;
  int _movingSegmentIndex = 0;
  double _movingSegmentFraction = 0.0;

  /// Whether the marker is currently animating along the route.
  bool get isMovingMarkerActive => _movingMarkerTimer?.isActive ?? false;

  /// Starts moving the marker along the polyline. No-op if route has < 2 points.
  void startMovingMarker() {
    final points = polylinePoints;
    if (points.length < 2) return;
    stopMovingMarker();
    _movingSegmentIndex = 0;
    _movingSegmentFraction = 0.0;
    movingMarkerPosition.value = points.first;
    movingMarkerBearing.value = points.length > 1
        ? _getBearing(points[0], points[1])
        : 0.0;
    const step = 0.02;
    const period = Duration(milliseconds: 150);
    _movingMarkerTimer = Timer.periodic(period, (_) {
      if (_disposed) return;
      final points = polylinePoints;
      if (points.length < 2) {
        stopMovingMarker();
        return;
      }
      _movingSegmentFraction += step;
      if (_movingSegmentFraction >= 1.0) {
        _movingSegmentIndex++;
        _movingSegmentFraction = 0.0;
        if (_movingSegmentIndex >= points.length - 1) {
          movingMarkerPosition.value = points.last;
          movingMarkerBearing.value = _movingSegmentIndex >= 1
              ? _getBearing(
                  points[_movingSegmentIndex - 1],
                  points[_movingSegmentIndex],
                )
              : movingMarkerBearing.value;
          stopMovingMarker();
          return;
        }
      }
      final a = points[_movingSegmentIndex];
      final b = points[_movingSegmentIndex + 1];
      final t = _movingSegmentFraction.clamp(0.0, 1.0);
      final interpolated = LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      movingMarkerPosition.value = interpolated;
      movingMarkerBearing.value = _getBearing(a, b);
      _ensureMarkerOnPolyline(points);
    });
  }

  /// Stops the marker animation.
  void stopMovingMarker() {
    _movingMarkerTimer?.cancel();
    _movingMarkerTimer = null;
  }

  /// Resets moving marker to start of route (e.g. when route data changes).
  void resetMovingMarker() {
    stopMovingMarker();
    movingMarkerPosition.value = null;
    movingMarkerBearing.value = null;
    _movingSegmentIndex = 0;
    _movingSegmentFraction = 0.0;
    if (!_disposed) update();
  }

  /// Progressive load: process and draw polyline in chunks of this size.
  static const int _progressiveChunkSize = 50;
  /// Simplify Mapbox result per chunk before merging so dense road geometry doesn’t clutter the display.
  static const int _maxDisplayPoints = 350;
  /// Mapbox: smaller chunks (50) for better match quality; max 100 per request.
  static const int _mapboxChunkSize = 50;

  /// Pipeline: drop segments with implied speed below this (km/h).
  static const double _minSpeedKmh = 5.0;
  /// Pipeline: drop consecutive points closer than this (meters).
  static const double _minDistanceMeters = 8.0;
  static const double _minDistanceKm = _minDistanceMeters / 1000.0;

  static const double _coordEpsilon = 1e-6;

  /// Parses deviceTime string (ISO or "yyyy-MM-dd HH:mm:ss") for sorting.
  DateTime _parseDeviceTime(String? s) {
    if (s == null || s.trim().isEmpty) return DateTime(1970);
    final t = DateTime.tryParse(s.trim());
    if (t != null) return t;
    try {
      return DateFormat('yyyy-MM-dd HH:mm:ss').parse(s.trim());
    } catch (_) {
      try {
        return DateFormat('dd MMM yyyy').parse(s.trim());
      } catch (_) {
        return DateTime(1970);
      }
    }
  }

  /// Pipeline: Sort by devicetime → Remove speed < 5 km/h → Remove distance < 8 m → List<LatLng>.
  List<LatLng> _applyPolylinePipeline(List<Map<String, dynamic>> raw) {
    if (raw.isEmpty) {
      debugPrint('[History] Pipeline: raw input empty, returning []');
      return [];
    }
    debugPrint('[History] Pipeline: input raw points = ${raw.length}');
    // 1. Sort by devicetime
    final sorted = List<Map<String, dynamic>>.from(raw)
      ..sort((a, b) {
        final t1 = _parseDeviceTime(a['deviceTime'] as String?);
        final t2 = _parseDeviceTime(b['deviceTime'] as String?);
        return t1.compareTo(t2);
      });
    debugPrint('[History] Pipeline: after sort by devicetime = ${sorted.length}');
    // 2. Remove speed < 5 (keep first; then keep only if implied speed >= 5 km/h from last kept)
    final afterSpeed = <Map<String, dynamic>>[];
    for (final p in sorted) {
      if (afterSpeed.isEmpty) {
        afterSpeed.add(p);
        continue;
      }
      final prev = afterSpeed.last;
      final lat1 = prev['lat'] as double;
      final lng1 = prev['lng'] as double;
      final lat2 = p['lat'] as double;
      final lng2 = p['lng'] as double;
      final dt = _parseDeviceTime(p['deviceTime'] as String?)
          .difference(_parseDeviceTime(prev['deviceTime'] as String?));
      final timeHours = dt.inMilliseconds / (3600 * 1000);
      if (timeHours <= 0) {
        afterSpeed.add(p);
        continue;
      }
      final distKm = _distanceKm(LatLng(lat1, lng1), LatLng(lat2, lng2));
      final speedKmh = distKm / timeHours;
      if (speedKmh >= _minSpeedKmh) afterSpeed.add(p);
    }
    debugPrint('[History] Pipeline: after remove speed < $_minSpeedKmh km/h = ${afterSpeed.length}');
    // 3. Remove distance < 8 m (keep first; then keep only if distance from last kept >= 8 m)
    final afterDist = <Map<String, dynamic>>[];
    for (final p in afterSpeed) {
      if (afterDist.isEmpty) {
        afterDist.add(p);
        continue;
      }
      final prev = afterDist.last;
      final lat1 = prev['lat'] as double;
      final lng1 = prev['lng'] as double;
      final lat2 = p['lat'] as double;
      final lng2 = p['lng'] as double;
      if (_distanceKm(LatLng(lat1, lng1), LatLng(lat2, lng2)) >= _minDistanceKm) {
        afterDist.add(p);
      }
    }
    debugPrint('[History] Pipeline: after remove distance < $_minDistanceMeters m = ${afterDist.length}');
    final result = afterDist.map((m) => LatLng(m['lat'] as double, m['lng'] as double)).toList();
    if (result.isNotEmpty) {
      debugPrint('[History] Pipeline: final cleanList first lat=${result.first.latitude} lng=${result.first.longitude}');
      debugPrint('[History] Pipeline: final cleanList last lat=${result.last.latitude} lng=${result.last.longitude}');
    }
    return result;
  }

  bool _samePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < _coordEpsilon &&
        (a.longitude - b.longitude).abs() < _coordEpsilon;
  }

  /// Snaps path to roads using Mapbox Map Matching API. Returns raw points on failure.
  Future<List<LatLng>> _smoothPathWithMapbox(List<LatLng> rawPoints) async {
    final token = ApiConfig.mapboxAccessToken;
    debugPrint('[History] Mapbox: input rawPoints = ${rawPoints.length}');
    if (token.isEmpty) {
      debugPrint('[History] Mapbox: token empty, returning raw points');
      return rawPoints;
    }
    if (rawPoints.length < 2) {
      debugPrint('[History] Mapbox: rawPoints < 2, returning as-is');
      return rawPoints;
    }
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 25),
      validateStatus: (status) => status != null && status < 500,
    ));
    final snappedPath = <LatLng>[];
    int successChunks = 0;
    int totalChunks = 0;
    try {
      for (int i = 0; i < rawPoints.length; i += _mapboxChunkSize) {
        final end = (i + _mapboxChunkSize > rawPoints.length)
            ? rawPoints.length
            : i + _mapboxChunkSize;
        final chunk = rawPoints.sublist(i, end);
        if (chunk.length < 2) continue;
        totalChunks++;
        final chunkIndex = i ~/ _mapboxChunkSize;
        debugPrint('[History] Mapbox: chunk $chunkIndex request points ${chunk.length} (indices $i–${end - 1})');
        final coords = chunk
            .map((p) => '${p.longitude},${p.latitude}')
            .join(';');
        final radiuses = List.filled(chunk.length, 50).join(';');
        // Coordinates in path as semicolon-separated lng,lat (Mapbox expects unencoded in path).
        final url =
            '$_mapboxMatchBase/$coords.json?geometries=geojson&overview=full&radiuses=$radiuses&tidy=true&access_token=$token';
        final response = await dio.get<Map<String, dynamic>>(url);
        if (response.statusCode != 200 || response.data == null) {
          debugPrint('[History] Mapbox: chunk $chunkIndex HTTP ${response.statusCode}, skipping');
          continue;
        }
        final chunkSmoothed = await compute(
          _processMapboxChunk,
          response.data!,
        );
        if (chunkSmoothed.isEmpty) {
          debugPrint('[History] Mapbox: chunk $chunkIndex parsed 0 points, skipping');
          continue;
        }
        successChunks++;
        debugPrint('[History] Mapbox: chunk $chunkIndex matched ${chunkSmoothed.length} points');
        final chunkLatLng = chunkSmoothed
            .map((p) => LatLng(p[0], p[1]))
            .toList();
        if (snappedPath.isNotEmpty && chunkLatLng.isNotEmpty &&
            _samePoint(snappedPath.last, chunkLatLng.first)) {
          chunkLatLng.removeAt(0);
        }
        snappedPath.addAll(chunkLatLng);
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      if (snappedPath.isEmpty) {
        debugPrint('[History] Mapbox: all chunks failed, returning raw points (${rawPoints.length})');
        return rawPoints;
      }
      if (successChunks < totalChunks) {
        debugPrint('[History] Mapbox: partial ($successChunks/$totalChunks chunks), snapped ${snappedPath.length} points');
      } else {
        debugPrint('[History] Mapbox: all $totalChunks chunks ok, snapped ${snappedPath.length} points');
      }
      return snappedPath;
    } catch (e, st) {
      debugPrint('[History] Mapbox error: $e\n$st');
      return rawPoints;
    }
  }

  double _distanceKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final la1 = a.latitude * math.pi / 180;
    final la2 = b.latitude * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
    return R * c;
  }

  double _distanceMeters(LatLng a, LatLng b) => _distanceKm(a, b) * 1000;

  /// Finds the closest point on the polyline to [currentLocation] (snap-to-route).
  /// Returns map with 'point', 'distance' (m), 'segmentIndex', 't' (0..1 on segment).
  Map<String, dynamic> getClosestPointOnPolyline(
    LatLng currentLocation,
    List<LatLng> polyline,
  ) {
    if (polyline.isEmpty) {
      return {
        'point': currentLocation,
        'distance': double.infinity,
        'segmentIndex': -1,
        't': 0.0,
      };
    }
    if (polyline.length == 1) {
      final dist = _distanceMeters(currentLocation, polyline[0]);
      return {'point': polyline[0], 'distance': dist, 'segmentIndex': 0, 't': 0.0};
    }
    double minDistance = double.infinity;
    LatLng closestPoint = polyline[0];
    int closestSegmentIndex = 0;
    double closestT = 0.0;
    for (int i = 0; i < polyline.length - 1; i++) {
      final p1 = polyline[i];
      final p2 = polyline[i + 1];
      final dx = p2.longitude - p1.longitude;
      final dy = p2.latitude - p1.latitude;
      final segmentLengthSq = dx * dx + dy * dy;
      if (segmentLengthSq < 1e-10) {
        final dist = _distanceMeters(currentLocation, p1);
        if (dist < minDistance) {
          minDistance = dist;
          closestPoint = p1;
          closestSegmentIndex = i;
          closestT = 0.0;
        }
        continue;
      }
      final t = ((currentLocation.longitude - p1.longitude) * dx +
              (currentLocation.latitude - p1.latitude) * dy) /
          segmentLengthSq;
      final clampedT = t.clamp(0.0, 1.0);
      final q = LatLng(
        p1.latitude + clampedT * dy,
        p1.longitude + clampedT * dx,
      );
      final dist = _distanceMeters(currentLocation, q);
      if (dist < minDistance) {
        minDistance = dist;
        closestPoint = q;
        closestSegmentIndex = i;
        closestT = clampedT;
      }
    }
    return {
      'point': closestPoint,
      'distance': minDistance,
      'segmentIndex': closestSegmentIndex,
      't': closestT,
    };
  }

  /// Keeps the moving marker on the polyline (snap if drifted > 5m). Prevents marker off road.
  void _ensureMarkerOnPolyline(List<LatLng> route) {
    if (route.length < 2) return;
    final pos = movingMarkerPosition.value;
    if (pos == null) return;
    final snap = getClosestPointOnPolyline(pos, route);
    final distanceM = snap['distance'] as double;
    if (distanceM > 5.0) {
      movingMarkerPosition.value = snap['point'] as LatLng;
      final seg = snap['segmentIndex'] as int;
      final t = snap['t'] as double;
      if (seg >= 0 && seg < route.length - 1) {
        _movingSegmentIndex = seg;
        _movingSegmentFraction = t;
      }
    }
  }

  /// Keeps polyline under [_maxDisplayPoints] by even sampling (no Douglas–Peucker).
  List<LatLng> _capPolylinePoints(List<LatLng> points) {
    if (points.length <= _maxDisplayPoints) return points;
    if (points.length <= 1) return points;
    final n = points.length;
    final step = (n - 1) / (_maxDisplayPoints - 1);
    return [
      for (int i = 0; i < _maxDisplayPoints; i++)
        points[(i * step).round().clamp(0, n - 1)],
    ];
  }

  /// Loads polyline step-by-step: sends points to Mapbox for snapping.
  void _runProgressiveSnapInBackground(List<LatLng> cleanPoints) {
    if (cleanPoints.length < 2) {
      debugPrint('[History] Progressive: cleanPoints < 2, skipping');
      return;
    }
    final runId = ++_progressiveRunId;
    debugPrint('[History] Progressive: runId=$runId cleanPoints=${cleanPoints.length}');
    Future<void>.delayed(Duration.zero, () async {
      final reducedPoints = cleanPoints;
      debugPrint('[History] Progressive: points to Mapbox = ${reducedPoints.length}');
      int chunkIndex = 0;
      for (int start = 0; start < reducedPoints.length; start += _progressiveChunkSize) {
        if (_disposed || runId != _progressiveRunId) return;
        final end = (start + _progressiveChunkSize > reducedPoints.length)
            ? reducedPoints.length
            : start + _progressiveChunkSize;
        final chunk = reducedPoints.sublist(start, end);
        if (chunk.length < 2) continue;
        debugPrint('[History] Progressive: chunk $chunkIndex start=$start end=$end size=${chunk.length}');
        List<LatLng> snapped = await _smoothPathWithMapbox(chunk);
        if (_disposed || runId != _progressiveRunId) return;
        // Only draw Mapbox-matched geometry; never draw raw points on the map.
        final mapboxOk = !identical(snapped, chunk) && snapped.length >= 2;
        if (!mapboxOk) {
          debugPrint('[History] Progressive: chunk $chunkIndex skipped (Mapbox failed or < 2 points, no raw drawn)');
          chunkIndex++;
          continue;
        }
        debugPrint('[History] Progressive: chunk $chunkIndex using Mapbox snapped ${snapped.length} points');
        if (_disposed || runId != _progressiveRunId) return;
        if (start == 0) {
          _cachedPolylinePoints = _capPolylinePoints(snapped);
          debugPrint('[History] Progressive: chunk 0 drawn (Mapbox only), cached points = ${_cachedPolylinePoints.length}');
        } else {
          if (_cachedPolylinePoints.isNotEmpty &&
              snapped.isNotEmpty &&
              _samePoint(_cachedPolylinePoints.last, snapped.first)) {
            snapped = snapped.sublist(1);
          }
          _cachedPolylinePoints = List<LatLng>.from(_cachedPolylinePoints)
            ..addAll(snapped);
          _cachedPolylinePoints = _capPolylinePoints(_cachedPolylinePoints);
          debugPrint('[History] Progressive: chunk $chunkIndex merged, cached points = ${_cachedPolylinePoints.length}');
        }
        chunkIndex++;
        if (_disposed || runId != _progressiveRunId) return;
        update();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (_disposed || runId != _progressiveRunId) return;
      debugPrint('[History] Progressive: done. Total polyline points on map = ${_cachedPolylinePoints.length}');
      resetMovingMarker();
      if (_disposed) return;
      update();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        if (polylinePoints.length >= 2) startMovingMarker();
      });
    });
  }

  @override
  void onClose() {
    _disposed = true;
    stopMovingMarker();
    super.onClose();
  }

  bool _historyFetchScheduled = false;

  /// Fetches history once per screen load (didChangeDependencies can run multiple times).
  void getHistoryOnce(String imei) {
    if (_historyFetchScheduled || imei.trim().isEmpty) return;
    _historyFetchScheduled = true;
    getHistory(imei);
  }

  Future<void> getHistory(String imei) async {
    if (imei.trim().isEmpty) return;
    isLoading.value = true;
    debugPrint('[History] getHistory: imei=$imei fromDate=${fromDate.value} toDate=${toDate.value}');
    try {
      final token = DioClient().dio.options.headers['Authorization']
          ?.toString();
      final params = <String, dynamic>{
        'baseUrl': ApiConfig.baseUrl,
        'path': ApiEndPoints.vehicleHistory,
        'query': <String, String>{
          'imei': imei.trim(),
          'from_date': fromDate.value == '-:-'
              ? _apiDateFormat.format(DateTime.now())
              : _apiDateFormat.format(_parseDisplayDate(fromDate.value)),
          'to_date': toDate.value == '-:-'
              ? _apiDateFormat.format(DateTime.now())
              : _apiDateFormat.format(_parseDisplayDate(toDate.value)),
        },
        'token': token,
      };
      debugPrint('[History] getHistory: fetching backend ${params['path']} query=${params['query']}');
      final result = await compute(_getHistoryInIsolate, params);
      if (result.containsKey('error')) {
        debugPrint('[History] getHistory: backend error ${result['error']}');
        isLoading.value = false;
        showErrorMessage(Exception(result['error']));
        return;
      }
      final statusCode = result['statusCode'] as int?;
      debugPrint('[History] getHistory: backend statusCode=$statusCode');
      final responseBody = result['data'] as Map<String, dynamic>?;
      if (responseBody != null) {
        debugPrint('[History] getHistory: parsing lat/lng from response');
        final rawPoints = await compute(_buildPolylinePointsInIsolate, responseBody);
        debugPrint('[History] getHistory: rawPoints from isolate = ${rawPoints.length}');
        // Pipeline: Sort by devicetime → Remove speed < 5 → Remove distance < 8 m → Mapbox → Draw
        final cleanList = _applyPolylinePipeline(rawPoints);
        debugPrint('[History] getHistory: pipeline cleanList = ${cleanList.length} points');
        historyModel = HistoryModel.fromJson(responseBody);
        resetMovingMarker();
        if (cleanList.length >= 2) {
          // Do not draw raw points: only draw after Mapbox returns snapped geometry.
          _cachedPolylinePoints = [];
          debugPrint('[History] getHistory: no raw draw; starting Mapbox matching (cleanList=${cleanList.length})');
          final info = historyModel.data?.vehicleInfo;
          if (info != null) {
            currentSpeed.value = '${info.speed ?? 0} Kmph';
          }
          update();
          isLoading.value = false;
          _runProgressiveSnapInBackground(cleanList);
        } else {
          debugPrint('[History] getHistory: cleanList < 2, no polyline');
          _cachedPolylinePoints = [];
          final info = historyModel.data?.vehicleInfo;
          if (info != null) {
            currentSpeed.value = '${info.speed ?? 0} Kmph';
          }
          update();
          isLoading.value = false;
        }
      } else {
        debugPrint('[History] getHistory: responseBody null');
        isLoading.value = false;
      }
    } catch (e, st) {
      debugPrint('[History] getHistory: exception $e\n$st');
      isLoading.value = false;
      showErrorMessage(e);
    }
  }
}
