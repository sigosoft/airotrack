import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../controllers/history_controller.dart';
import 'history_circular_control.dart';

class HistoryPlaybackControls extends StatelessWidget {
  final HistoryController controller;

  const HistoryPlaybackControls({Key? key, required this.controller})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Obx(
            () => IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: controller.isPlaying.value
                  ? Image.asset(
                      'lib/Asset/Images/pause_button.png',
                      width: 30,
                      height: 30,
                    )
                  : Image.asset(
                      'lib/Asset/Images/play_button.png',
                      width: 30,
                      height: 30,
                    ),
              onPressed: () {
                if (controller.isPlaying.value) {
                  debugPrint('[History] UI: Pause button tapped');
                  controller.stopMovingMarker();
                } else {
                  debugPrint('[History] UI: Play button tapped');
                  controller.startMovingMarker();
                }
              },
            ),
          ),
          Expanded(
            child: Obx(
              () => Slider(
                value: controller.progress.value.clamp(0.0, 1.0),
                onChanged: (v) => controller.seekToProgress(v),
                activeColor: const Color(0xFF009FE3),
                inactiveColor: Colors.grey.shade200,
              ),
            ),
          ),
          HistoryCircularControl(
            onTap: controller.cyclePlaybackSpeed,
            child: Obx(
              () {
                final label = controller.playbackSpeed.value.replaceAll('X', '');
                return CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFF009FE3),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          HistoryCircularControl(
            onTap: () {
              controller.seekToProgress(0.0);
              controller.startMovingMarker();
            },
            child: Image.asset(
              'lib/Asset/Icons/repeat.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
              color: const Color(0xFF009FE3),
            ),
          ),
          const SizedBox(width: 8),
          HistoryCircularControl(
            child: Image.asset(
              'lib/Asset/Icons/mapfromto.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
