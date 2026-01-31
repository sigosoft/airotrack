import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AlertsController extends GetxController {
  final ScrollController scrollController = ScrollController();
  var alerts = <int>[].obs;
  var isLoading = false.obs;
  var hasMore = true.obs;
  var currentPage = 1;

  @override
  void onInit() {
    super.onInit();
    loadAlerts();
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        if (!isLoading.value && hasMore.value) {
          loadMoreAlerts();
        }
      }
    });
  }

  void loadAlerts() {
    isLoading.value = true;
    // Simulate initial load
    Future.delayed(const Duration(seconds: 1), () {
      alerts.assignAll(List.generate(10, (index) => index));
      isLoading.value = false;
    });
  }

  void loadMoreAlerts() {
    isLoading.value = true;
    currentPage++;
    // Simulate loading more data
    Future.delayed(const Duration(seconds: 1), () {
      alerts.addAll(List.generate(10, (index) => index));
      if (currentPage >= 5) {
        hasMore.value = false;
      }
      isLoading.value = false;
    });
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
