import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapWidget extends StatelessWidget {
  final LatLng? initialCenter;
  final double initialZoom;
  final MapController? mapController;
  final dynamic markers;
  final dynamic polylines;
  final VoidCallback? onTap;

  const MapWidget({
    Key? key,
    this.initialCenter,
    this.initialZoom = 13.0,
    this.mapController,
    this.markers,
    this.polylines,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter ?? const LatLng(11.8745, 75.3704),
        initialZoom: initialZoom,
        onTap: (tapPosition, point) => onTap?.call(),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.airotrack.app',
        ),
        // Reactively render polylines
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
        // Reactively render markers
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
