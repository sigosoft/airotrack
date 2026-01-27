import 'package:get/get.dart';

class NotificationController extends GetxController {
  final RxString selectedTab = 'Alerts'.obs;

  void changeTab(String tab) {
    selectedTab.value = tab;
  }
}
