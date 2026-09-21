import 'package:airotrack/Models/ReportItem.dart';
import 'package:airotrack/Screens/modules/reports/controllers/reports_controller.dart';
import 'package:airotrack/Screens/modules/reports/views/report_list_scaffold.dart';
import 'package:airotrack/Screens/modules/reports/views/report_map_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class IgnitionReportsView extends StatelessWidget {
  const IgnitionReportsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReportListScaffold(
      type: ReportType.ignition,
      title: 'Ignition Reports',
      onTap: (_) => Get.to(() => const ReportMapView(title: 'Ignition')),
      itemBuilder: (context, item, index) => _IgnitionTile(item: item),
    );
  }
}

class _IgnitionTile extends StatelessWidget {
  final ReportItem item;
  const _IgnitionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isOn = item.ignitionOn;
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth - 32.62,
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'lib/Asset/Icons/power.png',
                    width: 18,
                    height: 18,
                    color: isOn
                        ? const Color(0xFF00C853)
                        : const Color(0xFFFF3D00),
                  ),
                  Text(
                    item.status.isNotEmpty
                        ? item.status
                        : (isOn ? 'Ignition On' : 'Ignition Off'),
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
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
                width: 12,
                height: 12,
                color: const Color(0xFFFF5252),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reportDisplay(item.startTime),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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
                width: 12,
                height: 12,
                color: const Color(0xFFFF5252),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reportDisplay(
                    item.location,
                    fallback: 'Location unavailable',
                  ),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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
