import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:airotrack/Utils/app_colors.dart';
import '../../controllers/history_controller.dart';
import 'history_icon_stat.dart';
import 'history_playback_controls.dart';
import 'history_segment_item.dart';

class HistoryBottomSheet extends StatelessWidget {
  final ScrollController scrollController;
  final HistoryController controller;

  const HistoryBottomSheet({
    Key? key,
    required this.scrollController,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final horizontalPadding = width * 0.04;
    final verticalSpacing = height * 0.02;
    final cornerRadius = width * 0.09;
    final handleWidth = width * 0.13;
    final handleHeight = height * 0.005;
    final iconSize = width * 0.055;
    final smallSpacing = width * 0.02;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(cornerRadius),
          topRight: Radius.circular(cornerRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: width * 0.025,
            offset: Offset(0, -height * 0.006),
          ),
        ],
      ),
      child: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primaryBlue),
          );
        }
        final history = controller.historyPreviewItems;
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SizedBox(height: height * 0.015),
                  Center(
                    child: Container(
                      width: handleWidth,
                      height: handleHeight,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(width * 0.005),
                      ),
                    ),
                  ),
                  SizedBox(height: height * 0.018),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => controller.pickFromDate(context),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Image.asset(
                                'lib/Asset/Icons/Calender.png',
                                width: iconSize,
                                height: iconSize,
                                color: Colors.red,
                              ),
                              SizedBox(width: smallSpacing),
                              Obx(
                                () => Text(
                                  "From: ${controller.fromDate.value}",
                                  style: TextStyle(
                                    fontSize: width * 0.028,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Obx(
                          () => Text(
                            controller.vehicleId.value,
                            style: TextStyle(
                              color: const Color(0xFF009FE3),
                              fontWeight: FontWeight.bold,
                              fontSize: width * 0.022,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => controller.pickToDate(context),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Image.asset(
                                'lib/Asset/Icons/Calender.png',
                                width: iconSize,
                                height: iconSize,
                                color: Colors.red,
                              ),
                              SizedBox(width: smallSpacing),
                              Obx(
                                () => Text(
                                  "To: ${controller.toDate.value}",
                                  style: TextStyle(
                                    fontSize: width * 0.028,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: verticalSpacing),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        HistoryIconStat(
                          assetPath: 'lib/Asset/Icons/KmPh.png',
                          value: controller.currentSpeed,
                          iconColor: Colors.red,
                        ),
                        HistoryIconStat(
                          assetPath: 'lib/Asset/Icons/time duration.png',
                          value: controller.duration,
                          iconColor: Colors.red,
                        ),
                        HistoryIconStat(
                          assetPath: 'lib/Asset/Icons/Distance.png',
                          value: controller.totalDistance,
                          iconColor: Colors.red,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: verticalSpacing),
                  HistoryPlaybackControls(controller: controller),
                  SizedBox(height: verticalSpacing),
                ],
              ),
            ),
            if (history.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: height * 0.03),
                  child: Text(
                    "No history for selected dates",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: width * 0.035,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = history[index];
                    final isStop = item.isStopped == true;
                    return Padding(
                      padding: EdgeInsets.only(bottom: height * 0.018),
                      child: HistorySegmentItem(
                        distance: "0 Km",
                        status: isStop ? "Stop" : "Moving",
                        statusColor: isStop
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                        statusTextColor: isStop ? Colors.red : Colors.green,
                        maxSpeed: "${item.speed ?? '0'} Kmph",
                        start: item.deviceTime ?? "-",
                        duration: "-",
                        end: item.deviceTime ?? "-",
                      ),
                    );
                  }, childCount: history.length),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: height * 0.12)),
          ],
        );
      }),
    );
  }
}
