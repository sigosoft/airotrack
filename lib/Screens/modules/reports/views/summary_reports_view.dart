import 'package:airotrack/Models/ReportItem.dart';
import 'package:airotrack/Screens/modules/reports/controllers/reports_controller.dart';
import 'package:airotrack/Screens/modules/reports/views/report_list_scaffold.dart';
import 'package:airotrack/Screens/modules/reports/views/report_map_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SummaryReportsView extends StatelessWidget {
  const SummaryReportsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReportListScaffold(
      type: ReportType.summary,
      title: 'Summary Reports',
      onTap: (_) => Get.to(() => const ReportMapView(title: 'Summary')),
      itemBuilder: (context, item, index) => _SummaryTile(item: item),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final ReportItem item;
  const _SummaryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth - 32.62,
      padding: const EdgeInsets.all(14),
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
          // Vehicle + distance
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
              Image.asset('lib/Asset/Icons/Route.png', width: 14, height: 14),
              const SizedBox(width: 4),
              Text(
                reportDisplay(item.distance, fallback: '0 Km'),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Duration stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat(
                'Engine Hour',
                reportDisplay(item.engineHours),
                const Color(0xFFFF6F00),
              ),
              _stat(
                'Running',
                reportDisplay(item.running),
                const Color(0xFF00C853),
              ),
              _stat(
                'Stoped',
                reportDisplay(item.stopped),
                const Color(0xFFFF5252),
              ),
              _stat(
                'Idle',
                reportDisplay(item.idle),
                const Color(0xFFFFC107),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _dottedLine(),
          const SizedBox(height: 12),
          // Addresses + odometer
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 13,
                      height: 13,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C853),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Container(width: 1, color: Colors.grey.shade300),
                    ),
                    Container(
                      width: 13,
                      height: 13,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3D00),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reportDisplay(
                          item.startLocation,
                          fallback: 'Start location unavailable',
                        ),
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFF6E6D6D),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      _odometerRow(),
                      const SizedBox(height: 10),
                      Text(
                        reportDisplay(
                          item.endLocation,
                          fallback: 'End location unavailable',
                        ),
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFF6E6D6D),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _dottedLine(),
          const SizedBox(height: 12),
          // Avg / Max speed
          Row(
            children: [
              Expanded(
                child: _speedBox(
                  iconColor: const Color(0xFF009FE3),
                  label: 'Avg Speed: ',
                  value: reportDisplay(item.averageSpeed, fallback: '—'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _speedBox(
                  iconColor: const Color(0xFFFF5252),
                  label: 'Max Speed: ',
                  value: reportDisplay(
                    item.maxSpeed.isNotEmpty ? item.maxSpeed : item.speed,
                    fallback: '—',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _odometerRow() {
    final start = reportDisplay(item.startOdometer, fallback: '—');
    final end = reportDisplay(item.endOdometer, fallback: '—');
    return Row(
      children: [
        _odoPill(start, const Color(0xFFE8F5E9), const Color(0xFF00C853)),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(height: 1, color: Colors.grey.shade300),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        _odoPill(end, const Color(0xFFFFEBEE), const Color(0xFFFF5252)),
      ],
    );
  }

  Widget _odoPill(String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _speedBox({
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Image.asset(
            'lib/Asset/Icons/Speed.png',
            width: 16,
            height: 16,
            color: iconColor,
            colorBlendMode: BlendMode.srcIn,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                children: [
                  TextSpan(text: label),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dottedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 4.0;
        const dashSpace = 3.0;
        final count =
            (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Container(
              width: dashWidth,
              height: 1,
              margin: const EdgeInsets.only(right: dashSpace),
              color: Colors.grey.shade300,
            ),
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: color)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color.withOpacity(0.7), width: 1.5),
            ),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
