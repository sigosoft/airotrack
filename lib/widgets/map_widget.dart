import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../Configs/ApiConfigs.dart';

enum AiroMapStyle {
  osm,
  mapboxStreets,
  /// Satellite + road labels (top-down hybrid, matches live-track screenshot).
  mapboxSatellite,
  /// Terrain / outdoors (contours and hill shading).
  mapboxOutdoors,
}

class AiroMapWidget extends StatelessWidget {
  final LatLng? initialCenter;
  final double initialZoom;
  final MapController? mapController;
  final dynamic markers;
  final dynamic polylines;
  final dynamic circles;
  final dynamic polygons;
  final VoidCallback? onTap;
  final void Function(MapEvent)? onMapEvent;
  final void Function(MapCamera, bool)? onPositionChanged;
  /// Called once the map is laid out and [mapController] can move it.
  final VoidCallback? onMapReady;
  final AiroMapStyle mapStyle;
  /// Keep map north-up (no rotate / perspective). Always a top-down view.
  final bool lockNorthUp;
  /// Live traffic: shows Mapbox's street map with traffic colours on the
  /// roads (green / orange / red) in place of [mapStyle].
  final bool traffic;

  AiroMapWidget({
    Key? key,
    this.onPositionChanged,
    this.onMapReady,
    this.onMapEvent,
    this.initialCenter,
    this.initialZoom = 13.0,
    this.mapController,
    this.markers,
    this.polylines,
    this.circles,
    this.polygons,
    this.onTap,
    this.mapStyle = AiroMapStyle.osm,
    this.lockNorthUp = true,
    this.traffic = false,
  }) : super(key: key);

  String _tileUrl() {
    final token = ApiConfig.mapboxAccessToken.trim();
    final tokenOk = token.isNotEmpty &&
        !token.contains('<') &&
        !token.contains('>') &&
        !token.toLowerCase().contains('your_mapbox_access_token');

    if (!tokenOk || mapStyle == AiroMapStyle.osm) {
      return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }

    final styleId = traffic ? 'traffic-day-v2' : switch (mapStyle) {
      AiroMapStyle.mapboxSatellite => 'satellite-streets-v12',
      AiroMapStyle.mapboxOutdoors => 'outdoors-v12',
      _ => 'streets-v12',
    };
    return 'https://api.mapbox.com/styles/v1/mapbox/$styleId'
        '/tiles/256/{z}/{x}/{y}@2x?access_token=$token';
  }

  @override
  Widget build(BuildContext context) {
    final interactionFlags = lockNorthUp
        ? (InteractiveFlag.all & ~InteractiveFlag.rotate)
        : InteractiveFlag.all;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter ?? const LatLng(11.8745, 75.3704),
        initialZoom: initialZoom,
        initialRotation: 0,
        // Without a limit, pinch / double-tap zoomed past the deepest map
        // tiles and the whole map turned grey.
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: InteractionOptions(flags: interactionFlags),
        onTap: (tapPosition, point) => onTap?.call(),
        onMapEvent: onMapEvent,
        onPositionChanged: onPositionChanged,
        onMapReady: onMapReady,
      ),
      children: [
        TileLayer(
          key: ValueKey('$mapStyle|$traffic'),
          urlTemplate: _tileUrl(),
          userAgentPackageName: 'com.airotrack.app',
          maxZoom: 22,
        ),
        Builder(
          builder: (context) {
            final pg = polygons;
            if (pg is RxList<Polygon>) {
              return Obx(() {
                if (pg.isEmpty) return const SizedBox.shrink();
                return PolygonLayer(polygons: pg.toList());
              });
            } else if (pg is List<Polygon> && pg.isNotEmpty) {
              return PolygonLayer(polygons: pg);
            }
            return const SizedBox.shrink();
          },
        ),
        Builder(
          builder: (context) {
            final c = circles;
            if (c is RxList<CircleMarker>) {
              return Obx(() {
                if (c.isEmpty) return const SizedBox.shrink();
                return CircleLayer(circles: c.toList());
              });
            } else if (c is List<CircleMarker> && c.isNotEmpty) {
              return CircleLayer(circles: c);
            }
            return const SizedBox.shrink();
          },
        ),
        Builder(
          builder: (context) {
            final p = polylines;
            if (p is RxList<Polyline>) {
              return Obx(() {
                if (p.length >= 0) {
                  return PolylineLayer(polylines: p.toList());
                }
                return const SizedBox.shrink();
              });
            } else if (p is List<Polyline>) {
              return PolylineLayer(polylines: p);
            }
            return const SizedBox.shrink();
          },
        ),
        Builder(
          builder: (context) {
            final m = markers;
            if (m is RxList<Marker>) {
              return Obx(() {
                if (m.length >= 0) {
                  return MarkerLayer(markers: m.toList());
                }
                return const SizedBox.shrink();
              });
            } else if (m is List<Marker>) {
              return MarkerLayer(markers: m);
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
