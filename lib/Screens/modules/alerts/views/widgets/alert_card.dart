import 'package:flutter/material.dart';

import '../../controllers/alerts_controller.dart';

/// One alert row, shared by the Notifications screen (bell on Home) and the
/// live track Alerts page so both look the same:
/// green power icon for ignition on / moving, red for ignition off / stopped /
/// offline, blue speed icon for every other event; vehicle and time on top,
/// event text, then the address.
class AlertCard extends StatelessWidget {
  final AlertModel alert;

  const AlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final typeLower = alert.type.toLowerCase();
    final String iconAsset;
    final Color iconColor;
    if (typeLower.contains('ignition on') || typeLower.contains('moving')) {
      iconAsset = 'lib/Asset/Icons/power.png';
      iconColor = const Color(0xFF00C853); // Green
    } else if (typeLower.contains('ignition off') ||
        typeLower.contains('stopped') ||
        typeLower.contains('offline')) {
      iconAsset = 'lib/Asset/Icons/power.png';
      iconColor = const Color(0xFFD50000); // Red
    } else {
      iconAsset = 'lib/Asset/Icons/Speed.png';
      iconColor = const Color(0xFF009FE3); // Blue
    }

    final plate =
        alert.plateNumber.isNotEmpty ? alert.plateNumber : alert.deviceName;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            child: Image.asset(
              iconAsset,
              width: 28,
              height: 28,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        plate,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      alert.date,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[500],
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  alert.type,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    height: 1.2,
                  ),
                ),
                if (alert.address.isNotEmpty)
                  Text(
                    alert.address,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
