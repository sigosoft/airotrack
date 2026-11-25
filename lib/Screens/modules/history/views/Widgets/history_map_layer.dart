import 'dart:math' as math;
import 'dart:ui' as ui show PictureRecorder, ImageByteFormat;

import 'package:airotrack/Models/HistoryModel.dart';
import 'package:airotrack/Services/AppSettings.dart';
import 'package:airotrack/Services/ReverseGeocodeService.dart';
import 'package:airotrack/Utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:intl/intl.dart' show DateFormat;
import 'package:latlong2/latlong.dart' as ll;

/// History map on Google Maps (same map as Location and Live Track): the
/// route line, start/end pins, numbered stops, the playback car and the
/// camera that follows it.
class HistoryMapLayer extends StatefulWidget {
  const HistoryMapLayer({
    Key? key,
    required this.initialCenter,
    required this.initialZoom,
    required this.polylinePoints,
    required this.markerPoints,
    this.stopLocations = const [],
    this.selectedStopIndex,
    this.showStopMarkers = true,
    this.onStopTap,
    this.movingMarkerPosition,
    this.movingMarkerBearing,
    this.isFollowCameraEnabled = true,
    this.isPlaybackActive = false,
    this.bottomSheetVisible = true,
    this.onManualFollowDisable,
    this.onRouteTap,
    this.routeTapPoint,
    this.movingMarkerAssetPath = 'lib/Asset/Images/marker2.png',
    this.bottomSheetFraction = 0.0,
    this.mapType = AppMapType.normal,
    this.fitRouteRequest = 0,
    this.zoomSteps = 0,
    this.recenterRequest = 0,
    this.onZoomChanged,
  }) : super(key: key);

  /// Default, Satellite or Terrain.
  final AppMapType mapType;

  /// When this changes, the map fits the whole route (route button).
  final int fitRouteRequest;

  /// Net zoom-button presses; each change zooms by the difference.
  final int zoomSteps;

  /// Re-centre button presses; each one brings the camera back to the car
  /// at once, ending the wait after a drag.
  final int recenterRequest;

  /// Called with the map's zoom whenever it changes.
  final ValueChanged<double>? onZoomChanged;

  final ll.LatLng initialCenter;
  final double initialZoom;
  final List<ll.LatLng> polylinePoints;
  final List<ll.LatLng> markerPoints;
  final List<HistoryStopLocation> stopLocations;
  final int? selectedStopIndex;
  final bool showStopMarkers;
  final ValueChanged<int>? onStopTap;
  final ll.LatLng? movingMarkerPosition;
  final double? movingMarkerBearing;
  final bool isFollowCameraEnabled;
  final bool isPlaybackActive;
  final bool bottomSheetVisible;
  final VoidCallback? onManualFollowDisable;
  final ValueChanged<ll.LatLng>? onRouteTap;
  final ll.LatLng? routeTapPoint;
  final String movingMarkerAssetPath;

  /// Share of the map's height the bottom sheet covers when shown; the
  /// route fit keeps the route above it.
  final double bottomSheetFraction;

  @override
  State<HistoryMapLayer> createState() => _HistoryMapLayerState();
}

class _HistoryMapLayerState extends State<HistoryMapLayer>
    with SingleTickerProviderStateMixin {
  gm.GoogleMapController? _map;
  static const double _fitPadding = 48.0;
  static const double _followVerticalOffsetFraction = 0.22;
  static const double _playbackFollowZoom = 16.0;
  static const double _maxFitZoom = 18.0;
  bool _hasAutoFittedCurrentRoute = false;
  ll.LatLng? _lastFollowTarget;
  ll.LatLng? _smoothCameraCenter;
  double _lastKnownZoom = 15.0;
  bool _usePlaybackFollowZoom = false;
  bool _isMapReady = false;
  Size _mapSize = Size.zero;

  /// Where the app last told the camera to go; a reported camera far from
  /// it (same zoom) during a touch means the user panned.
  gm.LatLng? _cmdTarget;
  double? _cmdZoom;

  /// Latest camera, for placing the stop card over its marker.
  late final ValueNotifier<gm.CameraPosition> _camera;

  /// Touch tracking. A one-finger drag stops follow; a pinch keeps the car
  /// in focus and keeps the new zoom. While the user touches the map (and
  /// shortly after, for a fling), follow doesn't move the camera, so it
  /// never fights the finger.
  final Map<int, Offset> _pointerDownAt = {};
  bool _sessionMultiTouch = false;
  bool _sessionZoomed = false;
  bool _singleFingerDrag = false;
  bool _sessionFollowOffSent = false;
  DateTime? _touchSessionUntil;
  static const double _panSlopPx = 10.0;
  static const int _afterTouchMs = 600;

  /// How long Google can take to report a camera move the app made.
  static const int _ownMoveReportMs = 300;

  /// After a drag the map stays where the user left it this long, then
  /// glides back to the car and follows it again, as on Live Track.
  /// Following used to switch off for good on a drag, losing the car.
  static const Duration _recenterDelay = Duration(seconds: 3);
  static const int _resumeGlideMs = 600;
  DateTime? _followHoldUntil;
  bool _sessionDragged = false;
  bool _wasHeld = false;
  ll.LatLng? _glideFrom;
  DateTime? _glideAt;
  double? _glideFromZoom;
  int _glideMs = _resumeGlideMs;

  /// The focus button's glide is a little longer: it may change the zoom
  /// a lot (from the whole route back to the car).
  static const int _recenterGlideMs = 800;

  /// Following waits: a finger is on the map, or a drag ended less than
  /// [_recenterDelay] ago.
  bool get _followHeld {
    if (_userGesture) return true;
    final until = _followHoldUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// Starts (or restarts) the wait after a drag.
  void _holdAfterDrag() {
    _followHoldUntil = DateTime.now().add(_recenterDelay);
  }

  bool get _userGesture {
    if (_pointerDownAt.isNotEmpty) return true;
    final until = _touchSessionUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  Ticker? _smoothTicker;
  ll.LatLng? _renderPosition;
  double _renderBearing = 0.0;

  /// Bumped when the car moves. The car is a Flutter picture over the map,
  /// not a Google marker: the Android map plugin re-decodes a marker's
  /// picture on every update, and updating it each frame during playback
  /// froze the map for seconds with no car on it.
  final ValueNotifier<int> _carMoved = ValueNotifier(0);

  /// While a finger is on the map, the car is a Google marker instead.
  /// Google reports the camera late and in bursts during a pinch or drag,
  /// so a Flutter car placed from those reports slid off the route or left
  /// the screen; Google moves its own marker with the map exactly. The
  /// marker stays on the map, see-through, the rest of the time, so Google
  /// has its picture ready (adding it at touch time took long enough to
  /// leave a gap with no car).
  gm.BitmapDescriptor? _carMarkerIcon;
  gm.Marker? _carMarker;
  bool _markerCarOn = false;
  bool _overlayCarHidden = false;
  DateTime _markerCarSince = DateTime(0);
  DateTime _lastCarMarkerAt = DateTime(0);

  /// Google re-decodes a marker's picture on every update, so it is moved
  /// at most this often (every frame froze the map before).
  static const int _carMarkerIntervalMs = 100;

  /// Google shows a marker ~170 ms after it's asked to, and later while
  /// the map is busy; the Flutter car stays until then so there is never a
  /// moment with no car. 200 ms still left a frame with no car on device.
  static const int _carHandoverMs = 350;

  /// Last route, so the route line is only rebuilt when it changes.
  List<ll.LatLng>? _polylineSource;
  Set<gm.Polyline> _polylines = const {};

  gm.BitmapDescriptor? _tapDotIcon;

  /// Start of the route: Google Maps' directions start circle.
  gm.BitmapDescriptor? _startDotIcon;
  final Map<int, gm.BitmapDescriptor> _stopIcons = {};

  double _bearingAlpha(bool isPlaying) => isPlaying ? 0.55 : 1.0;

  @override
  void initState() {
    super.initState();
    _lastKnownZoom = widget.initialZoom;
    _camera = ValueNotifier(
      gm.CameraPosition(
        target: _g(widget.initialCenter),
        zoom: widget.initialZoom,
      ),
    );
    _smoothTicker = createTicker(_onSmoothTick)..start();
    // Drawing needs the screen's pixel ratio (View.of), which can't be read
    // until initState has finished.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadIcons();
    });
  }

  static gm.LatLng _g(ll.LatLng p) => gm.LatLng(p.latitude, p.longitude);
  static ll.LatLng _l(gm.LatLng p) => ll.LatLng(p.latitude, p.longitude);

  // ---------------------------------------------------------------------
  // Marker pictures (Google markers are pictures, not widgets)
  // ---------------------------------------------------------------------

  double get _dpr => View.of(context).devicePixelRatio;

  Future<void> _loadIcons() async {
    try {
      final data = await rootBundle.load(widget.movingMarkerAssetPath);
      _carMarkerIcon = gm.BitmapDescriptor.bytes(
        data.buffer.asUint8List(),
        width: 40,
        height: 40,
      );
    } catch (e) {
      debugPrint('[History] car marker picture failed: $e');
    }
    if (!mounted) return;
    // Google Maps' directions start point: a white dot inside a Google grey
    // (#5F6368) ring, with a faint shadow.
    _startDotIcon = await _draw(const Size(22, 22), (c) {
      const centre = Offset(11, 11);
      c.drawCircle(
        centre.translate(0, 0.75),
        8.5,
        Paint()
          ..color = Colors.black26
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
      c.drawCircle(centre, 8, Paint()..color = const Color(0xFF5F6368));
      c.drawCircle(centre, 4.5, Paint()..color = Colors.white);
    });
    if (!mounted) return;
    _tapDotIcon = await _draw(const Size(18, 18), (c) {
      c.drawCircle(const Offset(9, 9), 7, Paint()..color = Colors.white);
      c.drawCircle(
        const Offset(9, 9),
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = AppColors.primaryBlue,
      );
    });
    if (mounted) setState(() {});
  }

  /// Red rounded square with a white border and the stop number, as before.
  Future<void> _ensureStopIcon(int number) async {
    if (_stopIcons.containsKey(number)) return;
    final icon = await _draw(const Size(30, 30), (c) {
      const r = Rect.fromLTWH(2, 2, 26, 26);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
      c.drawRRect(
        rr.shift(const Offset(0, 1)),
        Paint()
          ..color = Colors.black26
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      c.drawRRect(rr, Paint()..color = Colors.red.shade700);
      c.drawRRect(
        rr.deflate(0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, r.center - Offset(tp.width / 2, tp.height / 2));
    });
    if (!mounted) return;
    setState(() => _stopIcons[number] = icon);
  }

  Future<gm.BitmapDescriptor> _draw(
    Size size,
    void Function(Canvas) paint,
  ) async {
    final dpr = _dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    paint(canvas);
    final image = await recorder.endRecording().toImage(
      (size.width * dpr).ceil(),
      (size.height * dpr).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return gm.BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: size.width,
      height: size.height,
    );
  }

  // ---------------------------------------------------------------------
  // Playback car and follow camera
  // ---------------------------------------------------------------------

  /// Puts the Google car marker at the car, shown or see-through.
  void _pushCarMarker({required bool visible}) {
    final icon = _carMarkerIcon;
    final at = _renderPosition ?? widget.movingMarkerPosition;
    if (icon == null || at == null || !mounted) return;
    _lastCarMarkerAt = DateTime.now();
    setState(() {
      _carMarker = gm.Marker(
        markerId: const gm.MarkerId('car'),
        position: _g(at),
        icon: icon,
        rotation: _renderPosition != null
            ? _renderBearing
            : (widget.movingMarkerBearing ?? 0.0),
        anchor: const Offset(0.5, 0.5),
        alpha: visible ? 1.0 : 0.0,
        zIndexInt: 5,
      );
    });
  }

  /// Every frame: Google marker car while a finger is on the map (and
  /// during the fling after), Flutter car otherwise.
  void _syncGestureCar() {
    final want =
        _userGesture &&
        _carMarkerIcon != null &&
        (_renderPosition ?? widget.movingMarkerPosition) != null;
    final now = DateTime.now();
    if (want) {
      if (!_markerCarOn) {
        _markerCarOn = true;
        _markerCarSince = now;
        _pushCarMarker(visible: true);
        return;
      }
      if (now.difference(_lastCarMarkerAt).inMilliseconds >=
          _carMarkerIntervalMs) {
        _pushCarMarker(visible: true);
      }
      if (!_overlayCarHidden &&
          now.difference(_markerCarSince).inMilliseconds >= _carHandoverMs) {
        _overlayCarHidden = true;
        _carMoved.value++;
      }
    } else if (_markerCarOn) {
      // Flutter car back first (it shows at once), then hide the marker.
      _markerCarOn = false;
      _overlayCarHidden = false;
      _carMoved.value++;
      _pushCarMarker(visible: false);
    } else if (_carMarker == null && _carMarkerIcon != null) {
      _pushCarMarker(visible: false);
    }
  }

  void _onSmoothTick(Duration elapsed) {
    _syncGestureCar();
    // Paused: nothing else moves the camera, so run the focus glide here.
    if (!widget.isPlaybackActive && _glideAt != null && !_userGesture) {
      _glideStep();
    }
    final target = widget.movingMarkerPosition;
    if (target == null) {
      if (_renderPosition != null && mounted) {
        _renderPosition = null;
        _carMoved.value++;
      }
      return;
    }

    final targetBearing = widget.movingMarkerBearing ?? 0.0;
    if (_renderPosition == null) {
      if (!mounted) return;
      _renderPosition = target;
      _renderBearing = targetBearing;
      _carMoved.value++;
      // Follow only while playing. Following as soon as the car first
      // appeared zoomed the camera onto the parked car (zoom 16) and undid
      // the fit to the whole route when History opened.
      if (widget.isFollowCameraEnabled && widget.isPlaybackActive) {
        _enterFollowMode(snapImmediately: true);
      }
      return;
    }

    final latDelta = target.latitude - _renderPosition!.latitude;
    final lngDelta = target.longitude - _renderPosition!.longitude;
    final bearingDelta = _shortestBearingDelta(_renderBearing, targetBearing);

    if (latDelta.abs() < 1e-8 &&
        lngDelta.abs() < 1e-8 &&
        bearingDelta.abs() < 0.05) {
      return;
    }

    // The controller already moves the car along the route each frame; a
    // lat/lng lerp would cut corners off the blue line.
    final bearingAlpha = _bearingAlpha(widget.isPlaybackActive);
    if (!mounted) return;
    _renderPosition = target;
    _renderBearing = (_renderBearing + bearingDelta * bearingAlpha) % 360;
    _carMoved.value++;

    if (widget.isFollowCameraEnabled && widget.isPlaybackActive) {
      _followMovingMarker();
    }
  }

  double _shortestBearingDelta(double from, double to) {
    return ((to - from + 540) % 360) - 180;
  }

  @override
  void didUpdateWidget(HistoryMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.zoomSteps != oldWidget.zoomSteps) {
      _zoomBy((widget.zoomSteps - oldWidget.zoomSteps).toDouble());
    }
    // Route button: show the whole route.
    if (widget.fitRouteRequest != oldWidget.fitRouteRequest &&
        widget.polylinePoints.length >= 2 &&
        _isMapReady) {
      _usePlaybackFollowZoom = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isMapReady) _fitToPolyline();
      });
    }
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
    final followToggledOn =
        widget.isFollowCameraEnabled && !oldWidget.isFollowCameraEnabled;
    final playbackStarted =
        widget.isPlaybackActive && !oldWidget.isPlaybackActive;
    if (playbackStarted && widget.isFollowCameraEnabled) {
      _enterFollowMode(snapImmediately: true);
    }
    // Focus button: back to the start view, on the car at the start zoom.
    // Following each move is left to the frame tick; following here too
    // sent the camera two different targets every frame.
    if (widget.recenterRequest != oldWidget.recenterRequest) {
      _recenter();
    } else if (followToggledOn &&
        widget.isPlaybackActive &&
        _renderPosition != null) {
      _enterFollowMode(snapImmediately: true);
    }
  }

  /// Focus button: glide to the car at the zoom playback starts with
  /// ([_playbackFollowZoom]), playing or paused, and follow it from there.
  /// It used to jump there only after the route button, keep the user's
  /// zoom after a drag, and do nothing at all while paused.
  void _recenter() {
    _followHoldUntil = null;
    _usePlaybackFollowZoom = true;
    _lastKnownZoom = _playbackFollowZoom;
    final car = _renderPosition ?? widget.movingMarkerPosition;
    if (car == null || !_isMapReady) return;
    _wasHeld = false;
    _glideFrom = _l(_camera.value.target);
    _glideFromZoom = _camera.value.zoom;
    _glideAt = DateTime.now();
    _glideMs = _recenterGlideMs;
    _glideStep();
  }

  /// One frame of a glide to the car (after a drag, or the focus button):
  /// eases position, and zoom when [_glideFromZoom] is set, from where the
  /// map was to the follow view. Returns whether it moved the camera.
  bool _glideStep() {
    final from = _glideFrom;
    final at = _glideAt;
    final car = _renderPosition ?? widget.movingMarkerPosition;
    if (from == null || at == null || car == null) return false;
    final zoom = _activeFollowZoom();
    final target = _cameraTargetWithVisualOffset(car);
    final t = DateTime.now().difference(at).inMilliseconds / _glideMs;
    ll.LatLng pos;
    double z;
    if (t >= 1.0) {
      _glideFrom = null;
      _glideAt = null;
      _glideFromZoom = null;
      _glideMs = _resumeGlideMs;
      pos = target;
      z = zoom;
    } else {
      // Ease in and out, so the map neither jumps nor stops abruptly.
      final e = t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
      pos = ll.LatLng(
        from.latitude + (target.latitude - from.latitude) * e,
        from.longitude + (target.longitude - from.longitude) * e,
      );
      final fz = _glideFromZoom;
      z = fz == null ? zoom : fz + (zoom - fz) * e;
    }
    _smoothCameraCenter = pos;
    _lastFollowTarget = pos;
    _moveCamera(pos, z);
    return true;
  }

  /// Zoom buttons. While following, the next follow step uses the new zoom;
  /// otherwise the camera zooms where it is.
  void _zoomBy(double delta) {
    final from = _camera.value.zoom.isFinite
        ? _camera.value.zoom
        : _lastKnownZoom;
    final to = (from + delta).clamp(3.0, 21.0);
    _usePlaybackFollowZoom = false;
    _lastKnownZoom = to;
    if (widget.isFollowCameraEnabled &&
        widget.isPlaybackActive &&
        _renderPosition != null) {
      _lastFollowTarget = null;
      _smoothCameraCenter = null;
      _followMovingMarker();
    } else {
      _cmdZoom = to;
      _map?.animateCamera(gm.CameraUpdate.zoomTo(to));
    }
  }

  /// When the app last moved the camera itself.
  DateTime _lastFollowCmdAt = DateTime(0);

  /// Camera the Flutter car is placed against. While the camera follows
  /// the car, it's the camera the app just asked for: Google reports the
  /// camera late and not every frame, and placing the car against those
  /// reports made it jump ~100 px back and forth on screen on the phone.
  /// Otherwise (map still, or user moving it), it's the reported camera.
  gm.CameraPosition get _carCamera {
    final cmd = _cmdTarget;
    final zoom = _cmdZoom;
    final appMoving =
        (widget.isPlaybackActive && widget.isFollowCameraEnabled) ||
        _glideAt != null;
    final following =
        appMoving &&
        !_userGesture &&
        cmd != null &&
        zoom != null &&
        DateTime.now().difference(_lastFollowCmdAt).inMilliseconds < 150;
    return following
        ? gm.CameraPosition(target: cmd, zoom: zoom)
        : _camera.value;
  }

  void _moveCamera(ll.LatLng target, double zoom) {
    final map = _map;
    if (map == null) return;
    final t = _g(target);
    _cmdTarget = t;
    _cmdZoom = zoom;
    _lastFollowCmdAt = DateTime.now();
    map.moveCamera(
      gm.CameraUpdate.newCameraPosition(
        gm.CameraPosition(target: t, zoom: zoom),
      ),
    );
  }

  void _enterFollowMode({bool snapImmediately = false}) {
    _usePlaybackFollowZoom = true;
    _lastKnownZoom = _playbackFollowZoom;
    final marker = _renderPosition ?? widget.movingMarkerPosition;
    if (marker == null || !_isMapReady) return;
    final target = _cameraTargetWithVisualOffset(marker);
    if (snapImmediately) {
      _smoothCameraCenter = target;
      _lastFollowTarget = target;
      _moveCamera(target, _playbackFollowZoom);
    }
  }

  double _activeFollowZoom() =>
      _usePlaybackFollowZoom ? _playbackFollowZoom : _lastKnownZoom;

  void _followMovingMarker() {
    if (!_isMapReady || _renderPosition == null) return;
    if (!widget.isFollowCameraEnabled) return;
    // Never fight a finger on the map, and leave the map where the user
    // dragged it for a while (like Live Track).
    if (_followHeld) {
      _wasHeld = true;
      return;
    }
    if (_wasHeld) {
      // Back to the car: glide there from where the map was left.
      _wasHeld = false;
      _glideFrom = _l(_camera.value.target);
      _glideFromZoom = null;
      _glideAt = DateTime.now();
      _glideMs = _resumeGlideMs;
      _smoothCameraCenter = null;
      _lastFollowTarget = null;
    }

    if (_glideStep()) return;

    final markerPosition = _renderPosition!;
    final target = _cameraTargetWithVisualOffset(markerPosition);
    final zoom = _activeFollowZoom();

    if (_smoothCameraCenter == null) {
      _smoothCameraCenter = target;
    } else {
      const cameraAlpha = 0.88;
      _smoothCameraCenter = ll.LatLng(
        _smoothCameraCenter!.latitude +
            (target.latitude - _smoothCameraCenter!.latitude) * cameraAlpha,
        _smoothCameraCenter!.longitude +
            (target.longitude - _smoothCameraCenter!.longitude) * cameraAlpha,
      );
    }

    if (_lastFollowTarget != null && _cmdZoom == zoom) {
      final movedDistance =
          (_smoothCameraCenter!.latitude - _lastFollowTarget!.latitude).abs() +
          (_smoothCameraCenter!.longitude - _lastFollowTarget!.longitude).abs();
      if (movedDistance < 0.000001) return;
    }
    _lastFollowTarget = _smoothCameraCenter;
    _moveCamera(_smoothCameraCenter!, zoom);
  }

  ll.LatLng _cameraTargetWithVisualOffset(ll.LatLng marker) {
    if (!widget.bottomSheetVisible) {
      return marker;
    }
    final heightPx = MediaQuery.sizeOf(context).height;
    final offsetPx = heightPx * _followVerticalOffsetFraction;
    final zoom = _activeFollowZoom();
    final metersPerPixel =
        156543.03392 *
        math.cos(marker.latitude * math.pi / 180.0) /
        math.pow(2.0, zoom);
    final offsetMeters = offsetPx * metersPerPixel;
    final deltaLat = offsetMeters / 111320.0;
    final adjustedLat = (marker.latitude - deltaLat).clamp(-85.0, 85.0);
    return ll.LatLng(adjustedLat, marker.longitude);
  }

  // ---------------------------------------------------------------------
  // Web Mercator (256 px tiles; the map never rotates or tilts here)
  // ---------------------------------------------------------------------

  static Offset _world0(double lat, double lng) {
    final s = math.sin(lat.clamp(-85.0, 85.0) * math.pi / 180);
    return Offset(
      (lng + 180) / 360 * 256,
      (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * 256,
    );
  }

  static double _latFromWorld0Y(double y) {
    final n = math.pi * (1 - 2 * y / 256);
    return math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi;
  }

  /// Screen position (map-local logical px) of [p] for [cam].
  Offset _toScreen(gm.LatLng p, gm.CameraPosition cam) {
    final scale = math.pow(2, cam.zoom).toDouble();
    final a = _world0(p.latitude, p.longitude) * scale;
    final c = _world0(cam.target.latitude, cam.target.longitude) * scale;
    return a - c + Offset(_mapSize.width / 2, _mapSize.height / 2);
  }

  /// Fits the whole route above the bottom sheet.
  void _fitToPolyline() {
    final points = widget.polylinePoints;
    if (points.length < 2 || !_isMapReady || _mapSize.isEmpty) return;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in points) {
      final w = _world0(p.latitude, p.longitude);
      minX = math.min(minX, w.dx);
      maxX = math.max(maxX, w.dx);
      minY = math.min(minY, w.dy);
      maxY = math.max(maxY, w.dy);
    }
    final sheetPx = widget.bottomSheetVisible
        ? _mapSize.height * widget.bottomSheetFraction.clamp(0.0, 0.8)
        : 0.0;
    final availW = math.max(40.0, _mapSize.width - _fitPadding * 2);
    final availH = math.max(40.0, _mapSize.height - _fitPadding * 2 - sheetPx);
    final dx = maxX - minX;
    final dy = maxY - minY;
    var zoom = _maxFitZoom;
    if (dx > 0) zoom = math.min(zoom, math.log(availW / dx) / math.ln2);
    if (dy > 0) zoom = math.min(zoom, math.log(availH / dy) / math.ln2);
    if (!zoom.isFinite) zoom = _lastKnownZoom;
    zoom = zoom.clamp(3.0, _maxFitZoom);
    // Centre the route in the part of the map above the sheet: the camera
    // centre sits half a sheet lower.
    final scale = math.pow(2, zoom).toDouble();
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2 + (sheetPx / 2) / scale;
    final centre = ll.LatLng(_latFromWorld0Y(cy), cx / 256 * 360 - 180);
    _lastKnownZoom = zoom;
    _moveCamera(centre, zoom);
    debugPrint(
      '[History] Camera: route fit applied (zoom ${zoom.toStringAsFixed(2)})',
    );
  }

  @override
  void dispose() {
    _smoothTicker?.dispose();
    _camera.dispose();
    _carMoved.dispose();
    super.dispose();
  }

  gm.MapType get _googleMapType => switch (widget.mapType) {
    AppMapType.satellite => gm.MapType.hybrid,
    AppMapType.terrain => gm.MapType.terrain,
    AppMapType.normal => gm.MapType.normal,
  };

  void _onCameraMove(gm.CameraPosition pos) {
    _camera.value = pos;
    final zoom = pos.zoom;
    widget.onZoomChanged?.call(zoom);
    final following = widget.isPlaybackActive && widget.isFollowCameraEnabled;
    if (!_userGesture) {
      // Our own move (or a zoom-button animation).
      if (!following) _lastKnownZoom = zoom;
      return;
    }
    // A fling keeps the camera moving after the finger lifts.
    if (_pointerDownAt.isEmpty) {
      _touchSessionUntil = DateTime.now().add(
        const Duration(milliseconds: _afterTouchMs),
      );
    }
    final cmdZoom = _cmdZoom ?? _lastKnownZoom;
    if ((zoom - cmdZoom).abs() > 0.01) {
      // Pinch: keep follow, lock to the new zoom.
      _sessionZoomed = true;
      _usePlaybackFollowZoom = false;
      _lastKnownZoom = zoom;
      _cmdZoom = zoom;
      return;
    }
    if (!following) {
      _lastKnownZoom = zoom;
      return;
    }
    if (_sessionMultiTouch || _sessionZoomed) return;
    final cmd = _cmdTarget;
    // The camera check only counts once the app's own last camera move has
    // surely been reported: Google reports moves late, so right after a
    // touch began, reports of the follow moves made just before it still
    // differ from the newest one, and a plain tap counted as a drag (it
    // turned following off).
    final ownMovesSettled =
        DateTime.now().difference(_lastFollowCmdAt).inMilliseconds >
        _ownMoveReportMs;
    final panned =
        _singleFingerDrag ||
        (ownMovesSettled &&
            cmd != null &&
            !_mapSize.isEmpty &&
            (_toScreen(pos.target, pos) - _toScreen(cmd, pos)).distance > 15);
    if (panned) {
      _sessionDragged = true;
      // The wait runs from the last movement, so a fling counts too.
      if (_pointerDownAt.isEmpty) _holdAfterDrag();
      if (!_sessionFollowOffSent) {
        // Logged once per drag; every camera report of it used to repeat.
        _sessionFollowOffSent = true;
        debugPrint('[History] Camera: drag, follow paused');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Playback rebuilds this widget every frame; hand Google the very same
    // route and markers unless they really changed, so the map isn't sent
    // updates (and marker pictures re-decoded) each frame.
    if (!identical(_polylineSource, widget.polylinePoints)) {
      _polylineSource = widget.polylinePoints;
      _polylines = {
        if (widget.polylinePoints.length >= 2)
          gm.Polyline(
            polylineId: const gm.PolylineId('history-route'),
            points: widget.polylinePoints.map(_g).toList(),
            color: AppColors.primaryBlue,
            width: 4,
          ),
      };
    }
    final markerKey = <Object?>[
      widget.selectedStopIndex,
      widget.showStopMarkers,
      _stopIcons.length,
      _tapDotIcon != null,
      _startDotIcon != null,
      widget.routeTapPoint,
      widget.markerPoints.length,
      ...widget.markerPoints,
      widget.stopLocations.length,
      ...widget.stopLocations,
    ];
    if (!_sameKey(markerKey, _markerKey)) {
      _markerKey = markerKey;
      _markers = _buildMarkers();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _mapSize = constraints.biggest;
        return Stack(
          children: [
            Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              child: gm.GoogleMap(
                initialCameraPosition: gm.CameraPosition(
                  target: _g(widget.initialCenter),
                  zoom: widget.initialZoom,
                ),
                mapType: _googleMapType,
                polylines: _polylines,
                markers: {..._markers, ?_carMarker},
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                onMapCreated: (c) {
                  _map = c;
                  _isMapReady = true;
                  _lastKnownZoom = widget.initialZoom;
                  if (widget.polylinePoints.length >= 2 &&
                      !_hasAutoFittedCurrentRoute) {
                    _fitToPolyline();
                    _hasAutoFittedCurrentRoute = true;
                  }
                },
                onCameraMove: _onCameraMove,
                onTap: (point) {
                  if (widget.selectedStopIndex != null) {
                    widget.onStopTap?.call(-1);
                  }
                  widget.onRouteTap?.call(_l(point));
                },
              ),
            ),
            _movingCar(),
            _selectedStopCard(),
          ],
        );
      },
    );
  }

  List<Object?>? _markerKey;
  Set<gm.Marker> _markers = const {};

  static bool _sameKey(List<Object?> a, List<Object?>? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// The playback car, drawn by Flutter over the map at the car's spot for
  /// the camera Google last reported (what is on screen), turned to its
  /// heading.
  Widget _movingCar() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_carMoved, _camera]),
        builder: (context, _) {
          final at = _renderPosition ?? widget.movingMarkerPosition;
          if (at == null || _mapSize.isEmpty || _overlayCarHidden) {
            return const SizedBox.shrink();
          }
          final bearing = _renderPosition != null
              ? _renderBearing
              : (widget.movingMarkerBearing ?? 0.0);
          final p = _toScreen(_g(at), _carCamera);
          return Stack(
            children: [
              Positioned(
                left: p.dx - 22,
                top: p.dy - 22,
                width: 44,
                height: 44,
                child: Transform.rotate(
                  angle: bearing * (math.pi / 180.0),
                  child: Image.asset(
                    widget.movingMarkerAssetPath,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Set<gm.Marker> _buildMarkers() {
    final markers = <gm.Marker>{};
    // A stop at the start (vehicle parked there) is shown by the start
    // circle alone; its square would sit messily behind the circle.
    var stopAtStart = -1;
    final pointCount = widget.markerPoints.length;
    for (var i = 0; i < pointCount; i++) {
      final isStart = i == 0;
      final isEnd = i == pointCount - 1;
      final startDot = _startDotIcon;
      if (isStart && startDot != null) {
        // Start circle, centred on the start, as in Google Maps. It stands
        // in for a stop at the same spot (a vehicle that was parked at the
        // start): tapping it opens that stop.
        final start = widget.markerPoints[i];
        final stopHere = widget.showStopMarkers
            ? widget.stopLocations.indexWhere(
                (s) =>
                    const ll.Distance().as(
                      ll.LengthUnit.Meter,
                      start,
                      ll.LatLng(s.markerLatitude, s.markerLongitude),
                    ) <
                    50,
              )
            : -1;
        stopAtStart = stopHere;
        markers.add(
          gm.Marker(
            markerId: gm.MarkerId('pt-$i'),
            position: _g(start),
            icon: startDot,
            anchor: const Offset(0.5, 0.5),
            // Not flat: Android draws flat markers under all others.
            zIndexInt: 3,
            consumeTapEvents: true,
            onTap: stopHere >= 0
                ? () => widget.onStopTap?.call(stopHere)
                : null,
          ),
        );
        continue;
      }
      markers.add(
        gm.Marker(
          markerId: gm.MarkerId('pt-$i'),
          position: _g(widget.markerPoints[i]),
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(
            isStart
                ? gm.BitmapDescriptor.hueAzure
                : isEnd
                ? gm.BitmapDescriptor.hueRed
                : gm.BitmapDescriptor.hueAzure,
          ),
          zIndexInt: 1,
        ),
      );
    }

    if (widget.showStopMarkers) {
      for (var i = 0; i < widget.stopLocations.length; i++) {
        if (i == stopAtStart) continue;
        final stop = widget.stopLocations[i];
        final number = stop.index ?? (i + 1);
        final icon = _stopIcons[number];
        if (icon == null) {
          _ensureStopIcon(number);
          continue;
        }
        markers.add(
          gm.Marker(
            markerId: gm.MarkerId('stop-$i'),
            position: gm.LatLng(stop.markerLatitude, stop.markerLongitude),
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: widget.selectedStopIndex == i ? 4 : 2,
            consumeTapEvents: true,
            onTap: () => widget.onStopTap?.call(i),
          ),
        );
      }
    }

    final tap = widget.routeTapPoint;
    final tapIcon = _tapDotIcon;
    if (tap != null && tapIcon != null) {
      markers.add(
        gm.Marker(
          markerId: const gm.MarkerId('route-tap'),
          position: _g(tap),
          icon: tapIcon,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 4,
        ),
      );
    }
    return markers;
  }

  /// Details card above the selected stop, kept over its marker as the map
  /// moves.
  Widget _selectedStopCard() {
    final i = widget.selectedStopIndex;
    if (!widget.showStopMarkers ||
        i == null ||
        i < 0 ||
        i >= widget.stopLocations.length) {
      return const SizedBox.shrink();
    }
    final stop = widget.stopLocations[i];
    final number = stop.index ?? (i + 1);
    final point = gm.LatLng(stop.markerLatitude, stop.markerLongitude);
    const cardWidth = 250.0;
    return ValueListenableBuilder<gm.CameraPosition>(
      valueListenable: _camera,
      builder: (context, cam, _) {
        final at = _toScreen(point, cam);
        return Positioned(
          left: at.dx - cardWidth / 2,
          // Card bottom sits just above the 26 px stop square.
          bottom: _mapSize.height - at.dy + 13 + 4,
          width: cardWidth,
          child: _HistoryStopMarker(
            number: number,
            selected: true,
            cardOnly: true,
            stop: stop,
            onTap: () => widget.onStopTap?.call(i),
          ),
        );
      },
    );
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!_userGesture) {
      // New touch session.
      _sessionMultiTouch = false;
      _sessionZoomed = false;
      _singleFingerDrag = false;
      _sessionFollowOffSent = false;
      _sessionDragged = false;
      // A new touch stops a glide back to the car where it is.
      _glideFrom = null;
      _glideAt = null;
      _glideFromZoom = null;
      _glideMs = _resumeGlideMs;
    }
    _pointerDownAt[e.pointer] = e.position;
    if (_pointerDownAt.length > 1) {
      _sessionMultiTouch = true;
      _singleFingerDrag = false;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    final start = _pointerDownAt[e.pointer];
    if (start == null || _sessionMultiTouch || _pointerDownAt.length != 1) {
      return;
    }
    if ((e.position - start).distance > _panSlopPx) {
      _singleFingerDrag = true;
    }
  }

  void _onPointerUp(PointerEvent e) {
    _pointerDownAt.remove(e.pointer);
    if (_pointerDownAt.isEmpty) {
      // A plain tap (finger lifted without dragging, pinching or zooming)
      // can't fling the map, so following carries on at once; waiting let
      // the car drift off and the camera then snapped back to it. A
      // cancelled touch (Google took the gesture over) may still be a drag.
      final plainTap =
          e is PointerUpEvent &&
          !_singleFingerDrag &&
          !_sessionMultiTouch &&
          !_sessionZoomed;
      _touchSessionUntil = plainTap
          ? DateTime.now()
          : DateTime.now().add(const Duration(milliseconds: _afterTouchMs));
      if (_singleFingerDrag || _sessionDragged) _holdAfterDrag();
    }
  }
}

class _HistoryStopMarker extends StatelessWidget {
  const _HistoryStopMarker({
    required this.number,
    required this.selected,
    this.cardOnly = false,
    required this.stop,
    required this.onTap,
  });

  final int number;
  final bool selected;

  /// Only the details card; the numbered square is a Google marker.
  final bool cardOnly;
  final HistoryStopLocation stop;
  final VoidCallback onTap;

  static final _displayTimeFormat = DateFormat('dd MMM yyyy hh:mm a');
  static final _apiTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  String _formatTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '–';
    try {
      final parsed = _apiTimeFormat.parse(raw.trim());
      return _displayTimeFormat.format(parsed);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (selected) ...[
            Material(
              color: Colors.transparent,
              child: Container(
                width: 236,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _detailRow('Arrival Time:', _formatTime(stop.arrivalTime)),
                    const SizedBox(height: 4),
                    _detailRow(
                      'Departure Time:',
                      _formatTime(stop.departureTime),
                    ),
                    const SizedBox(height: 4),
                    _detailRow('Duration:', stop.duration ?? '–'),
                    const SizedBox(height: 4),
                    _detailRow(
                      'Latlong:',
                      '${stop.latitude.toStringAsFixed(6)}, ${stop.longitude.toStringAsFixed(6)}',
                      valueColor: const Color(0xFF009FE3),
                    ),
                    const SizedBox(height: 4),
                    _detailRow(
                      'Address:',
                      (stop.address?.trim().isNotEmpty ?? false)
                          ? ReverseGeocodeService.withoutPincode(stop.address)
                          : 'Address unavailable',
                      maxLines: 2,
                    ),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        Icons.near_me,
                        size: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!cardOnly) const SizedBox(height: 4),
          ],
          if (!cardOnly)
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    Color? valueColor,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: valueColor ?? Colors.black87,
              fontWeight: valueColor != null
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
