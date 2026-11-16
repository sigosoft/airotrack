import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../../Utils/app_colors.dart';
import '../../../../widgets/map_widget.dart';
import '../../../widgets/vehicle_details_dialog.dart';
import '../../home/controllers/home_controller.dart';
import '../controllers/location_controller.dart';

class LocationView extends StatefulWidget {
  const LocationView({super.key});

  @override
  State<LocationView> createState() => _LocationViewState();
}

class _LocationViewState extends State<LocationView> {
  final LocationController controller = Get.find<LocationController>();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    controller.attachMap(_mapController);
  }

  @override
  void dispose() {
    controller.detachMap(_mapController);
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = math.max(45.0, MediaQuery.of(context).padding.top + 10);
    return Scaffold(
      body: Stack(
        children: [
          Obx(() {
            final selectedId = controller.selectedId.value;
            final placements =
                controller.markerPlacements(controller.zoomStep.value);
            // The marker holding the selected vehicle draws last, on top.
            placements.sort((a, b) =>
                (a.vehicles.any((v) => v.id == selectedId) ? 1 : 0) -
                (b.vehicles.any((v) => v.id == selectedId) ? 1 : 0));
            return AiroMapWidget(
              mapController: _mapController,
              mapStyle: controller.mapStyle.value,
              traffic: controller.trafficEnabled.value,
              initialCenter: controller.lastCenter,
              initialZoom: controller.lastZoom,
              onMapReady: controller.onMapReady,
              onPositionChanged: controller.onPositionChanged,
              markers: [
                for (final p in placements)
                  if (p.vehicles.length > 1 && controller.atMaxZoom)
                    _stackMarker(p.vehicles, selectedId, p.point)
                  else
                    _groupMarker(p.vehicles, selectedId, at: p.point),
              ],
            );
          }),
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Markers
  // ---------------------------------------------------------------------

  /// One marker per group. A group of several vehicles shows the first (or
  /// selected) plate with a "+N" badge; tapping it lists them to pick from.
  Marker _groupMarker(List<Vehicle> group, int? selectedId, {LatLng? at}) {
    final v = group.first;
    final selected = group.any((g) => g.id == selectedId);
    final extra = group.length - 1;
    return Marker(
      point: at ?? LatLng(v.latitude!, v.longitude!),
      // Wide enough for full plate names like "TCP TSAIRO MICRA".
      width: 180,
      height: 38 + 52 * controller.iconScale,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryBlue : Colors.black,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      v.plateNumber.isEmpty ? '—' : v.plateNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (extra > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+$extra',
                        style: TextStyle(
                          color: selected
                              ? AppColors.primaryBlue
                              : Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Image.asset(
              _statusCarImage(v.status),
              width: (selected ? 52 : 44) * controller.iconScale,
              height: (selected ? 52 : 44) * controller.iconScale,
            ),
          ],
        ),
      ),
    );
  }

  /// Cars reporting the same spot, at the closest zoom: one name label per
  /// car (each opens that car), and the cars overlapped like cards right on
  /// the real location.
  Marker _stackMarker(List<Vehicle> group, int? selectedId, LatLng point) {
    const labelH = 30.0;
    const gap = 4.0;
    const step = 18.0; // how far each car sits from the one before it
    final car = 44 * controller.iconScale;
    final carsW = car + step * (group.length - 1);
    final labelsH = group.length * (labelH + gap);
    // Same empty height below as the labels above, so the cars sit centred
    // on the real spot.
    return Marker(
      point: point,
      width: math.max(180, carsW),
      height: labelsH * 2 + car,
      child: Column(
        children: [
          for (final v in group)
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openVehicle(v),
                child: _plateLabel(v, selected: v.id == selectedId),
              ),
            ),
          SizedBox(
            width: carsW,
            height: car,
            child: Stack(
              children: [
                for (var i = 0; i < group.length; i++)
                  Positioned(
                    left: i * step,
                    child: GestureDetector(
                      onTap: () => _openVehicle(group[i]),
                      child: Image.asset(
                        _statusCarImage(group[i].status),
                        width: car,
                        height: car,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plateLabel(Vehicle v, {required bool selected}) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryBlue : Colors.black,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        v.plateNumber.isEmpty ? '—' : v.plateNumber,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
