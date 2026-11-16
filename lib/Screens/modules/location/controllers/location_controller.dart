import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../Services/AppSettings.dart';
import '../../home/controllers/home_controller.dart';

/// Location tab: every vehicle on one map.
///
/// Vehicles come from [HomeController.allVehicles] (the `home` API), which
/// refreshes itself every few seconds while this tab is open, so the markers
/// move without a separate request.
class LocationController extends GetxController {
  /// Filter choices, in the order the sheet shows them.
  static const List<String> statusFilters = [
    'All',
    'Running',
    'Idle',
    'Stopped',
    'Expired',
    'Inactive',
    'No data',
  ];

  static const double _vehicleZoom = 15;
  static const double _minZoom = 3;
  static const double _maxZoom = 20;
  static const double minZoom = _minZoom;
  static const double maxZoom = _maxZoom;

  final statusFilter = 'All'.obs;
  /// Google map type. Starts on General Settings → Map Type.
  final mapType = _settingsMapType().obs;

  static MapType _settingsMapType() {
    switch (AppSettings.maybe?.mapType.value) {
      case AppMapType.satellite:
        return MapType.hybrid;
      case AppMapType.terrain:
        return MapType.terrain;
      default:
        return MapType.normal;
    }
  }

  /// Traffic button: live traffic colours on the roads.
  final trafficEnabled = false.obs;

  void toggleTraffic() => trafficEnabled.toggle();

  /// General Settings → Vehicle Icon Size.
  double get iconScale => AppSettings.maybe?.iconScale ?? 1.0;
  final selectedId = RxnInt();

  HomeController get _home => Get.find<HomeController>();

  GoogleMapController? _map;
  bool _mapReady = false;
  bool _fittedOnce = false;

  /// Camera follows the selected vehicle until the user drags the map.
  bool _following = false;

  /// Last camera, so switching tabs and back keeps the view.
  LatLng? lastCenter;
  double lastZoom = 13;

  /// Size of the map on screen, for fitting vehicles into view.
  Size mapSize = Size.zero;

  final List<Worker> _workers = [];

  bool get isLoading => _home.isLoading.value;

  /// Vehicles that can be drawn: valid coordinates and matching the filter.
  List<Vehicle> get mapVehicles {
    final filter = statusFilter.value;
    return _home.allVehicles
        .where((v) => v.hasValidCoordinates)
        .where((v) => filter == 'All' || v.status == filter)
        .toList();
  }

  Vehicle? get selectedVehicle {
    final id = selectedId.value;
    if (id == null) return null;
    return mapVehicles.firstWhereOrNull((v) => v.id == id);
  }

  /// Vehicles per filter choice (with a location), for the filter sheet.
  int countFor(String filter) => _home.allVehicles
      .where((v) => v.hasValidCoordinates)
      .where((v) => filter == 'All' || v.status == filter)
      .length;

  @override
  void onInit() {
    super.onInit();
    _workers.add(ever(_home.allVehicles, (_) => _onVehiclesChanged()));
  }

  // ---------------------------------------------------------------------
  // Map lifecycle
  // ---------------------------------------------------------------------

  /// Where the map opens: the last view, else the first vehicle.
  CameraPosition get initialCamera {
    final first = mapVehicles.firstOrNull;
    return CameraPosition(
      target: lastCenter ??
          (first != null ? _pointOf(first) : const LatLng(11.8745, 75.3704)),
      zoom: lastZoom,
    );
  }

  void onMapCreated(GoogleMapController controller) {
    _map = controller;
    _mapReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_fittedOnce) fitAll();
    });
  }

  /// The map left the screen (tab switched); its controller is gone.
  void onMapDisposed() {
    _map = null;
    _mapReady = false;
  }

  /// Zoom rounded to half steps. Markers that would overlap at this zoom are
  /// grouped, so the view rebuilds markers only when this changes.
  final zoomStep = 13.0.obs;

  void onCameraMove(CameraPosition camera) {
    lastCenter = camera.target;
    lastZoom = camera.zoom;
    final step = (camera.zoom * 2).round() / 2;
    if (zoomStep.value != step) zoomStep.value = step;
  }

  /// A finger touched the map: stop following the selected vehicle.
  void onUserTouch() => _following = false;

  /// True at the closest zoom the map allows.
  bool get atMaxZoom => zoomStep.value >= _maxZoom - 0.25;

  /// One marker per group of cars that would cover each other, always at
  /// the group's real location. At the closest zoom a group that still has
  /// several cars (trackers reporting the very same point) is drawn as a
  /// stack there, one tappable label per car.
  List<MarkerPlacement> markerPlacements(double zoom) => [
        for (final g in groupedVehicles(zoom))
          MarkerPlacement(g, LatLng(g.first.latitude!, g.first.longitude!)),
      ];

  /// "+N" marker tapped: zoom in until those cars show one by one.
  void zoomToGroup(List<Vehicle> group) {
    if (!_mapReady || _map == null || group.isEmpty) return;
    _following = false;
    _fit(group.map(_pointOf).toList(), maxZoom: _maxZoom);
  }

  /// Vehicles whose markers would cover each other at [zoom] share one group.
  /// The selected vehicle anchors its group so it is never hidden.
  List<List<Vehicle>> groupedVehicles(double zoom) {
    final vehicles = mapVehicles;
    final selected = selectedId.value;
    vehicles.sort((a, b) => (b.id == selected ? 1 : 0) - (a.id == selected ? 1 : 0));

    // Marker label is up to ~180 px wide and the marker 82 px tall.
    const maxDx = 140.0;
    const maxDy = 60.0;
    final scale = 256 * math.pow(2, zoom);
    Offset px(Vehicle v) {
      final lat = v.latitude! * math.pi / 180;
      final x = (v.longitude! + 180) / 360 * scale;
      final y = (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) /
          2 *
          scale;
      return Offset(x, y);
    }

    final groups = <List<Vehicle>>[];
    final anchors = <Offset>[];
    for (final v in vehicles) {
      final p = px(v);
      final i = anchors.indexWhere(
        (a) => (a.dx - p.dx).abs() < maxDx && (a.dy - p.dy).abs() < maxDy,
      );
      if (i < 0) {
        groups.add([v]);
        anchors.add(p);
      } else {
        groups[i].add(v);
      }
    }
    return groups;
  }

  void _onVehiclesChanged() {
    // RxList.assignAll clears before it adds, so this also fires once with an
    // empty list on every refresh. Ignore that step, or the selection is lost.
    if (_home.allVehicles.isEmpty) return;
    if (!_fittedOnce) {
      fitAll();
      return;
    }
    final selected = selectedVehicle;
    if (selected == null) {
      // The selected vehicle lost its location or left the filter.
      if (selectedId.value != null) selectedId.value = null;
      return;
    }
    if (_following) _moveTo(selected);
  }

  // ---------------------------------------------------------------------
  // Camera
  // ---------------------------------------------------------------------

  LatLng _pointOf(Vehicle v) => LatLng(v.latitude!, v.longitude!);

  double get _currentZoom => lastZoom;

  void _moveTo(Vehicle v, {double? zoom}) {
    _camera(CameraUpdate.newLatLngZoom(_pointOf(v), zoom ?? _currentZoom));
  }

  void _camera(CameraUpdate update) {
    if (!_mapReady || _map == null) return;
    _map!.animateCamera(update).catchError((Object e) {
      debugPrint('[Location] camera skipped: $e');
    });
  }

  /// Centres [points] in the free part of the map (clear of the side
  /// buttons, the top buttons and the bottom bar), zoomed in no closer than
  /// [maxZoom].
  void _fit(List<LatLng> points, {required double maxZoom}) {
    if (points.isEmpty) return;
    const pad = EdgeInsets.fromLTRB(80, 200, 90, 200);
    Offset world(LatLng p) {
      final lat = p.latitude.clamp(-85.0, 85.0) * math.pi / 180;
      return Offset(
        (p.longitude + 180) / 360,
        (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2,
      );
    }

    final w = points.map(world).toList();
    final minX = w.map((o) => o.dx).reduce(math.min);
    final maxX = w.map((o) => o.dx).reduce(math.max);
    final minY = w.map((o) => o.dy).reduce(math.min);
    final maxY = w.map((o) => o.dy).reduce(math.max);
    final freeW = math.max(1.0, mapSize.width - pad.horizontal);
    final freeH = math.max(1.0, mapSize.height - pad.vertical);
    var zoom = maxZoom;
    if (maxX > minX || maxY > minY) {
      final zx = maxX > minX
          ? math.log(freeW / (256 * (maxX - minX))) / math.ln2
          : maxZoom;
      final zy = maxY > minY
          ? math.log(freeH / (256 * (maxY - minY))) / math.ln2
          : maxZoom;
      zoom = math.min(maxZoom, math.min(zx, zy));
    }
    zoom = zoom.clamp(_minZoom, _maxZoom).toDouble();
    // Centre of the points, shifted so they sit in the middle of the free
    // area rather than of the whole map.
    final scale = 256 * math.pow(2, zoom);
    final cx = (minX + maxX) / 2 - (pad.left - pad.right) / 2 / scale;
    final cy = (minY + maxY) / 2 - (pad.top - pad.bottom) / 2 / scale;
    final n = math.pi - 2 * math.pi * cy;
    final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    final lng = cx * 360 - 180;
    _camera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), zoom));
  }

  /// Shows every vehicle in the current filter.
  void fitAll() {
    if (!_mapReady || _map == null) return;
    final points = mapVehicles.map(_pointOf).toList();
    if (points.isEmpty) return;
    _following = false;
    _fittedOnce = true;
    _fit(points, maxZoom: points.length == 1 ? _vehicleZoom : 16);
  }

  void zoomIn() => _zoomBy(1);

  void zoomOut() => _zoomBy(-1);

  void _zoomBy(double delta) => _camera(CameraUpdate.zoomBy(delta));

  // ---------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------

  void selectVehicle(Vehicle v) {
    selectedId.value = v.id;
    _following = true;
    _moveTo(v, zoom: math.max(_currentZoom, _vehicleZoom));
  }

  /// Centre button: the selected vehicle, else the first one.
  void centerOnVehicle() {
    final v = selectedVehicle ?? mapVehicles.firstOrNull;
    if (v != null) selectVehicle(v);
  }

  /// Side arrows: previous (-1) or next (+1) vehicle on the map.
  void selectAdjacent(int direction) {
    final list = mapVehicles;
    if (list.isEmpty) return;
    final index = list.indexWhere((v) => v.id == selectedId.value);
    final next = index < 0
        ? (direction > 0 ? 0 : list.length - 1)
        : (index + direction) % list.length;
    selectVehicle(list[next < 0 ? next + list.length : next]);
  }

  // ---------------------------------------------------------------------
  // Toolbar
  // ---------------------------------------------------------------------

  void setFilter(String filter) {
    if (statusFilter.value == filter) return;
    statusFilter.value = filter;
    if (selectedVehicle == null) selectedId.value = null;
    _fittedOnce = false;
    fitAll();
  }

  /// Map button: default → satellite → terrain → default.
  void cycleMapStyle() {
    mapType.value = switch (mapType.value) {
      MapType.normal => MapType.hybrid,
      MapType.hybrid => MapType.terrain,
      _ => MapType.normal,
    };
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }
}

/// One marker on the Location map: its vehicles (several = "+N") and where.
class MarkerPlacement {
  const MarkerPlacement(this.vehicles, this.point);

  final List<Vehicle> vehicles;
  final LatLng point;
}
