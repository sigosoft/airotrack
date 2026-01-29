import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/reports_controller.dart';
import '../../../routes/app_routes.dart';

class ReportsView extends GetView<ReportsController> {
  const ReportsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Reports',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          // const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 171.05 / 147,
              children: [
                _buildReportCard(
                  'lib/Asset/Icons/Ignition report.png',
                  'Ignition Reports',
                  () {
                    Get.toNamed(Routes.IGNITION_REPORTS);
                  },
                ),
                _buildReportCard(
                  'lib/Asset/Icons/Stoppage report.png',
                  'Stoppage Reports',
                  () {
                    Get.toNamed(Routes.STOPPAGE_REPORTS);
                  },
                ),
                _buildReportCard(
                  'lib/Asset/Icons/Trip report.png',
                  'Trip Reports',
                  () {
                    Get.toNamed(Routes.TRIP_REPORTS);
                  },
                ),
                _buildReportCard(
                  'lib/Asset/Icons/Daily report.png',
                  'Daily Reports',
                  () {
                    Get.toNamed(Routes.DAILY_REPORTS);
                  },
                ),
                _buildReportCard(
                  'lib/Asset/Icons/Summary report.png',
                  'Summary Reports',
                  () {
                    Get.toNamed(Routes.SUMMARY_REPORTS);
                  },
                ),
                _buildReportCard(
                  'lib/Asset/Icons/over_speed.png',
                  'Over Speed Reports',
                  () {
                    Get.toNamed(Routes.OVER_SPEED_REPORTS);
                  },
                ),
                _buildReportCard(
                  'lib/Asset/Icons/Geofence report.png',
                  'Geofence Reports',
                  () {
                    Get.toNamed(Routes.GEOFENCE_REPORTS);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(String iconPath, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 171.05,
        height: 147,
        padding: const EdgeInsets.fromLTRB(23, 15, 23, 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Image.asset(
                iconPath,
                width: 50,
                height: 50,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.description_outlined,
                    size: 50,
                    color: Color(0xFF009FE3),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
