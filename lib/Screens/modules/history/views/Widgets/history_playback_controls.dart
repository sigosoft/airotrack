import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/history_controller.dart';
import 'history_circular_control.dart';

class HistoryPlaybackControls extends StatelessWidget {
  final HistoryController controller;

  const HistoryPlaybackControls({
    Key? key,
    required this.controller,
  }) : super(key: key);

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
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Image.asset(
              'lib/Asset/Icons/Play.png',
              width: 30,
              height: 30,
            ),
            onPressed: () {},
          ),
          Expanded(
            child: Obx(
              () => Slider(
                value: controller.progress.value,
                onChanged: (v) => controller.progress.value = v,
                activeColor: const Color(0xFF009FE3),
                inactiveColor: Colors.grey.shade200,
              ),
            ),
          ),
          HistoryCircularControl(
            child: Image.asset(
              'lib/Asset/Icons/1x.png',
              width: 35,
              height: 35,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 8),
          HistoryCircularControl(
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
