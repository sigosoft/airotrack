import 'package:airotrack/Screens/routes/app_routes.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../alerts/controllers/alerts_controller.dart';
import '../../alerts/views/widgets/alert_card.dart';
import '../controllers/notification_controller.dart';
import 'widgets/notification_filter_sheet.dart';

class NotificationView extends GetView<NotificationController> {
  const NotificationView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Notifications',
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: const EdgeInsets.only(
              top: 20,
              left: 13.97,
              right: 13.97,
            ), // Adjusted top to separate from AppBar, left as requested
            child: Row(
              children: [
                // Search takes the width the filter button leaves.
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
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: "Search Vehicles",
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ), // Reduced vertical padding for 45px height
                      suffixIcon: Icon(Icons.search, color: Colors.grey),
                    ),
                  ),
                ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => showNotificationFilterSheet(context),
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

          const SizedBox(height: 16), // Spacing between Search and Tabs
          // Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 13.97,
            ), // Align with search bar; right margin when scrolled to end
            child: Obx(
              () => Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildTab('Alerts', controller.selectedTab.value == 'Alerts'),
                  const SizedBox(width: 8),
                  _buildTab(
                    'Announcements',
                    controller.selectedTab.value == 'Announcements',
                  ),
                  const SizedBox(width: 8),
                  _buildTab(
                    'Reminders',
                    controller.selectedTab.value == 'Reminders',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16), // Height to push list down
          // List
          Expanded(
            child: Obx(
              // No announcements API yet: don't repeat the alerts under
              // this tab.
              () => controller.selectedTab.value == 'Announcements'
                  ? const Center(
                      child: Text(
                        'No announcements',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  // Finished loading and nothing matches (e.g. filtered to a
                  // vehicle with no alerts): say so instead of a blank page.
                  : controller.notifications.isEmpty &&
                          !controller.isLoading.value
                      ? const Center(
                          child: Text(
                            'No alerts found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                controller: controller.scrollController,
                padding: const EdgeInsets.only(left: 17, right: 17, top: 0),
                itemCount:
                    controller.notifications.length +
                    (controller.isLoading.value && controller.hasMore.value
                        ? 1
                        : 0),
                itemBuilder: (context, index) {
                  if (index < controller.notifications.length) {
                    return _buildNotificationCard(
                      context,
                      controller.notifications[index],
                    );
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tab chip: Alerts / Announcements switch in place, Reminders opens its page.
  Widget _buildTab(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (text == 'Reminders') {
          Get.toNamed(Routes.REMINDERS);
        } else {
          // Alerts and Announcements switch in place. Alerts used to open the
          // separate Alerts page, which reloaded everything like a new page;
          // the alerts are already loaded here, so just show them again.
          controller.changeTab(text);
        }
      },
      child: Container(
        width: 116,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13), // Radius 13
          border: Border.all(
            color: isSelected ? const Color(0xFF009FE3) : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: text == 'Alerts' && isSelected
                ? Colors.black
                : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// Shared with the live track Alerts page so both look the same.
  Widget _buildNotificationCard(BuildContext context, AlertModel item) {
    return AlertCard(alert: item);
  }
}
