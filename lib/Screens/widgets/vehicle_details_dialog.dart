import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../modules/home/controllers/home_controller.dart';
import '../routes/app_routes.dart';

/// Vehicle details popup with Cancel, History and Track.
///
/// Shared by the Home vehicle list and the Location map so tapping a vehicle
/// shows the same popup in both places.
void showVehicleDetailsDialog(BuildContext context, Vehicle vehicle) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        // Height follows the content (long addresses wrap) instead of a
        // fixed 250 that clipped on narrow phones.
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogRow("Name:", vehicle.plateNumber),
              const SizedBox(height: 8),
              // The home API sends no status duration today; show
              // "Since …" only when there is one, not a dangling "Since".
              _dialogRow(
                "Status:",
                vehicle.statusDuration.trim().isEmpty
                    ? vehicle.statusLabel
                    : "${vehicle.statusLabel} since ${vehicle.statusDuration.trim()}",
              ),
              const SizedBox(height: 8),
              _dialogRow("Device Time:", vehicle.displayLastUpdated),
              const SizedBox(height: 8),
              _dialogRow("Location:", vehicle.locationLabel),
              const SizedBox(height: 8),
              _dialogRow("Engine:", vehicle.isIgnitionOn ? "On" : "Off"),
              const SizedBox(height: 8),
              _dialogRow("Voltage:", "13.78 V"),
              const SizedBox(height: 20),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cancel Button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 120,
                        height: 35,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Get.toNamed(
                          Routes.HISTORY,
                          parameters: {
                            'imei': vehicle.deviceId,
                            'vehicleId': vehicle.plateNumber,
                          },
                        );
                      },
                      child: Container(
                        width: 100,
                        height: 35,
                        decoration: BoxDecoration(
                          color: const Color(0xFF009FE3),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Center(
                          child: Text(
                            "History",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        // Dismiss keyboard before navigating
                        if (FocusManager.instance.primaryFocus != null) {
                          FocusManager.instance.primaryFocus!.unfocus();
                        }
                        Navigator.pop(context);
                        Get.toNamed(
                          Routes.TRACK,
                          parameters: {
                            'imei': vehicle.deviceId,
                            'vehicleId': vehicle.plateNumber,
                          },
                        );
                      },
                      child: Container(
                        width: 120,
                        height: 35,
                        decoration: BoxDecoration(
                          color: const Color(0xFF009FE3),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Center(
                          child: Text(
                            "Track",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _dialogRow(String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 90,
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.black,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
