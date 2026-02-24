import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapWidget extends StatelessWidget {
  final LatLng? initialCenter;
  final double initialZoom;
  final MapController? mapController;
  final List<Marker>? markers;
  final VoidCallback? onTap;

  const MapWidget({
    Key? key,
    this.initialCenter,
    this.initialZoom = 13.0,
    this.mapController,
    this.markers,
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
        if (markers != null && markers!.isNotEmpty)
          MarkerLayer(markers: markers!),
      ],
    );
  }
}
