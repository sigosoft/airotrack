import 'package:airotrack/Models/ReportItem.dart';
import 'package:airotrack/Screens/modules/reports/controllers/reports_controller.dart';
import 'package:airotrack/Screens/modules/reports/views/report_list_scaffold.dart';
import 'package:airotrack/Screens/modules/reports/views/report_map_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class StoppageReportsView extends StatelessWidget {
  const StoppageReportsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReportListScaffold(
      type: ReportType.stoppage,
      title: 'Stoppage Reports',
      onTap: (_) => Get.to(() => const ReportMapView(title: 'Stoppage')),
      itemBuilder: (context, item, index) => _StoppageTile(item: item),
    );
  }
}

class _StoppageTile extends StatelessWidget {
  final ReportItem item;
  const _StoppageTile({required this.item});

  @override
  Widget build(BuildContext context) {
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
                color: const Color(0xFFFF3D00),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reportDisplay(item.vehicleNumber, fallback: 'Vehicle'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  children: [
                    const TextSpan(text: 'Duration: '),
                    TextSpan(
                      text: reportDisplay(item.duration, fallback: '00h 00m'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Image.asset(
                'lib/Asset/Icons/Time.png',
                width: 12,
                height: 12,
                color: const Color(0xFF00C853),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  reportDisplay(item.startTime),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Image.asset(
                'lib/Asset/Icons/Time.png',
                width: 12,
                height: 12,
                color: const Color(0xFFFF5252),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  reportDisplay(item.endTime),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Image.asset(
                'lib/Asset/Icons/location outlined.png',
                width: 12,
                height: 12,
                color: const Color(0xFFFF5252),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reportDisplay(item.location, fallback: 'Location unavailable'),
                  style: TextStyle(fontSize: 9, color: Colors.grey[700]),
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
