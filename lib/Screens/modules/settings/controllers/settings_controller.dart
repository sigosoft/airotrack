import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../routes/app_routes.dart';

class SettingsController extends GetxController {
  Future<void> signOut() async {
    try {
      if (!Hive.isBoxOpen('userBox')) {
        await Hive.openBox('userBox');
      }
      var box = Hive.box('userBox');
      await box.put('isLoggedIn', false);

      Get.snackbar(
        'Success',
        'Signed out successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Get.offAllNamed(Routes.LOGIN);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Sign out failed: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  final ScrollController expensesScrollController = ScrollController();
  final ScrollController supportTicketsScrollController = ScrollController();

  var expenses = <int>[].obs;
  var isLoadingExpenses = false.obs;
  var hasMoreExpenses = true.obs;
  var expensesPage = 1;

  var supportTickets = <int>[].obs;
  var isLoadingSupportTickets = false.obs;
  var hasMoreSupportTickets = true.obs;
  var supportTicketsPage = 1;

  @override
  void onInit() {
    super.onInit();
    loadExpenses();
    loadSupportTickets();

    expensesScrollController.addListener(() {
      if (expensesScrollController.position.pixels ==
          expensesScrollController.position.maxScrollExtent) {
        if (!isLoadingExpenses.value && hasMoreExpenses.value) {
          loadMoreExpenses();
        }
      }
    });

    supportTicketsScrollController.addListener(() {
      if (supportTicketsScrollController.position.pixels ==
          supportTicketsScrollController.position.maxScrollExtent) {
        if (!isLoadingSupportTickets.value && hasMoreSupportTickets.value) {
          loadMoreSupportTickets();
        }
      }
    });
  }

  void loadExpenses() {
    isLoadingExpenses.value = true;
    Future.delayed(const Duration(seconds: 1), () {
      expenses.assignAll(List.generate(10, (index) => index));
      isLoadingExpenses.value = false;
    });
  }

  void loadMoreExpenses() {
    isLoadingExpenses.value = true;
    expensesPage++;
    Future.delayed(const Duration(seconds: 1), () {
      expenses.addAll(List.generate(10, (index) => index));
      if (expensesPage >= 5) {
        hasMoreExpenses.value = false;
      }
      isLoadingExpenses.value = false;
    });
  }

  void loadSupportTickets() {
    isLoadingSupportTickets.value = true;
    Future.delayed(const Duration(seconds: 1), () {
      supportTickets.assignAll(List.generate(10, (index) => index));
      isLoadingSupportTickets.value = false;
    });
  }

  void loadMoreSupportTickets() {
    isLoadingSupportTickets.value = true;
    supportTicketsPage++;
    Future.delayed(const Duration(seconds: 1), () {
      supportTickets.addAll(List.generate(10, (index) => index));
      if (supportTicketsPage >= 5) {
        hasMoreSupportTickets.value = false;
      }
      isLoadingSupportTickets.value = false;
    });
  }

  @override
  void onClose() {
    expensesScrollController.dispose();
    supportTicketsScrollController.dispose();
    super.onClose();
  }
}
