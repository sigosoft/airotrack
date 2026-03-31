import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/history_controller.dart';
import '../../../routes/app_routes.dart';
import 'Widgets/history_map_layer.dart';
import 'Widgets/history_side_button.dart';
import 'Widgets/history_bottom_sheet.dart';
import 'Widgets/history_expand_fab.dart';
import 'Widgets/history_bottom_nav_bar.dart';

class HistoryView extends GetView<HistoryController> {
  const HistoryView({Key? key, String? imei})
    : imei = imei ?? '',
      super(key: key);
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
            onPressed: () => Get.toNamed(Routes.TRACK),
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
                      polylinePoints: controller.polylinePoints,
                      markerPoints: controller.mapMarkerPoints,
                      movingMarkerPosition:
                          controller.movingMarkerPosition.value,
                      movingMarkerBearing: controller.movingMarkerBearing.value,
                      isFollowCameraEnabled:
                          controller.isFollowCameraEnabled.value,
                      isPlaybackActive: controller.isPlaying.value,
                      onManualFollowDisable: controller.disableFollowCamera,
                    ),
                  ),
                  Positioned(
                    top: topPadding,
                    left: horizontalPadding,
                    child: HistorySideButton(
                      assetPath: 'lib/Asset/Icons/map.png',
                    ),
                  ),
                  Positioned(
                    top: maxHeight * 0.12,
                    right: horizontalPadding,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: controller.enableFollowCamera,
                          child: HistorySideButton(
                            assetPath: 'lib/Asset/Icons/Locations.png',
                          ),
                        ),
                        SizedBox(height: sideBtnSpacing),
                        HistorySideButton(text: "P", textColor: Colors.green),
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
                        HistorySideButton(
                          assetPath: 'lib/Asset/Icons/zoomin.png',
                        ),
                        SizedBox(height: sideBtnSpacing),
                        HistorySideButton(
                          assetPath: 'lib/Asset/Icons/zoomout.png',
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
}
