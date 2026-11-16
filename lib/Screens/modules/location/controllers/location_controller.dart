import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../../widgets/map_widget.dart';
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
  static const double _maxZoom = 19;

  final statusFilter = 'All'.obs;
  /// Public OpenStreetMap tiles stay grey on devices (blocked), so the tab
  /// uses Mapbox; the widget still falls back to OSM without a token.
  /// Starts on General Settings → Map Type.
  final mapStyle = _settingsStyle().obs;

  static AiroMapStyle _settingsStyle() {
    switch (AppSettings.maybe?.mapType.value) {
      case AppMapType.satellite:
        return AiroMapStyle.mapboxSatellite;
      case AppMapType.terrain:
        return AiroMapStyle.mapboxOutdoors;
      default:
        return AiroMapStyle.mapboxStreets;
    }
  }

  /// Traffic button: live traffic colours on the roads.
  final trafficEnabled = false.obs;

  void toggleTraffic() => trafficEnabled.toggle();

  /// General Settings → Vehicle Icon Size.
  double get iconScale => AppSettings.maybe?.iconScale ?? 1.0;
  final selectedId = RxnInt();

  HomeController get _home => Get.find<HomeController>();

  MapController? _map;
  bool _mapReady = false;
  bool _fittedOnce = false;

  /// Camera follows the selected vehicle until the user drags the map.
  bool _following = false;

  /// Last camera, so switching tabs and back keeps the view.
  LatLng? lastCenter;
  double lastZoom = 13;

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
  // Map lifecycle (the view owns the MapController)
  // ---------------------------------------------------------------------

  void attachMap(MapController controller) {
    _map = controller;
    _mapReady = false;
  }

  void detachMap(MapController controller) {
    if (identical(_map, controller)) {
      _map = null;
      _mapReady = false;
    }
  }

  void onMapReady() {
    _mapReady = true;
    // Fitting inside onMapReady moves the camera before the tile layer has
    // loaded its first view, and the new view stays grey until a gesture.
    // Fit one frame later instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_fittedOnce) fitAll();
    });
  }

  /// Zoom rounded to half steps. Markers that would overlap at this zoom are
  /// grouped, so the view rebuilds markers only when this changes.
  final zoomStep = 13.0.obs;

  void onPositionChanged(MapCamera camera, bool hasGesture) {
    lastCenter = camera.center;
    lastZoom = camera.zoom;
    final step = (camera.zoom * 2).round() / 2;
    if (zoomStep.value != step) zoomStep.value = step;
    if (hasGesture) _following = false;
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

  double get _currentZoom {
    try {
      return _map?.camera.zoom ?? lastZoom;
    } catch (_) {
      return lastZoom;
    }
  }

  void _moveTo(Vehicle v, {double? zoom}) {
    if (!_mapReady || _map == null) return;
    try {
      _map!.move(_pointOf(v), zoom ?? _currentZoom);
    } catch (e) {
      debugPrint('[Location] move skipped: $e');
    }
  }

  /// Shows every vehicle in the current filter.
  void fitAll() {
    if (!_mapReady || _map == null) return;
    final points = mapVehicles.map(_pointOf).toList();
    if (points.isEmpty) return;
    _following = false;
    _fittedOnce = true;
    try {
      final bounds = LatLngBounds.fromPoints(points);
      final zeroArea = bounds.southWest == bounds.northEast;
      if (points.length == 1 || zeroArea) {
        _map!.move(bounds.center, _vehicleZoom);
      } else {
        _map!.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            // Clear of the side buttons, the top buttons (plate labels sit
            // above each point) and the bottom navigation bar.
            padding: const EdgeInsets.fromLTRB(80, 200, 90, 200),
            maxZoom: 16,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Location] fit skipped: $e');
    }
  }

  void zoomIn() => _zoomBy(1);

  void zoomOut() => _zoomBy(-1);

  void _zoomBy(double delta) {
    if (!_mapReady || _map == null) return;
    try {
      final camera = _map!.camera;
      _map!.move(
        camera.center,
        (camera.zoom + delta).clamp(_minZoom, _maxZoom).toDouble(),
      );
    } catch (e) {
      debugPrint('[Location] zoom skipped: $e');
    }
  }

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

  /// Map button: streets ↔ satellite.
  void cycleMapStyle() {
    // Traffic uses its own street map; picking a style turns it off so the
    // chosen style actually shows.
    trafficEnabled.value = false;
    // Streets → satellite → terrain → streets.
    mapStyle.value = switch (mapStyle.value) {
      AiroMapStyle.mapboxStreets => AiroMapStyle.mapboxSatellite,
      AiroMapStyle.mapboxSatellite => AiroMapStyle.mapboxOutdoors,
      _ => AiroMapStyle.mapboxStreets,
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
