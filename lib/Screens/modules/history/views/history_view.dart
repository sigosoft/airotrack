import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:airotrack/Services/AppSettings.dart';
import '../controllers/history_controller.dart';
import 'Widgets/history_map_layer.dart';
import 'Widgets/history_side_button.dart';
import 'Widgets/history_bottom_sheet.dart';
import 'Widgets/history_expand_fab.dart';
import 'Widgets/history_bottom_nav_bar.dart';
import 'Widgets/history_route_info_card.dart';

class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key, String? imei})
    : imei = imei ?? '';
  final String imei;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final horizontalPadding = width * 0.04;
    final topPadding = height * 0.02;

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.black,
              size: width * 0.055,
            ),
            onPressed: () => Get.back(),
          ),
          title: Obx(
            () => Text(
              controller.vehicleId.value,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: width * 0.045,
              ),
            ),
          ),
          centerTitle: false,
          actions: [
            PopupMenuButton<String>(
              onSelected: controller.updateDateRange,
              itemBuilder: (context) => controller.dateRangeOptions
                  .map(
                    (option) =>
                        PopupMenuItem(value: option, child: Text(option)),
                  )
                  .toList(),
              offset: Offset(0, height * 0.055),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(width * 0.025),
              ),
              child: Container(
                height: height * 0.043,
                padding: EdgeInsets.symmetric(horizontal: width * 0.03),
                margin: EdgeInsets.only(
                  right: horizontalPadding,
                  top: topPadding,
                  bottom: topPadding,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(width * 0.025),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Obx(
                      () => Text(
                        controller.selectedDateRange.value,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: width * 0.035,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    SizedBox(width: width * 0.02),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF009FE3)),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: GetBuilder<HistoryController>(
          didChangeDependencies: (state) {
            final routeImei = (Get.parameters['imei'] ?? '').trim();
            final widgetImei = imei.trim();
            final resolvedImei = widgetImei.isNotEmpty ? widgetImei : routeImei;
            final routeVehicleId = Get.parameters['vehicleId'];
            controller.syncRouteParams(
              imei: resolvedImei,
              vehicleNameOrId: routeVehicleId,
            );
            debugPrint('The emi number is: $resolvedImei');
            // Ensure Today range is applied and history loads if imei arrived late.
            if (resolvedImei.isNotEmpty) {
              if (controller.fromDate.value == '-:-' ||
                  controller.toDate.value == '-:-') {
                controller.updateDateRange('Today');
              } else {
                controller.getHistoryOnce(resolvedImei);
              }
            }
          },
          builder: (controller) => LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight;
              final sheetTopOffset = maxHeight * 0.55;
              double initialSize = (maxHeight - sheetTopOffset) / maxHeight;
              initialSize = initialSize.clamp(0.2, 0.9);
              final sideBtnSpacing = maxHeight * 0.012;
              final fabBottom = maxHeight * 0.14;
              return Stack(
                children: [
                  Obx(
                    () => HistoryMapLayer(
                      initialCenter: controller.initialMapCenter,
                      initialZoom: controller.initialMapZoom,
                      zoomSteps: controller.zoomSteps.value,
                      recenterRequest: controller.recenterRequest.value,
                      onZoomChanged: (z) => controller.mapZoom = z,
                      polylinePoints: controller.polylinePoints,
                      markerPoints: controller.mapMarkerPoints,
                      stopLocations: controller.stopLocations.toList(),
                      selectedStopIndex: controller.selectedStopIndex.value,
                      showStopMarkers: controller.showStopMarkers.value,
                      onStopTap: controller.selectStop,
                      movingMarkerPosition:
                          controller.movingMarkerPosition.value,
                      movingMarkerBearing: controller.movingMarkerBearing.value,
                      isFollowCameraEnabled:
                          controller.isFollowCameraEnabled.value,
                      isPlaybackActive: controller.isPlaying.value,
                      bottomSheetVisible: controller.showBottomSheet.value,
                      bottomSheetFraction: initialSize,
                      onManualFollowDisable: controller.disableFollowCamera,
                      onRouteTap: controller.onRouteTap,
                      routeTapPoint: controller.routeTapInfo.value?.point,
                      mapType: controller.mapType.value,
                      fitRouteRequest: controller.fitRouteRequest.value,
                    ),
                  ),
                  Obx(() {
                    final info = controller.routeTapInfo.value;
                    if (info == null) return const SizedBox.shrink();
                    return Positioned(
                      top: maxHeight * 0.12,
                      left: horizontalPadding,
                      right: width * 0.2,
                      child: HistoryRouteInfoCard(
                        info: info,
                        onClose: controller.clearRouteTap,
                      ),
                    );
                  }),
                  Positioned(
                    top: topPadding,
                    left: horizontalPadding,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showMapTypeSheet(context),
                      child: HistorySideButton(
                        assetPath: 'lib/Asset/Icons/map.png',
                      ),
                    ),
                  ),
                  Positioned(
                    top: maxHeight * 0.12,
                    right: horizontalPadding,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: controller.recenterOnCar,
                          child: HistorySideButton(
                            assetPath: 'lib/Asset/Icons/Locations.png',
                          ),
                        ),
                        SizedBox(height: sideBtnSpacing),
                        GestureDetector(
                          onTap: controller.toggleStopMarkers,
                          child: Obx(
                            () => HistorySideButton(
                              text: 'P',
                              textColor: controller.showStopMarkers.value
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ),
                        SizedBox(height: sideBtnSpacing),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Get.find<HistoryController>().startMovingMarker();
                          },
                          child: HistorySideButton(
                            assetPath: 'lib/Asset/Icons/Arrows.png',
                          ),
                        ),
                        SizedBox(height: sideBtnSpacing),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: controller.zoomIn,
                          child: HistorySideButton(
                            assetPath: 'lib/Asset/Icons/zoomin.png',
                          ),
                        ),
                        SizedBox(height: sideBtnSpacing),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: controller.zoomOut,
                          child: HistorySideButton(
                            assetPath: 'lib/Asset/Icons/zoomout.png',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Obx(
                    () => controller.showBottomSheet.value
                        ? DraggableScrollableSheet(
                            initialChildSize: initialSize,
                            minChildSize: initialSize,
                            maxChildSize: 0.95,
                            snap: true,
                            builder: (context, scrollController) {
                              return HistoryBottomSheet(
                                scrollController: scrollController,
                                controller: controller,
                              );
                            },
                          )
                        : Positioned(
                            bottom: fabBottom,
                            right: horizontalPadding,
                            child: HistoryExpandFab(
                              onTap: () =>
                                  controller.showBottomSheet.value = true,
                            ),
                          ),
                  ),
                  const Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: HistoryBottomNavBar(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Map type picker (top-left map button), same as on Track.
  void _showMapTypeSheet(BuildContext context) {
    const options = [
      (AppMapType.normal, 'Default', Icons.map_outlined),
      (AppMapType.satellite, 'Satellite', Icons.satellite_alt_outlined),
      (AppMapType.terrain, 'Terrain', Icons.terrain_outlined),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Map type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Obx(
                () => Row(
                  children: [
                    for (final (type, label, icon) in options)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            controller.setMapType(type);
                            Navigator.of(sheetContext).pop();
                          },
                          child: _mapTypeOption(
                            label,
                            icon,
                            controller.mapType.value == type,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapTypeOption(String label, IconData icon, bool selected) {
    const blue = Color(0xFF009FE3);
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: selected ? blue.withValues(alpha: 0.08) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? blue : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Icon(icon, size: 30, color: selected ? blue : Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? blue : Colors.black87,
          ),
        ),
      ],
    );
  }
}
