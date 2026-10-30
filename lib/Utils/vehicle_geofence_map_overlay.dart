import 'dart:math' as math;

import 'package:airotrack/Utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Builds map circles/polygons from `GET vehicle_geofences` response.
class VehicleGeofenceMapOverlay {
  VehicleGeofenceMapOverlay._();

  static const _fillAlpha = 0.22;
  static const _borderAlpha = 0.85;

  static Color get _fill =>
      AppColors.primaryBlue.withValues(alpha: _fillAlpha);
  static Color get _border =>
      AppColors.primaryBlue.withValues(alpha: _borderAlpha);

  static void parseApiResponse(
    dynamic raw, {
    required List<Circle> circles,
    required List<Polygon> polygons,
  }) {
    circles.clear();
    polygons.clear();

    if (raw is! Map) return;
    final data = raw['data'];
    if (data is! Map) return;

    final list = data['geofences'];
    if (list is! List) return;

    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map) continue;
      _addOverlay(item, i, circles: circles, polygons: polygons);
    }
  }

  static void _addOverlay(
    Map item,
    int index, {
    required List<Circle> circles,
    required List<Polygon> polygons,
  }) {
    final type = item['type']?.toString().toLowerCase() ?? 'circle';
    final id = 'geofence_${item['id'] ?? index}_$index';

    if (type == 'circle') {
      final lat = double.tryParse(item['latitude']?.toString() ?? '');
      final lng = double.tryParse(item['longitude']?.toString() ?? '');
      final radiusKm = double.tryParse(item['radius']?.toString() ?? '');
      if (lat == null || lng == null || radiusKm == null || radiusKm <= 0) {
        return;
      }
      circles.add(
        Circle(
          circleId: CircleId(id),
          center: LatLng(lat, lng),
          radius: radiusKm * 1000,
          fillColor: _fill,
          strokeWidth: 2,
          strokeColor: _border,
        ),
      );
      return;
    }

    var points = _parseCoordinates(item['coordinates']);
    if (points.isEmpty) return;

    if (type == 'rectangle' && points.length == 2) {
      points = _rectangleFromOppositeCorners(points[0], points[1]);
    }

    if (points.length < 3) return;

    polygons.add(
      Polygon(
        polygonId: PolygonId(id),
        points: points,
        fillColor: _fill,
        strokeWidth: 2,
        strokeColor: _border,
      ),
    );
  }

  static List<LatLng> _parseCoordinates(dynamic raw) {
    if (raw is! List) return [];
    final points = <LatLng>[];
    for (final c in raw) {
      if (c is! Map) continue;
      final lat = double.tryParse(c['lat']?.toString() ?? '');
      final lng = double.tryParse(c['lng']?.toString() ?? '');
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }
    return points;
  }

  static List<LatLng> _rectangleFromOppositeCorners(LatLng a, LatLng b) {
    final minLat = math.min(a.latitude, b.latitude);
    final maxLat = math.max(a.latitude, b.latitude);
    final minLng = math.min(a.longitude, b.longitude);
    final maxLng = math.max(a.longitude, b.longitude);
    return [
      LatLng(minLat, minLng),
      LatLng(minLat, maxLng),
      LatLng(maxLat, maxLng),
      LatLng(maxLat, minLng),
    ];
  }
}
