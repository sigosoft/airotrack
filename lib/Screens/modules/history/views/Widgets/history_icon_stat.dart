import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HistoryIconStat extends StatelessWidget {
  final String assetPath;
  final RxString value;
  final Color iconColor;

  const HistoryIconStat({
    Key? key,
    required this.assetPath,
    required this.value,
    required this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(assetPath, width: 22, height: 22, color: iconColor),
        const SizedBox(width: 8),
        Obx(
          () => Text(
            value.value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
