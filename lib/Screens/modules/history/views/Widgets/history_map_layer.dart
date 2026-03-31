import 'dart:math' as math;

import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
    this.isFollowCameraEnabled = true,
    this.isPlaybackActive = false,
    this.onManualFollowDisable,
    this.movingMarkerAssetPath = 'lib/Asset/Images/marker2.png',
  }) : super(key: key);

  final ll.LatLng initialCenter;
  final double initialZoom;
  final List<ll.LatLng> polylinePoints;
  final List<ll.LatLng> markerPoints;
  final ll.LatLng? movingMarkerPosition;
  final double? movingMarkerBearing;
  final bool isFollowCameraEnabled;
  final bool isPlaybackActive;
  final VoidCallback? onManualFollowDisable;
  final String movingMarkerAssetPath;

  @override
  State<HistoryMapLayer> createState() => _HistoryMapLayerState();
}

class _HistoryMapLayerState extends State<HistoryMapLayer> {
  final MapController _mapController = MapController();
  static const double _fitPadding = 48.0;
  static const double _followVerticalOffsetFraction = 0.22;
  bool _hasAutoFittedCurrentRoute = false;
  static const Duration _followThrottle = Duration(milliseconds: 250);
  DateTime? _lastFollowTime;
  ll.LatLng? _lastFollowTarget;
  double _lastKnownZoom = 15.0;
  double _fixedBearing = 0.0;
  bool _tileSourceLogged = false;
  bool _isProgrammaticCameraMove = false;
  bool _isMapReady = false;

  @override
  void didUpdateWidget(HistoryMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.polylinePoints.length < 2) {
      // New route load starts with empty/short polyline; allow one auto-fit when route appears again.
      _hasAutoFittedCurrentRoute = false;
      return;
    }
    final wasNotDrawable = oldWidget.polylinePoints.length < 2;
    if (wasNotDrawable && _isMapReady && !_hasAutoFittedCurrentRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isMapReady) {
          _fitToPolyline();
          _hasAutoFittedCurrentRoute = true;
        }
      });
    }
    final moved =
        widget.movingMarkerPosition != null &&
        widget.movingMarkerPosition != oldWidget.movingMarkerPosition;
    final followToggledOn =
        widget.isFollowCameraEnabled && !oldWidget.isFollowCameraEnabled;
    if ((moved || followToggledOn) &&
        widget.isFollowCameraEnabled &&
        widget.isPlaybackActive) {
      _followMovingMarker();
    }
  }

  Future<void> _followMovingMarker() async {
    if (!_isMapReady || widget.movingMarkerPosition == null) return;
    final now = DateTime.now();
    if (_lastFollowTime != null &&
        now.difference(_lastFollowTime!).compareTo(_followThrottle) < 0) {
      return;
    }
    final markerPosition = widget.movingMarkerPosition!;
    final target = _cameraTargetWithVisualOffset(markerPosition);
    if (_lastFollowTarget != null) {
      final movedDistance = (target.latitude - _lastFollowTarget!.latitude).abs() +
          (target.longitude - _lastFollowTarget!.longitude).abs();
      if (movedDistance < 0.00003) {
        return;
      }
    }
    _lastFollowTime = now;
    _lastFollowTarget = target;
    _isProgrammaticCameraMove = true;
    try {
      _mapController.moveAndRotate(
        target,
        _lastKnownZoom,
        _fixedBearing,
      );
      debugPrint('[History] Camera: follow recenter applied');
    } finally {
      _isProgrammaticCameraMove = false;
    }
  }

  ll.LatLng _cameraTargetWithVisualOffset(ll.LatLng marker) {
    final heightPx = MediaQuery.sizeOf(context).height;
    final offsetPx = heightPx * _followVerticalOffsetFraction;
    final metersPerPixel =
        156543.03392 * math.cos(marker.latitude * math.pi / 180.0) /
        math.pow(2.0, _lastKnownZoom);
    final offsetMeters = offsetPx * metersPerPixel;
    final deltaLat = offsetMeters / 111320.0;
    final adjustedLat = (marker.latitude - deltaLat).clamp(-85.0, 85.0);
    return ll.LatLng(adjustedLat, marker.longitude);
  }

  void _fitToPolyline() {
    final points = widget.polylinePoints;
    if (points.length < 2 || !_isMapReady) return;
    final bounds = LatLngBounds.fromPoints(points);

    // If the bounds are zero-area (e.g. all points same), fitCamera can crash on non-finite zoom calculation.
    final isZeroArea = bounds.southWest.latitude == bounds.northEast.latitude &&
        bounds.southWest.longitude == bounds.northEast.longitude;

    _isProgrammaticCameraMove = true;
    try {
      if (isZeroArea) {
        _mapController.move(bounds.center, _lastKnownZoom);
        debugPrint('[History] Camera: zero-area move applied');
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(_fitPadding),
          ),
        );
        debugPrint('[History] Camera: initial fit applied');
      }
    } finally {
      _isProgrammaticCameraMove = false;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _mapboxTileUrl() {
    final token = ApiConfig.mapboxAccessToken.trim();
    final hasInvalidTokenFormat =
        token.isEmpty ||
        token.contains('<') ||
        token.contains('>') ||
        token.toLowerCase().contains('your_mapbox_access_token');
    if (hasInvalidTokenFormat) {
      if (!_tileSourceLogged) {
        _tileSourceLogged = true;
        debugPrint(
          '[History] Tiles: Mapbox token missing/invalid, falling back to OSM tiles',
        );
      }
      return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
    if (!_tileSourceLogged) {
      _tileSourceLogged = true;
      debugPrint('[History] Tiles: using Mapbox style tiles');
    }
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$token';
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = widget.initialCenter;
    final hasPolyline = widget.polylinePoints.length >= 2;

    final polylines = <Polyline>[];
    if (hasPolyline) {
      polylines.add(
        Polyline(
          points: widget.polylinePoints,
          color: AppColors.primaryBlue,
          strokeWidth: 4,
        ),
      );
    }

    final markers = <Marker>[];
    final pointCount = widget.markerPoints.length;
    for (var i = 0; i < pointCount; i++) {
      final isStart = i == 0;
      final isEnd = i == pointCount - 1;
      markers.add(
        Marker(
          point: widget.markerPoints[i],
          width: 30,
          height: 30,
          child: Icon(
            Icons.location_pin,
            color: isStart
                ? Colors.green
                : isEnd
                ? Colors.red
                : Colors.blue,
            size: 30,
          ),
        ),
      );
    }

    if (widget.movingMarkerPosition != null) {
      markers.add(
        Marker(
          point: widget.movingMarkerPosition!,
          width: 44,
          height: 44,
          child: Transform.rotate(
            angle: (widget.movingMarkerBearing ?? 0.0) * (math.pi / 180.0),
            child: Image.asset(
              widget.movingMarkerAssetPath,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialTarget,
        initialZoom: widget.initialZoom,
        initialRotation: 0.0,
        onMapReady: () {
          _isMapReady = true;
          _lastKnownZoom = widget.initialZoom;
          _fixedBearing = 0.0;
          if (widget.polylinePoints.length >= 2 && !_hasAutoFittedCurrentRoute) {
            _fitToPolyline();
            _hasAutoFittedCurrentRoute = true;
          }
        },
        onPositionChanged: (camera, hasGesture) {
          if (camera.zoom.isFinite) {
            _lastKnownZoom = camera.zoom;
          }
          if (hasGesture &&
              !_isProgrammaticCameraMove &&
              widget.isPlaybackActive &&
              widget.isFollowCameraEnabled) {
            widget.onManualFollowDisable?.call();
            debugPrint('[History] Camera: manual move detected, follow disabled');
          }
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: _mapboxTileUrl(),
          userAgentPackageName: 'com.airotrack.app',
          fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }
}
