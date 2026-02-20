import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// A single point from tracking with timestamp for ordering and speed filtering.
class TrackingPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const TrackingPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);
}

/// Earth radius in km for Haversine.
const double _earthRadiusKm = 6371.0;

/// Haversine distance between two points in meters.
double haversineDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a1 = lat1 * math.pi / 180;
  final a2 = lat2 * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(a1) * math.cos(a2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusKm * c * 1000;
}

/// Speed between two points in km/h (distance / time). Returns 0 if time is zero or negative.
double speedKmh(TrackingPoint from, TrackingPoint to) {
  final distKm = haversineDistanceMeters(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      ) /
      1000;
  final hours = to.timestamp.difference(from.timestamp).inMilliseconds / 3600000.0;
  if (hours <= 0) return 0;
  return distKm / hours;
}

/// Perpendicular distance from point to line segment in meters (Haversine approx).
double _distanceToSegmentMeters(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final distAB = haversineDistanceMeters(ax, ay, bx, by);
  if (distAB < 1e-9) return haversineDistanceMeters(px, py, ax, ay);
  final distPA = haversineDistanceMeters(px, py, ax, ay);
  final distPB = haversineDistanceMeters(px, py, bx, by);
  final t = ((bx - ax) * (px - ax) + (by - ay) * (py - ay)) /
      ((bx - ax) * (bx - ax) + (by - ay) * (by - ay));
  if (t <= 0) return distPA;
  if (t >= 1) return distPB;
  final qx = ax + t * (bx - ax);
  final qy = ay + t * (by - ay);
  return haversineDistanceMeters(px, py, qx, qy);
}

/// Douglas–Peucker simplification (iterative). [toleranceMeters] in meters.
List<LatLng> _douglasPeuckerMeters(List<LatLng> points, double toleranceMeters) {
  if (points.length < 3 || toleranceMeters <= 0) return points;
  final keep = List<bool>.filled(points.length, false);
  keep[0] = true;
  keep[points.length - 1] = true;
  final stack = <int>[0, points.length - 1];
  while (stack.length >= 2) {
    final end = stack.removeLast();
    final start = stack.removeLast();
    if (end <= start + 1) continue;
    final a = points[start];
    final b = points[end];
    double maxDist = 0;
    int maxIdx = start;
    for (int i = start + 1; i < end; i++) {
      final p = points[i];
      final d = _distanceToSegmentMeters(
        p.latitude,
        p.longitude,
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
      if (d > maxDist) {
        maxDist = d;
        maxIdx = i;
      }
    }
    if (maxDist >= toleranceMeters) {
      keep[maxIdx] = true;
      stack.add(start);
      stack.add(maxIdx);
      stack.add(maxIdx);
      stack.add(end);
    }
  }
  return [for (int i = 0; i < points.length; i++) if (keep[i]) points[i]];
}

/// Cleans raw tracking points for smooth polyline rendering.
///
/// 1. Sorts by timestamp.
/// 2. Removes duplicate or very close points (< [minDistMeters]).
/// 3. Removes unrealistic GPS jumps (speed > [maxSpeedKmh]).
/// 4. Optionally simplifies with Douglas–Peucker ([simplifyToleranceMeters], 5–8 recommended).
///
/// Returns a cleaned [List<LatLng>] ready for Polyline / LineLayer. Does not remove valid tracking data.
List<LatLng> cleanPolyline(
  List<TrackingPoint> rawPoints, {
  double minDistMeters = 5,
  double maxSpeedKmh = 200,
  double? simplifyToleranceMeters,
}) {
  if (rawPoints.isEmpty) return [];
  if (rawPoints.length == 1) return [rawPoints.first.toLatLng()];

  final sorted = List<TrackingPoint>.from(rawPoints)
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final filtered = <TrackingPoint>[sorted.first];
  for (int i = 1; i < sorted.length; i++) {
    final p = sorted[i];
    final last = filtered.last;
    final distM = haversineDistanceMeters(
      last.latitude,
      last.longitude,
      p.latitude,
      p.longitude,
    );
    if (distM < minDistMeters) continue;
    filtered.add(p);
  }

  final speedFiltered = <TrackingPoint>[filtered.first];
  for (int i = 1; i < filtered.length; i++) {
    final p = filtered[i];
    final last = speedFiltered.last;
    final speed = speedKmh(last, p);
    if (speed > maxSpeedKmh) continue;
    speedFiltered.add(p);
  }

  List<LatLng> result =
      speedFiltered.map((p) => p.toLatLng()).toList();

  if (simplifyToleranceMeters != null &&
      simplifyToleranceMeters > 0 &&
      result.length >= 3) {
    result = _douglasPeuckerMeters(result, simplifyToleranceMeters);
  }

  return result;
}
