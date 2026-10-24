import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/history_controller.dart';

/// Card shown after tapping the blue route: time and place the vehicle passed.
class HistoryRouteInfoCard extends StatelessWidget {
  const HistoryRouteInfoCard({
    super.key,
    required this.info,
    required this.onClose,
  });

  final RouteTapInfo info;
  final VoidCallback onClose;

  static final _timeFormat = DateFormat('dd MMM yyyy hh:mm:ss a');

  @override
  Widget build(BuildContext context) {
    final address = info.address;
    final addressText = address == null
        ? 'Loading address...'
        : (address.isEmpty ? 'Address unavailable' : address);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 0, 0, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
              ),
            ),
            _detailRow('Date & Time :', _timeFormat.format(info.time)),
            const SizedBox(height: 4),
            _detailRow('Speed :', '${info.speed} Kmph'),
            const SizedBox(height: 4),
            _detailRow('Address :', addressText, maxLines: 2),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    Color? valueColor,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: valueColor ?? Colors.black87,
              fontWeight:
                  valueColor != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
