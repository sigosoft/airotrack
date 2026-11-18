import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../Utils/app_colors.dart';
import '../../../widgets/vehicle_details_dialog.dart';
import '../../home/controllers/home_controller.dart';
import '../controllers/location_controller.dart';
import 'location_marker_icons.dart';

class LocationView extends StatefulWidget {
  const LocationView({super.key});

  @override
  State<LocationView> createState() => _LocationViewState();
}

class _LocationViewState extends State<LocationView> {
  final LocationController controller = Get.find<LocationController>();
  LocationMarkerIcons? _icons;
  Set<Marker> _markers = {};
  int _markerGen = 0;

  /// Closest zoom: where each car and name label is drawn, to tell which
  /// one a finger touched. Google's own tap areas for these marker pictures
  /// don't match what's drawn, so a tap could open the car next to it.
  List<_HitTarget> _hitTargets = const [];
  Offset? _lastPointer;
  final List<Worker> _workers = [];

  @override
  void initState() {
    super.initState();
    final home = Get.find<HomeController>();
    _workers.addAll([
      ever(controller.zoomStep, (_) => _rebuildMarkers()),
      ever(controller.selectedId, (_) => _rebuildMarkers()),
      ever(controller.statusFilter, (_) => _rebuildMarkers()),
      ever(home.allVehicles, (_) => _rebuildMarkers()),
      // Cars moved onto the road: redraw once a batch has arrived.
      debounce(
        controller.roadPointsVersion,
        (_) => _rebuildMarkers(),
        time: const Duration(milliseconds: 300),
      ),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_icons == null) {
      _icons = LocationMarkerIcons(MediaQuery.of(context).devicePixelRatio);
      _rebuildMarkers();
    }
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    controller.onMapDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = math.max(45.0, MediaQuery.of(context).padding.top + 10);
    return Scaffold(
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              controller.mapSize = constraints.biggest;
              return Listener(
                // Any finger on the map stops following the selected car.
                onPointerDown: (e) {
                  _lastPointer = e.localPosition;
                  controller.onUserTouch();
                },
                child: Obx(
                  () => GoogleMap(
                    initialCameraPosition: controller.initialCamera,
                    mapType: controller.mapType.value,
                    trafficEnabled: controller.trafficEnabled.value,
                    onMapCreated: controller.onMapCreated,
                    onCameraMove: controller.onCameraMove,
                    markers: _markers,
                    minMaxZoomPreference: const MinMaxZoomPreference(
                      LocationController.minZoom,
                      LocationController.maxZoom,
                    ),
                    // The screen has its own buttons for these.
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: topInset,
            left: 15,
            child: Column(
              children: [
                _buildFloatingButton(
                  'lib/Asset/Icons/map.png',
                  onTap: controller.cycleMapStyle,
                ),
                const SizedBox(height: 10),
                // Live traffic on/off, as on Track; blue border while on.
                Obx(
                  () => _buildFloatingButton(
                    'lib/Asset/Icons/Traffic.png',
                    onTap: controller.toggleTraffic,
                    active: controller.trafficEnabled.value,
                    tint: false,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: topInset,
            right: 15,
            child: Column(
              children: [
                Obx(
                  () => _buildFloatingButton(
                    'lib/Asset/Icons/Filters.png',
                    onTap: () => _showFilterSheet(context),
                    badge: controller.statusFilter.value != 'All',
                  ),
                ),
                const SizedBox(height: 10),
                // Zoom.png tints to a solid dot, so use a Material icon.
                _buildFloatingButton(
                  null,
                  icon: Icons.zoom_out_map,
                  onTap: controller.fitAll,
                ),
                const SizedBox(height: 10),
                _buildFloatingButton(
                  'lib/Asset/Icons/zoomin.png',
                  onTap: controller.zoomIn,
                ),
                const SizedBox(height: 10),
                _buildFloatingButton(
                  'lib/Asset/Icons/zoomout.png',
                  onTap: controller.zoomOut,
                ),
              ],
            ),
          ),
          Positioned(
            top: topInset + 4,
            left: 60,
            right: 60,
            child: Center(child: Obx(_buildStatusChip)),
          ),
          // Left / right: previous or next vehicle; the map moves to it.
          Obx(() {
            if (controller.mapVehicles.isEmpty) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.05),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildArrowButton(
                        Icons.chevron_left,
                        () => controller.selectAdjacent(-1),
                      ),
                      _buildArrowButton(
                        Icons.chevron_right,
                        () => controller.selectAdjacent(1),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Translucent grey circle at the screen edge with a white chevron, so
  /// the map stays visible behind it.
  Widget _buildArrowButton(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, size: 34, color: Colors.white),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Markers
  // ---------------------------------------------------------------------

  /// Redraws the Google markers for the current zoom, filter, selection and
  /// vehicles. Only the latest call's result is shown.
  Future<void> _rebuildMarkers() async {
    final icons = _icons;
    if (icons == null) return;
    // A refresh first empties the vehicle list for a moment; keep the
    // markers until the new list arrives.
    if (Get.find<HomeController>().allVehicles.isEmpty && _markers.isNotEmpty) {
      return;
    }
    final gen = ++_markerGen;
    final selectedId = controller.selectedId.value;
    final atMax = controller.atMaxZoom;
    final placements = controller.markerPlacements(controller.zoomStep.value);
    final out = <Marker>{};
    final targets = <_HitTarget>[];
    try {
      for (final p in placements) {
        if (atMax) {
          out.addAll(await _topCarMarkers(icons, p, selectedId, targets));
        } else {
          out.add(await _groupMarker(icons, p, selectedId));
        }
      }
    } catch (e) {
      debugPrint('[Location] markers skipped: $e');
      return;
    }
    if (!mounted || gen != _markerGen) return;
    setState(() {
      _markers = out;
      _hitTargets = targets;
    });
  }

  /// A closest-zoom car or label was tapped: open the car whose car or name
  /// is under the finger (nearest one if none is), else [fallback].
  void _openTapped(Vehicle fallback) {
    final finger = _lastPointer;
    final center = controller.lastCenter;
    if (finger == null || center == null || _hitTargets.isEmpty) {
      _openVehicle(fallback);
      return;
    }
    final scale = 256 * math.pow(2, controller.lastZoom);
    Offset world(LatLng p) {
      final lat = p.latitude * math.pi / 180;
      return Offset(
        (p.longitude + 180) / 360 * scale,
        (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) /
            2 *
            scale,
      );
    }

    final origin = world(center) -
        Offset(controller.mapSize.width / 2, controller.mapSize.height / 2);
    _HitTarget? best;
    var bestDist = double.infinity;
    for (final t in _hitTargets) {
      final at = world(t.point) - origin;
      final rect = Rect.fromLTWH(
        at.dx - t.anchor.dx * t.size.width,
        at.dy - t.anchor.dy * t.size.height,
        t.size.width,
        t.size.height,
      );
      final d = rect.contains(finger) ? 0.0 : (rect.center - finger).distance;
      if (d < bestDist) {
        bestDist = d;
        best = t;
      }
    }
    _openVehicle(best?.vehicle ?? fallback);
  }

  /// One marker per group. A group of several vehicles shows the first (or
  /// selected) plate with a "+N" badge; tapping it zooms in on them.
  Future<Marker> _groupMarker(
    LocationMarkerIcons icons,
    MarkerPlacement p,
    int? selectedId,
  ) async {
    final group = p.vehicles;
    final v = group.first;
    final selected = group.any((g) => g.id == selectedId);
    final extra = group.length - 1;
    final icon = await icons.group(
      plate: v.plateNumber,
      extra: extra,
      selected: selected,
      carAsset: _statusCarImage(v.status),
      carSize: (selected ? 52 : 44) * controller.iconScale,
    );
    return Marker(
      markerId: MarkerId('g-${v.id}'),
      position: p.point,
      icon: icon.descriptor,
      anchor: icon.anchor(),
      zIndexInt: selected ? 2 : 1,
      consumeTapEvents: true,
      onTap: () {
        if (extra == 0) {
          _openVehicle(v);
        } else if (controller.atMaxZoom) {
          _showGroupSheet(group);
        } else {
          // Zoom in on them; at the closest zoom each gets its own marker.
          controller.zoomToGroup(group);
        }
      },
    );
  }

  /// Closest zoom: cars seen from above, turned the way they face, side by
  /// side on their real spot (several trackers can report the very same
  /// point), each with its own small name label above. Tap a car or its
  /// name to open it.
  Future<List<Marker>> _topCarMarkers(
    LocationMarkerIcons icons,
    MarkerPlacement p,
    int? selectedId,
    List<_HitTarget> targets,
  ) async {
    // Fixed order, so selecting a car doesn't make the cars swap places.
    final group = [...p.vehicles]..sort((a, b) => a.id.compareTo(b.id));
    final car = 48 * controller.iconScale;
    final step = car * 0.55; // close together, like cars parked side by side
    const labelGap = 3.0;
    const labelRow = 20.0 + labelGap;
    final n = group.length;
    final out = <Marker>[];
    for (var i = 0; i < n; i++) {
      final v = group[i];
      final selected = v.id == selectedId;
      final dx = (i - (n - 1) / 2) * step;
      final carIcon = await icons.topCar(
        color: _statusColor(v.status),
        course: v.course ?? 0,
        size: car,
      );
      final label = await icons.label(plate: v.plateNumber, selected: selected);
      // Leftmost car's name on top, so every name stays readable.
      final above = car / 2 + labelGap + (n - 1 - i) * labelRow;
      // Each car and label gets its own map position, moved by screen px at
      // this zoom.
      final carAt = controller.offsetPx(p.point, dx, 0);
      final labelAt = controller.offsetPx(p.point, dx, -above);
      targets
        ..add(_HitTarget(v, carAt, carIcon.size, carIcon.anchor()))
        ..add(_HitTarget(v, labelAt, label.size, label.anchor()));
      out
        ..add(Marker(
          markerId: MarkerId('c-${v.id}'),
          position: carAt,
          icon: carIcon.descriptor,
          anchor: carIcon.anchor(),
          zIndexInt: 1,
          consumeTapEvents: true,
          onTap: () => _openTapped(v),
        ))
        ..add(Marker(
          markerId: MarkerId('l-${v.id}'),
          position: labelAt,
          icon: label.descriptor,
          anchor: label.anchor(),
          zIndexInt: selected ? 4 : 3,
          consumeTapEvents: true,
          onTap: () => _openTapped(v),
        ));
    }
    return out;
  }

  void _openVehicle(Vehicle v) {
    controller.selectVehicle(v);
    showVehicleDetailsDialog(context, v);
  }

  /// Vehicles parked at (almost) the same spot: pick one from a list.
  void _showGroupSheet(List<Vehicle> group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      '${group.length} vehicles here',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final v in group)
                          ListTile(
                            dense: true,
                            leading: Image.asset(
                              _statusCarImage(v.status),
                              width: 40,
                              height: 40,
                            ),
                            title: Text(
                              v.plateNumber.isEmpty ? '—' : v.plateNumber,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _statusColor(v.status),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(v.statusLabel),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _openVehicle(v);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Car picture for each status, matching Home.
  String _statusCarImage(String status) {
    switch (status) {
      case 'Running':
        return 'lib/Asset/Images/Green right Car.png';
      case 'Idle':
        return 'lib/Asset/Images/Idle_yellow_rightcar.png';
      case 'Expired':
        return 'lib/Asset/Images/Expired_GlossyOrange_rightcar.png';
      case 'Inactive':
        return 'lib/Asset/Images/Inactive_blue_rightcar.png';
      case 'No data':
        return 'lib/Asset/Images/No data_grey_rightcar.png';
      default:
        return 'lib/Asset/Images/Red right Car.png';
    }
  }

  /// Same colours as the status cards on Home.
  Color _statusColor(String status) {
    switch (status) {
      case 'Running':
        return const Color(0xFF00C853);
      case 'Idle':
        return const Color(0xFFFFD600);
      case 'Expired':
        return const Color(0xFFFF9100);
      case 'Inactive':
        return Colors.blue;
      case 'No data':
        return Colors.grey;
      case 'All':
        return AppColors.primaryBlue;
      default:
        return const Color(0xFFFF3D00);
    }
  }

  /// Loading / empty notice at the top of the map; nothing when vehicles show.
  Widget _buildStatusChip() {
    final String? text;
    if (controller.mapVehicles.isNotEmpty) {
      text = null;
    } else if (controller.isLoading) {
      text = 'Loading vehicles…';
    } else if (controller.statusFilter.value == 'All') {
      text = 'No vehicles with a location';
    } else {
      text = 'No ${controller.statusFilter.value} vehicles';
    }
    if (text == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Filter sheet
  // ---------------------------------------------------------------------

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Show vehicles',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                for (final filter in LocationController.statusFilters)
                  Obx(() {
                    final active = controller.statusFilter.value == filter;
                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _statusColor(filter),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${controller.countFor(filter)}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            active
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color: active
                                ? AppColors.primaryBlue
                                : Colors.black26,
                          ),
                        ],
                      ),
                      onTap: () {
                        controller.setFilter(filter);
                        Navigator.pop(sheetContext);
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Buttons
  // ---------------------------------------------------------------------

  BoxDecoration get _buttonDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _buildFloatingButton(
    String? iconPath, {
    IconData? icon,
    required VoidCallback onTap,
    bool badge = false,
    bool active = false,
    bool tint = true,
  }) {
    return Container(
      width: 35,
      height: 35,
      decoration: active
          ? _buttonDecoration.copyWith(
              border: Border.all(color: AppColors.primaryBlue, width: 2),
            )
          : _buttonDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Stack(
            children: [
              Center(
                child: iconPath != null
                    ? Image.asset(
                        iconPath,
                        width: 20,
                        height: 20,
                        color: tint ? Colors.black : null,
                      )
                    : Icon(icon, size: 22, color: Colors.black),
              ),
              if (badge)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


}

/// A car or name label drawn at the closest zoom, for finding what a finger
/// touched.
class _HitTarget {
  const _HitTarget(this.vehicle, this.point, this.size, this.anchor);

  final Vehicle vehicle;
  final LatLng point;
  final Size size;
  final Offset anchor;
}
