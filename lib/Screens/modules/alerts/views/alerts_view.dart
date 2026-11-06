import 'package:flutter/material.dart';

import 'package:get/get.dart';
import '../controllers/alerts_controller.dart';
import 'alerts_filter_sheet.dart';
import 'widgets/alert_card.dart';
import '../../../routes/app_routes.dart';

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

  /// Same card as the Notifications screen (bell on Home).
  Widget _buildAlertTile(BuildContext context, int index) {
    return AlertCard(alert: controller.alerts[index]);
  }
}
