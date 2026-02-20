import 'package:flutter/material.dart';
import '../../../../routes/app_routes.dart';
import 'package:get/get.dart';

class HistoryBottomNavBar extends StatelessWidget {
  const HistoryBottomNavBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
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
            onTap: () => Get.toNamed(Routes.TRACK),
          ),
          HistoryNavItem(
            assetPath: 'lib/Asset/Icons/history.png',
            label: "History",
            isSelected: true,
            onTap: () {},
          ),
          HistoryNavItem(
            assetPath: 'lib/Asset/Icons/notification.png',
            label: "Alerts",
            isSelected: false,
            onTap: () => Get.toNamed(Routes.ALERTS),
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
