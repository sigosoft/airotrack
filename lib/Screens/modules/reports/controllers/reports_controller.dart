import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReportsController extends GetxController {
  final ScrollController scrollController = ScrollController();
  var items = <int>[].obs;
  var isLoading = false.obs;
  var hasMore = true.obs;
  var currentPage = 1;

  @override
  void onInit() {
    super.onInit();
    loadItems();
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        if (!isLoading.value && hasMore.value) {
          loadMore();
        }
      }
    });
  }

  void loadItems() {
    isLoading.value = true;
    Future.delayed(const Duration(seconds: 1), () {
      items.assignAll(List.generate(10, (index) => index));
      isLoading.value = false;
    });
  }

  void loadMore() {
    isLoading.value = true;
    currentPage++;
    Future.delayed(const Duration(seconds: 1), () {
      items.addAll(List.generate(10, (index) => index));
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
