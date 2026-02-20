import 'package:flutter/material.dart';
import 'history_dashed_line.dart';
import 'history_row_detail.dart';
import 'history_section_divider.dart';

class HistorySegmentItem extends StatelessWidget {
  final String distance;
  final String status;
  final Color statusColor;
  final Color statusTextColor;
  final String maxSpeed;
  final String start;
  final String duration;
  final String end;

  const HistorySegmentItem({
    Key? key,
    required this.distance,
    required this.status,
    required this.statusColor,
    required this.statusTextColor,
    required this.maxSpeed,
    required this.start,
    required this.duration,
    required this.end,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.directions_walk, color: Colors.grey, size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                "Distance: $distance",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed, color: Colors.grey, size: 22),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      "Max Speed: $maxSpeed",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const HistoryDashedLine(),
        const SizedBox(height: 8),
        HistoryRowDetail(
          icon: Icons.play_circle_outline,
          label: "Start:",
          value: start,
        ),
        const SizedBox(height: 8),
        const HistoryDashedLine(),
        const SizedBox(height: 8),
        HistoryRowDetail(
          icon: Icons.access_time,
          label: "Duration:",
          value: duration,
        ),
        const SizedBox(height: 8),
        const HistoryDashedLine(),
        const SizedBox(height: 8),
        HistoryRowDetail(
          icon: Icons.stop_circle_outlined,
          label: "End:",
          value: end,
        ),
        const SizedBox(height: 20),
        const HistorySectionDivider(),
        const SizedBox(height: 15),
      ],
    );
  }
}
