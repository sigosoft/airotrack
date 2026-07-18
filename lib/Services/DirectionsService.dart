import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../Configs/ApiConfigs.dart';

class DirectionsService {
  final Dio _dio = Dio();
  final String _accessToken = ApiConfig.mapboxAccessToken;

  /// Fetches a route between two points using Mapbox Directions API.
  /// Returns road-snapped LatLng points (optionally Catmull-Rom smoothed).
  /// Falls back to a straight line [origin, destination] on any failure.
  Future<List<LatLng>> getRoute(
    LatLng origin,
    LatLng destination, {
    bool smooth = true,
  }) async {
    final String url =
        'https://api.mapbox.com/directions/v5/mapbox/driving'
        '/${origin.longitude},${origin.latitude}'
        ';${destination.longitude},${destination.latitude}'
        '?geometries=polyline&overview=full&access_token=$_accessToken';

    try {
      final response = await _dio.get<Map<String, dynamic>>(url);
      if (response.statusCode == 200 && response.data != null) {
        final List routes = response.data!['routes'] as List? ?? [];
        if (routes.isNotEmpty) {
          final String geometry = routes[0]['geometry'] as String;
          final List<PointLatLng> points =
              PolylinePoints.decodePolyline(geometry);
          final List<LatLng> latLngPoints =
              points.map((p) => LatLng(p.latitude, p.longitude)).toList();
          return smooth ? _smoothPolyline(latLngPoints) : latLngPoints;
        }
      }
    } catch (e) {
      debugPrint('DirectionsService: Error fetching route: $e');
    }
    return [origin, destination];
  }

  /// Snaps a GPS trace onto the road network (Map Matching).
  /// Prefer this for live tracking — Directions can cut corners / wrong roads.
  /// [radiusMeters] = how far each GPS sample may be from a road.
  Future<List<LatLng>> matchTrace(
    List<LatLng> points, {
    double radiusMeters = 25,
  }) async {
    if (points.length < 2) return List<LatLng>.from(points);

    // Map Matching needs distinct coords; drop near-duplicates.
    final cleaned = <LatLng>[points.first];
    for (var i = 1; i < points.length; i++) {
      if (_approxDistanceM(cleaned.last, points[i]) >= 2.0) {
        cleaned.add(points[i]);
      }
    }
    if (cleaned.length < 2) return List<LatLng>.from(points);

    // API max 100 coords; live track only sends a few.
    final input =
        cleaned.length > 100 ? cleaned.sublist(cleaned.length - 100) : cleaned;

    final coords = input
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    final radiuses = List.filled(input.length, radiusMeters.round()).join(';');
    final url =
        'https://api.mapbox.com/matching/v5/mapbox/driving/$coords.json'
        '?geometries=geojson&overview=full&radiuses=$radiuses'
        '&tidy=true&access_token=$_accessToken';

    try {
      final response = await _dio.get<Map<String, dynamic>>(url);
      if (response.statusCode != 200 || response.data == null) {
        return _fallbackDirections(input.first, input.last);
      }

      final data = response.data!;
      if (data['code']?.toString() != 'Ok') {
        debugPrint('DirectionsService matchTrace: code=${data['code']}');
        return _fallbackDirections(input.first, input.last);
      }

      final matchings = data['matchings'];
      if (matchings is! List || matchings.isEmpty) {
        return _fallbackDirections(input.first, input.last);
      }

      final snapped = <LatLng>[];
      for (final m in matchings) {
        if (m is! Map) continue;
        final geometry = m['geometry'];
        if (geometry is! Map) continue;
        final coordinates = geometry['coordinates'];
        if (coordinates is! List) continue;
        for (final c in coordinates) {
          if (c is List && c.length >= 2) {
            final lng = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            if (snapped.isEmpty ||
                _approxDistanceM(snapped.last, LatLng(lat, lng)) >= 0.8) {
              snapped.add(LatLng(lat, lng));
            }
          }
        }
      }

      if (snapped.length < 2) {
        return _fallbackDirections(input.first, input.last);
      }
      return _densify(snapped, maxSegmentM: 4.0);
    } catch (e) {
      debugPrint('DirectionsService matchTrace error: $e');
      return _fallbackDirections(input.first, input.last);
    }
  }

  Future<List<LatLng>> _fallbackDirections(LatLng from, LatLng to) {
    return getRoute(from, to, smooth: false);
  }

  /// Insert points so the marker never jumps long chords that look off-road.
  List<LatLng> _densify(List<LatLng> points, {required double maxSegmentM}) {
    if (points.length < 2) return points;
    final out = <LatLng>[points.first];
    for (var i = 1; i < points.length; i++) {
      final a = out.last;
      final b = points[i];
      final dist = _approxDistanceM(a, b);
      if (dist <= maxSegmentM) {
        out.add(b);
        continue;
      }
      final steps = (dist / maxSegmentM).ceil();
      for (var s = 1; s <= steps; s++) {
        final t = s / steps;
        out.add(LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
      }
    }
    return out;
  }

  double _approxDistanceM(LatLng a, LatLng b) {
    const metersPerLat = 111320.0;
    final dLat = (a.latitude - b.latitude) * metersPerLat;
    final midLat = (a.latitude + b.latitude) * 0.5 * 3.141592653589793 / 180;
    final metersPerLng = 111320.0 * (midLat == 0 ? 1.0 : _cos(midLat));
    final dLng = (a.longitude - b.longitude) * metersPerLng;
    return (dLat * dLat + dLng * dLng) > 0
        ? _sqrt(dLat * dLat + dLng * dLng)
        : 0.0;
  }

  double _cos(double rad) {
    // Avoid importing dart:math just for one call in this small helper path.
    // Use enough terms for distance mid-latitude cosine.
    final x = rad;
    final x2 = x * x;
    return 1 - x2 / 2 + x2 * x2 / 24;
  }

  double _sqrt(double v) {
    if (v <= 0) return 0;
    var x = v;
    for (var i = 0; i < 8; i++) {
      x = 0.5 * (x + v / x);
    }
    return x;
  }

  /// Catmull-Rom spline interpolation to smooth sharp corners in the polyline.
  List<LatLng> _smoothPolyline(List<LatLng> points) {
    if (points.length < 4) return points;

    final List<LatLng> smoothed = [];
    for (int i = 0; i < points.length - 1; i++) {
      final LatLng p0 = points[i == 0 ? i : i - 1];
      final LatLng p1 = points[i];
      final LatLng p2 = points[i + 1];
      final LatLng p3 = points[i + 2 >= points.length ? i + 1 : i + 2];

      for (double t = 0; t < 1; t += 0.2) {
        smoothed.add(_catmullRom(p0, p1, p2, p3, t));
      }
    }
    smoothed.add(points.last);
    return smoothed;
  }

  LatLng _catmullRom(LatLng p0, LatLng p1, LatLng p2, LatLng p3, double t) {
    final double t2 = t * t;
    final double t3 = t2 * t;

    final double f1 = -0.5 * t3 + t2 - 0.5 * t;
    final double f2 = 1.5 * t3 - 2.5 * t2 + 1.0;
    final double f3 = -1.5 * t3 + 2.0 * t2 + 0.5 * t;
    final double f4 = 0.5 * t3 - 0.5 * t2;

    return LatLng(
      p0.latitude * f1 + p1.latitude * f2 + p2.latitude * f3 + p3.latitude * f4,
      p0.longitude * f1 + p1.longitude * f2 + p2.longitude * f3 + p3.longitude * f4,
    );
  }
}
