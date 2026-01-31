import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NotificationController extends GetxController {
  final RxString selectedTab = 'Alerts'.obs;
  final ScrollController scrollController = ScrollController();
  var notifications = <int>[].obs;
  var isLoading = false.obs;
  var hasMore = true.obs;
  var currentPage = 1;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        if (!isLoading.value && hasMore.value) {
          loadMoreNotifications();
        }
      }
    });
  }

  void loadNotifications() {
    isLoading.value = true;
    Future.delayed(const Duration(seconds: 1), () {
      notifications.assignAll(List.generate(10, (index) => index));
      isLoading.value = false;
    });
  }

  void loadMoreNotifications() {
    isLoading.value = true;
    currentPage++;
    Future.delayed(const Duration(seconds: 1), () {
      notifications.addAll(List.generate(10, (index) => index));
      if (currentPage >= 5) {
        hasMore.value = false;
      }
      isLoading.value = false;
    });
  }

  void changeTab(String tab) {
    selectedTab.value = tab;
    // Reset pagination on tab change if needed, but for now just dummy
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
