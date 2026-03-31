import 'package:flutter/material.dart';
import '../../../../routes/app_routes.dart';
import 'package:get/get.dart';
import '../../controllers/history_controller.dart';

class HistoryBottomNavBar extends StatelessWidget {
  const HistoryBottomNavBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final historyController = Get.find<HistoryController>();
    final imei = historyController.activeImei;
    final vehicle = historyController.vehicleId.value;
    return Container(
      height: height * 0.1,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          HistoryNavItem(
            assetPath: 'lib/Asset/Icons/Location.png',
            label: "Track",
            isSelected: false,
            onTap: () => Get.offNamed(
              Routes.TRACK,
              parameters: {
                'imei': imei,
                'vehicleId': vehicle,
              },
            ),
          ),
          HistoryNavItem(
            assetPath: 'lib/Asset/Icons/history.png',
            label: "History",
            isSelected: true,
            onTap: () {
              // Current page, already active
            },
          ),
          HistoryNavItem(
            assetPath: 'lib/Asset/Icons/notification.png',
            label: "Alerts",
            isSelected: false,
            onTap: () => Get.offNamed(Routes.ALERTS),
          ),
          HistoryNavItem(
            assetPath: 'lib/Asset/Icons/statistics.png',
            label: "Statistics",
            isSelected: false,
            onTap: () => Get.toNamed(Routes.STATISTICS),
          ),
        ],
      ),
    );
  }
}

class HistoryNavItem extends StatelessWidget {
  final String assetPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const HistoryNavItem({
    Key? key,
    required this.assetPath,
    required this.label,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              assetPath,
              width: 25,
              height: 25,
              color: isSelected ? const Color(0xFF009FE3) : Colors.black,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF009FE3) : Colors.black,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
