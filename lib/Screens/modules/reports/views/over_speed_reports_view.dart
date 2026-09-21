import 'package:airotrack/Models/ReportItem.dart';
import 'package:airotrack/Screens/modules/reports/controllers/reports_controller.dart';
import 'package:airotrack/Screens/modules/reports/views/report_list_scaffold.dart';
import 'package:airotrack/Screens/modules/reports/views/report_map_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OverSpeedReportsView extends StatelessWidget {
  const OverSpeedReportsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReportListScaffold(
      type: ReportType.overspeed,
      title: 'Over Speed Reports',
      onTap: (_) => Get.to(() => const ReportMapView(title: 'Over Speed')),
      itemBuilder: (context, item, index) => _OverSpeedTile(item: item),
    );
  }
}

class _OverSpeedTile extends StatelessWidget {
  final ReportItem item;
  const _OverSpeedTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final speedText = item.speed.isNotEmpty
        ? item.speed
        : (item.maxSpeed.isNotEmpty ? item.maxSpeed : '—');
    final locationText = item.location.isNotEmpty
        ? item.location
        : item.startLocation;

    return Container(
      width: screenWidth - 32.62,
      height: 95,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'lib/Asset/Icons/Car.png',
                width: 22,
                height: 20,
                color: const Color(0xFF009FE3),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reportDisplay(item.vehicleNumber, fallback: '—'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Image.asset(
                    'lib/Asset/Icons/Speed.png',
                    width: 30,
                    height: 24,
                    color: Colors.black,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                  Text(
                    reportDisplay(speedText, fallback: '—'),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF6E6D6D),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Image.asset(
                'lib/Asset/Icons/Time.png',
                width: 14,
                height: 14,
                color: const Color(0xFFFF5252),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reportDisplay(item.startTime),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF6E6D6D),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Image.asset(
                'lib/Asset/Icons/location outlined.png',
                width: 14,
                height: 14,
                color: const Color(0xFFFF5252),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reportDisplay(
                    locationText,
                    fallback: 'Location unavailable',
                  ),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF6E6D6D),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
