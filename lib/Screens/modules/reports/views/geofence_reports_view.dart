import 'package:airotrack/Models/ReportItem.dart';
import 'package:airotrack/Screens/modules/reports/controllers/reports_controller.dart';
import 'package:airotrack/Screens/modules/reports/views/report_list_scaffold.dart';
import 'package:airotrack/Screens/modules/reports/views/report_map_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GeofenceReportsView extends StatelessWidget {
  const GeofenceReportsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReportListScaffold(
      type: ReportType.geofence,
      title: 'Geofence Reports',
      onTap: (_) => Get.to(() => const ReportMapView(title: 'Geofence')),
      itemBuilder: (context, item, index) => _GeofenceTile(item: item),
    );
  }
}

class _GeofenceTile extends StatelessWidget {
  final ReportItem item;
  const _GeofenceTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isEnter = item.isGeofenceEnter;
    final screenWidth = MediaQuery.of(context).size.width;
    final locationText = item.location.isNotEmpty
        ? item.location
        : item.startLocation;

    return Container(
      width: screenWidth - 32.62,
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
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'lib/Asset/Icons/Polygon.png',
                    width: 22,
                    height: 22,
                    color: isEnter
                        ? const Color(0xFF00C853)
                        : const Color(0xFFFF5252),
                  ),
                  Text(
                    isEnter ? 'Geofence Enter' : 'Geofence Exit',
                    style: TextStyle(
                      fontSize: 8,
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
                    locationText,
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
