import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../Configs/ApiConfigs.dart';

class DirectionsService {
  final Dio _dio = Dio();
  final String _accessToken = ApiConfig.mapboxAccessToken;

  /// Fetches a route between two points using Mapbox Directions API.
  /// Returns Catmull-Rom smoothed road-snapped LatLng points.
  /// Falls back to a straight line [origin, destination] on any failure.
  Future<List<LatLng>> getRoute(LatLng origin, LatLng destination) async {
    final String url =
        'https://api.mapbox.com/directions/v5/mapbox/driving'
        '/${origin.longitude},${origin.latitude}'
        ';${destination.longitude},${destination.latitude}'
        '?geometries=polyline&access_token=$_accessToken';

    try {
      final response = await _dio.get<Map<String, dynamic>>(url);
      if (response.statusCode == 200 && response.data != null) {
        final List routes = response.data!['routes'] as List? ?? [];
        if (routes.isNotEmpty) {
          final String geometry = routes[0]['geometry'] as String;
          // flutter_polyline_points v3 exposes decodePolyline as a static method
          final List<PointLatLng> points =
              PolylinePoints.decodePolyline(geometry);
          final List<LatLng> latLngPoints =
              points.map((p) => LatLng(p.latitude, p.longitude)).toList();
          return _smoothPolyline(latLngPoints);
        }
      }
    } catch (e) {
      debugPrint('DirectionsService: Error fetching route: $e');
    }
    // Fallback: straight line so the vehicle still shows approximate path
    return [origin, destination];
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
