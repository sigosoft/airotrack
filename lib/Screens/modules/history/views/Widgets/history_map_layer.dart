import 'package:airotrack/Utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;


class HistoryMapLayer extends StatefulWidget {
  const HistoryMapLayer({
    Key? key,
    required this.initialCenter,
    required this.initialZoom,
    required this.polylinePoints,
    required this.markerPoints,
    this.movingMarkerPosition,
    this.movingMarkerBearing,
    this.movingMarkerAssetPath = 'lib/Asset/Images/marker2.png',
  }) : super(key: key);

  final ll.LatLng initialCenter;
  final double initialZoom;
  final List<ll.LatLng> polylinePoints;
  final List<ll.LatLng> markerPoints;
  final ll.LatLng? movingMarkerPosition;
  final double? movingMarkerBearing;
  final String movingMarkerAssetPath;

  @override
  State<HistoryMapLayer> createState() => _HistoryMapLayerState();
}

class _HistoryMapLayerState extends State<HistoryMapLayer> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _movingMarkerIcon;
  static const int _fitPadding = 48;
  /// Throttle camera fit to avoid BLASTBufferQueue overflow (max once per 2s).
  DateTime? _lastFitTime;
  static const Duration _fitThrottle = Duration(seconds: 2);

  static LatLng _toGoogle(ll.LatLng l) => LatLng(l.latitude, l.longitude);

  @override
  void initState() {
    super.initState();
    _loadMovingMarkerIcon();
  }

  Future<void> _loadMovingMarkerIcon() async {
    final icon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(devicePixelRatio: 2.5),
      widget.movingMarkerAssetPath,
    );
    if (mounted) setState(() => _movingMarkerIcon = icon);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (widget.polylinePoints.length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapController != null) _fitToPolyline();
      });
    }
  }

  @override
  void didUpdateWidget(HistoryMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.polylinePoints.length >= 2 && _mapController != null) {
      final pointsChanged = widget.polylinePoints != oldWidget.polylinePoints ||
          widget.polylinePoints.length != oldWidget.polylinePoints.length;
      if (!pointsChanged) return;
      final now = DateTime.now();
      final isFirstFit = _lastFitTime == null;
      final throttlePassed = _lastFitTime == null ||
          now.difference(_lastFitTime!).compareTo(_fitThrottle) > 0;
      if (isFirstFit || throttlePassed) {
        _lastFitTime = now;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _mapController != null) _fitToPolyline();
        });
      }
    }
  }

  void _fitToPolyline() {
    final points = widget.polylinePoints;
    if (points.length < 2 || _mapController == null) return;
    _lastFitTime = DateTime.now();
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;
    for (final p in points) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, _fitPadding.toDouble()),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _toGoogle(widget.initialCenter);
    final List<LatLng> polylinePointsGoogle = widget.polylinePoints.map(_toGoogle).toList();
    final hasPolyline = polylinePointsGoogle.length >= 2;

    final polylines = <Polyline>{};
    if (hasPolyline) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: polylinePointsGoogle,
          color: AppColors.primaryBlue,
          width: 4,
        ),
      );
    }

    final markers = <Marker>{};
    for (var i = 0; i < widget.markerPoints.length; i++) {
      markers.add(
        Marker(
          markerId: MarkerId('point_$i'),
          position: _toGoogle(widget.markerPoints[i]),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    if (widget.movingMarkerPosition != null) {
      final pos = _toGoogle(widget.movingMarkerPosition!);
      markers.add(
        Marker(
          markerId: const MarkerId('moving_vehicle'),
          position: pos,
          rotation: widget.movingMarkerBearing ?? 0.0,
          icon: _movingMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialTarget,
        zoom: widget.initialZoom,
      ),
      polylines: polylines,
      markers: markers,
      onMapCreated: _onMapCreated,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }
}
