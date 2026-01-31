import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RemindersController extends GetxController {
  final ScrollController scrollController = ScrollController();
  var reminders = <int>[].obs;
  var isLoading = false.obs;
  var hasMore = true.obs;
  var currentPage = 1;

  @override
  void onInit() {
    super.onInit();
    loadReminders();
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        if (!isLoading.value && hasMore.value) {
          loadMoreReminders();
        }
      }
    });
  }

  void loadReminders() {
    isLoading.value = true;
    Future.delayed(const Duration(seconds: 1), () {
      reminders.assignAll(List.generate(5, (index) => index));
      isLoading.value = false;
    });
  }

  void loadMoreReminders() {
    isLoading.value = true;
    currentPage++;
    Future.delayed(const Duration(seconds: 1), () {
      reminders.addAll(List.generate(5, (index) => index));
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
