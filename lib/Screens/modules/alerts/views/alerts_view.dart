import 'package:flutter/material.dart';

import 'package:get/get.dart';
import '../controllers/alerts_controller.dart';
import 'alerts_filter_sheet.dart';
import '../../../routes/app_routes.dart';

/// Icon colour per API `alert` key.
const Map<String, Color> _eventColors = {
  'ignitionon': Color(0xFF00C853),
  'ignitionoff': Color(0xFFD50000),
  'emergencyon': Color(0xFFC2185B),
  'emergencyoff': Color(0xFF78909C),
  'wiredisconnect': Color(0xFFFF6D00),
  'powerdisconnect': Color(0xFF6A1B9A),
  'powerrestored': Color(0xFF009688),
  'tilt': Color(0xFFFFB300),
  'boxopen': Color(0xFF795548),
  'rashturning': Color(0xFFE65100),
  'deviceoverspeed': Color(0xFFFF3D00),
  'geofenceentry': Color(0xFF1E88E5),
  'geofenceexit': Color(0xFF00ACC1),
  'geofenceoverspeed': Color(0xFF3949AB),
  'impactcrash': Color(0xFFB71C1C),
};

/// Unknown events stay grey.
Color _eventColor(AlertModel alert) =>
    _eventColors[alert.alertKey.toLowerCase()] ?? Colors.grey.shade600;

class AlertsView extends GetView<AlertsController> {
  const AlertsView({Key? key}) : super(key: key);

  /// Back goes to the screen Alerts was opened from, with its vehicle. The
  /// bottom bars replace that screen, so a plain pop would land on Home.
  void _goBack() {
    final imei = Get.parameters['trackImei'] ?? '';
    final plate = Get.parameters['trackPlate'] ?? '';
    if (imei.isEmpty) {
      Get.back();
      return;
    }
    switch (Get.parameters['from']) {
      case 'history':
        Get.offNamed(
          Routes.HISTORY,
          parameters: {'imei': imei, 'vehicleId': plate},
        );
      case 'statistics':
        Get.offNamed(
          Routes.STATISTICS,
          parameters: {'imei': imei, 'plate': plate},
        );
      default:
        Get.offNamed(
          Routes.TRACK,
          parameters: {'imei': imei, 'vehicleId': plate},
        );
    }
  }

  /// Asks for the date range, then saves the alerts in it as a CSV file.
  Future<void> _pickDatesAndDownload(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day),
      ),
      helpText: 'Select alert dates',
    );
    if (picked == null) return;
    await controller.downloadAlerts(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Alerts',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 34),
          onPressed: _goBack,
        ),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Download alerts',
              onPressed: controller.isDownloading.value
                  ? null
                  : () => _pickDatesAndDownload(context),
              icon: controller.isDownloading.value
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Image.asset(
                      'lib/Asset/Icons/download.png',
                      height: 28,
                      width: 28,
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 13.97, right: 13.97),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (value) {
                        controller.searchQuery.value = value;
                        controller.applyFilters();
                      },
                      decoration: const InputDecoration(
                        hintText: "Search Alerts",
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        suffixIcon: Icon(Icons.search, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: showAlertsFilterSheet,
                  child: Container(
                    height: 45,
                    width: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'lib/Asset/Icons/Filters.png',
                        width: 22,
                        height: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // List of Alerts
          Expanded(
            child: Obx(() {
              if (controller.alerts.isEmpty && !controller.isLoading.value) {
                return const Center(
                  child: Text(
                    'No alerts found',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                );
              }
              return ListView.builder(
                controller: controller.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount:
                    controller.alerts.length +
                    (controller.isLoading.value && controller.hasMore.value
                        ? 1
                        : 0),
                itemBuilder: (context, index) {
                  if (index < controller.alerts.length) {
                    return _buildAlertTile(context, index);
                  } else {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF009FE3),
                          ),
                        ),
                      ),
                    );
                  }
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertTile(BuildContext context, int index) {
    final alert = controller.alerts[index];
    double screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth - 32,
      constraints: const BoxConstraints(minHeight: 64),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          // Power Icon
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.asset(
              'lib/Asset/Icons/power.png',
              width: 30,
              height: 30,
              color: _eventColor(alert),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.plateNumber.isNotEmpty
                            ? alert.plateNumber
                            : alert.deviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      alert.date,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                Text(
                  alert.type,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              
              ],
            ),
          ),
        ],
      ),
    );
  }
}
