import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../controllers/configure_alerts_controller.dart';

class ConfigureAlertsView extends GetView<ConfigureAlertsController> {
  const ConfigureAlertsView({Key? key}) : super(key: key);

  static const Color _accent = Color(0xFF009FE3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Configure Alerts',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => controller.searchQuery.value = v,
                      decoration: const InputDecoration(
                        hintText: 'Search Vehicles',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Icon(Icons.search, color: Colors.grey.shade400, size: 24),
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.vehicles.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: _accent),
                );
              }
              // Reads searchQuery so the list re-filters as you type.
              final _ = controller.searchQuery.value;
              final list = controller.filteredVehicles;
              if (list.isEmpty) {
                return const Center(
                  child: Text(
                    'No vehicles found',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: controller.loadVehicles,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _vehicleTile(list[index]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _vehicleTile(VehicleAlertRow vehicle) {
    return GestureDetector(
      onTap: () => _openAlertSheet(vehicle),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_car, color: _accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.plateNumber.isEmpty ? vehicle.imei : vehicle.plateNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// Loads the vehicle's current alerts, then shows the checklist to edit them.
  Future<void> _openAlertSheet(VehicleAlertRow vehicle) async {
    // Labels first (alert_types), then the vehicle's own keys (vehicle_alerts).
    await controller.loadAlertTypes();
    final loaded = await controller.loadVehicleAlerts(vehicle.imei);
    if (!loaded) return;
    await Get.bottomSheet(
      _AlertSheet(vehicle: vehicle),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }
}

class _AlertSheet extends GetView<ConfigureAlertsController> {
  final VehicleAlertRow vehicle;

  const _AlertSheet({required this.vehicle});

  static const Color _accent = Color(0xFF009FE3);

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      vehicle.plateNumber.isEmpty ? vehicle.imei : vehicle.plateNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(
                () => ListView(
                  children: [
                    CheckboxListTile(
                      value: controller.allSelected,
                      onChanged: (_) => controller.toggleAll(),
                      activeColor: _accent,
                      title: const Text(
                        'All Alerts',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const Divider(height: 1),
                    for (final option in controller.alertOptions)
                      CheckboxListTile(
                        value: controller.selectedAlerts.contains(option.key),
                        onChanged: (_) => controller.toggleAlert(option.key),
                        activeColor: _accent,
                        title: Text(
                          option.label,
                          style: const TextStyle(fontSize: 13),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: controller.isSaving.value
                        ? null
                        : () async {
                            final ok = await controller.saveVehicleAlerts(
                              vehicle.imei,
                            );
                            if (ok) {
                              Get.back();
                              Fluttertoast.showToast(
                                msg: 'Alerts updated for ${vehicle.plateNumber}',
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                timeInSecForIosWeb: 1,
                                backgroundColor: Colors.black,
                                textColor: Colors.white,
                                fontSize: 16.0,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      controller.isSaving.value ? 'Submitting...' : 'Submit',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
