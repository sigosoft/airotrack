import 'package:airotrack/Models/ReportItem.dart';
import 'package:airotrack/Screens/modules/reports/controllers/reports_controller.dart';
import 'package:airotrack/Screens/modules/reports/views/report_list_scaffold.dart';
import 'package:airotrack/Screens/modules/reports/views/report_map_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TripReportsView extends StatelessWidget {
  const TripReportsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReportListScaffold(
      type: ReportType.trip,
      title: 'Trip Reports',
      onTap: (_) => Get.to(() => const ReportMapView(title: 'Trip')),
      itemBuilder: (context, item, index) => _TripTile(item: item),
    );
  }
}

class _TripTile extends StatelessWidget {
  final ReportItem item;
  const _TripTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth - 32.62,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          // Vehicle number
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
            ],
          ),
          const SizedBox(height: 6),
          // Distance + Duration
          Row(
            children: [
              Image.asset(
                'lib/Asset/Icons/Distance.png',
                width: 14,
                height: 14,
                color: const Color(0xFFFF5252),
              ),
              const SizedBox(width: 6),
              const Text(
                'Distance: ',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                reportDisplay(item.distance, fallback: '0 Km'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
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
          const SizedBox(height: 5),
          // Start / end times
          Row(
            children: [
              Image.asset(
                'lib/Asset/Icons/Time.png',
                width: 13,
                height: 13,
                color: const Color(0xFF00C853),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  reportDisplay(item.startTime),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Image.asset(
                'lib/Asset/Icons/Time.png',
                width: 13,
                height: 13,
                color: const Color(0xFFFF5252),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  reportDisplay(item.endTime),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Start address (green dot)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00C853),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reportDisplay(
                    item.startLocation,
                    fallback: 'Start location unavailable',
                  ),
                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // End address (red dot)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3D00),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reportDisplay(
                    item.endLocation,
                    fallback: 'End location unavailable',
                  ),
                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                  maxLines: 2,
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
