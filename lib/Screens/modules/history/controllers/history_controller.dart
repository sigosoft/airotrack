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

/// Top-level for isolate: build polyline points from response (sendable types only).
List<List<double>> _buildPolylinePointsInIsolate(Map<String, dynamic>? responseBody) {
  if (responseBody == null) return [];
  final model = HistoryModel.fromJson(responseBody);
  final list = model.data?.locationHistory ?? [];
  final points = <List<double>>[];
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
      points.add([lat, lng]);
    }
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

  /// Initial map center: first point of route or default.
  LatLng get initialMapCenter =>
      polylinePoints.isNotEmpty ? polylinePoints.first : _defaultMapCenter;

  /// Initial map zoom level.
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
  /// Remove duplicate points: keep only if consecutive points are at least this far apart (~5m).
  static const double _redundantPointMinDistKm = 0.005; // 5m
  /// Douglas–Peucker tolerance (km) before Mapbox: simplify each chunk with this (5–8m) before sending.
  static const double _simplifyBeforeMapboxToleranceKm = 0.006; // ~6m (5–8m range)
  /// Simplify Mapbox result per chunk before merging so dense road geometry doesn’t clutter the display.
  static const double _simplifyChunkAfterMapboxKm = 0.01; // ~10m
  /// Douglas–Peucker tolerance (km) for display: keeps polyline smooth as more chunks load.
  static const double _simplifyToleranceKm = 0.018; // ~18m
  /// Max points before using lighter corner smoothing (1 iteration) to avoid clutter.
  static const int _smoothCornersMaxPoints = 250;
  /// Mapbox: smaller chunks (50) for better match quality; max 100 per request.
  static const int _mapboxChunkSize = 50;

  static const double _coordEpsilon = 1e-6;

  bool _samePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < _coordEpsilon &&
        (a.longitude - b.longitude).abs() < _coordEpsilon;
  }

  /// Rounds sharp turns into smooth curves using Chaikin's corner-cutting algorithm.
  /// Uses 1 iteration when path is long to avoid clutter.
  List<LatLng> _smoothPolylineCorners(List<LatLng> points, {int? iterations}) {
    if (points.length < 3) return points;
    final iter = iterations ?? (points.length > _smoothCornersMaxPoints ? 1 : 2);
    List<LatLng> current = List.from(points);
    for (int i = 0; i < iter; i++) {
      final next = <LatLng>[current.first];
      for (int i = 0; i < current.length - 1; i++) {
        final p0 = current[i];
        final p1 = current[i + 1];
        next.add(LatLng(
          p0.latitude * 0.25 + p1.latitude * 0.75,
          p0.longitude * 0.25 + p1.longitude * 0.75,
        ));
        next.add(LatLng(
          p0.latitude * 0.75 + p1.latitude * 0.25,
          p0.longitude * 0.75 + p1.longitude * 0.25,
        ));
      }
      next.add(current.last);
      current = next;
    }
    return current;
  }

  /// Snaps path to roads using Mapbox Map Matching API. Returns raw points on failure.
  Future<List<LatLng>> _smoothPathWithMapbox(List<LatLng> rawPoints) async {
    final token = ApiConfig.mapboxAccessToken;
    if (token.isEmpty || rawPoints.length < 2) return rawPoints;
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
        final coords = chunk
            .map((p) => '${p.longitude},${p.latitude}')
            .join(';');
        final radiuses = List.filled(chunk.length, 50).join(';');
        // Coordinates in path as semicolon-separated lng,lat (Mapbox expects unencoded in path).
        final url =
            '$_mapboxMatchBase/$coords.json?geometries=geojson&overview=full&radiuses=$radiuses&tidy=true&access_token=$token';
        final response = await dio.get<Map<String, dynamic>>(url);
        if (response.statusCode != 200 || response.data == null) {
          if (response.data != null) {
            debugPrint('Mapbox chunk ${i ~/ _mapboxChunkSize}: ${response.statusCode}');
          }
          continue;
        }
        final chunkSmoothed = await compute(
          _processMapboxChunk,
          response.data!,
        );
        if (chunkSmoothed.isEmpty) continue;
        successChunks++;
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
      if (snappedPath.isEmpty) return rawPoints;
      if (successChunks < totalChunks) {
        debugPrint('Mapbox: partial ($successChunks/$totalChunks chunks), ${snappedPath.length} points');
      } else {
        debugPrint('Mapbox: snapped ${snappedPath.length} points');
      }
      return snappedPath;
    } catch (e, st) {
      debugPrint('Mapbox smooth error: $e\n$st');
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

  /// Removes consecutive points that are too close (redundant lats/longs) for quality.
  List<LatLng> _removeRedundantPoints(List<LatLng> points) {
    if (points.length < 3) return points;
    final out = <LatLng>[points.first];
    for (int i = 1; i < points.length; i++) {
      if (_distanceKm(out.last, points[i]) >= _redundantPointMinDistKm) {
        out.add(points[i]);
      }
    }
    return out;
  }

  /// Perpendicular distance (km) from point [p] to line segment [a]–[b].
  double _distanceToSegmentKm(LatLng p, LatLng a, LatLng b) {
    final dLab = _distanceKm(a, b);
    if (dLab < 1e-9) return _distanceKm(p, a);
    final dPa = _distanceKm(p, a);
    final dPb = _distanceKm(p, b);
    final t = ((b.latitude - a.latitude) * (p.latitude - a.latitude) +
            (b.longitude - a.longitude) * (p.longitude - a.longitude)) /
        ((b.latitude - a.latitude) * (b.latitude - a.latitude) +
            (b.longitude - a.longitude) * (b.longitude - a.longitude));
    if (t <= 0) return dPa;
    if (t >= 1) return dPb;
    final q = LatLng(
      a.latitude + t * (b.latitude - a.latitude),
      a.longitude + t * (b.longitude - a.longitude),
    );
    return _distanceKm(p, q);
  }

  /// Douglas–Peucker simplification (iterative to avoid stack overflow on long polylines).
  List<LatLng> _simplifyPolyline(List<LatLng> points, double toleranceKm) {
    if (points.length < 3 || toleranceKm <= 0) return points;
    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;
    final stack = <int>[0, points.length - 1];
    while (stack.length >= 2) {
      final end = stack.removeLast();
      final start = stack.removeLast();
      if (end <= start + 1) continue;
      double maxDist = 0;
      int maxIdx = start;
      final a = points[start];
      final b = points[end];
      for (int i = start + 1; i < end; i++) {
        final d = _distanceToSegmentKm(points[i], a, b);
        if (d > maxDist) {
          maxDist = d;
          maxIdx = i;
        }
      }
      if (maxDist >= toleranceKm) {
        keep[maxIdx] = true;
        stack.add(start);
        stack.add(maxIdx);
        stack.add(maxIdx);
        stack.add(end);
      }
    }
    return [
      for (int i = 0; i < points.length; i++)
        if (keep[i]) points[i],
    ];
  }

  /// Loads polyline step-by-step: only Douglas–Peucker reduced points are sent to Mapbox for snapping.
  void _runProgressiveSnapInBackground(List<LatLng> cleanPoints) {
    if (cleanPoints.length < 2) return;
    final runId = ++_progressiveRunId;
    Future<void>.delayed(Duration.zero, () async {
      final reducedPoints = cleanPoints.length >= 3
          ? _simplifyPolyline(cleanPoints, _simplifyBeforeMapboxToleranceKm)
          : cleanPoints;
      for (int start = 0; start < reducedPoints.length; start += _progressiveChunkSize) {
        if (_disposed || runId != _progressiveRunId) return;
        final end = (start + _progressiveChunkSize > reducedPoints.length)
            ? reducedPoints.length
            : start + _progressiveChunkSize;
        final chunk = reducedPoints.sublist(start, end);
        if (chunk.length < 2) continue;
        List<LatLng> snapped = await _smoothPathWithMapbox(chunk);
        if (_disposed || runId != _progressiveRunId) return;
        if (identical(snapped, chunk) || snapped.length < 2) {
          snapped = List<LatLng>.from(chunk);
        }
        if (snapped.length >= 3) {
          snapped = _simplifyPolyline(snapped, _simplifyChunkAfterMapboxKm);
        }
        if (_disposed || runId != _progressiveRunId) return;
        if (start == 0) {
          _cachedPolylinePoints = _smoothPolylineCorners(snapped);
          _cachedPolylinePoints = _simplifyPolyline(_cachedPolylinePoints, _simplifyToleranceKm);
        } else {
          if (_cachedPolylinePoints.isNotEmpty &&
              snapped.isNotEmpty &&
              _samePoint(_cachedPolylinePoints.last, snapped.first)) {
            snapped = snapped.sublist(1);
          }
          _cachedPolylinePoints = List<LatLng>.from(_cachedPolylinePoints)
            ..addAll(snapped);
          _cachedPolylinePoints = _smoothPolylineCorners(_cachedPolylinePoints);
          _cachedPolylinePoints = _simplifyPolyline(_cachedPolylinePoints, _simplifyToleranceKm);
        }
        if (_disposed || runId != _progressiveRunId) return;
        update();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (_disposed || runId != _progressiveRunId) return;
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
    debugPrint("fromDate: ${fromDate.value}");
    debugPrint("toDate: ${toDate.value}");
    debugPrint("imei: $imei");
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
      debugPrint("params: ${params.toString()}");
      final result = await compute(_getHistoryInIsolate, params);
      if (result.containsKey('error')) {
        isLoading.value = false;
        showErrorMessage(Exception(result['error']));
        return;
      }
      final responseBody = result['data'] as Map<String, dynamic>?;
      if (responseBody != null) {
        final rawPoints = await compute(_buildPolylinePointsInIsolate, responseBody);
        List<LatLng> rawList = rawPoints.map((p) => LatLng(p[0], p[1])).toList();
        historyModel = HistoryModel.fromJson(responseBody);
        resetMovingMarker();
        if (rawList.length >= 2) {
          final cleanList = _removeRedundantPoints(rawList);
          final firstChunkEnd = cleanList.length < _progressiveChunkSize
              ? cleanList.length
              : _progressiveChunkSize;
          _cachedPolylinePoints = List<LatLng>.from(cleanList.sublist(0, firstChunkEnd));
          if (_cachedPolylinePoints.length >= 3) {
            _cachedPolylinePoints = _simplifyPolyline(_cachedPolylinePoints, _simplifyToleranceKm);
          }
          final info = historyModel.data?.vehicleInfo;
          if (info != null) {
            currentSpeed.value = '${info.speed ?? 0} Kmph';
          }
          update();
          isLoading.value = false;
          _runProgressiveSnapInBackground(cleanList);
        } else {
          _cachedPolylinePoints = rawList.length >= 3
              ? _smoothPolylineCorners(rawList)
              : rawList;
          final info = historyModel.data?.vehicleInfo;
          if (info != null) {
            currentSpeed.value = '${info.speed ?? 0} Kmph';
          }
          update();
          isLoading.value = false;
        }
      } else {
        isLoading.value = false;
      }
    } catch (e) {
      isLoading.value = false;
      showErrorMessage(e);
    }
  }
}
