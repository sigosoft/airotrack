import 'package:get/get.dart';

class TrackController extends GetxController {
  final RxInt selectedBottomTabIndex = 0.obs;
  final RxBool showBottomSheet = false.obs;
  final RxString selectedShareOption = 'Only Once'.obs;

  void toggleBottomSheet() {
    showBottomSheet.value = !showBottomSheet.value;
  }

  void updateShareOption(String option) {
    selectedShareOption.value = option;
  }

  void changeBottomTab(int index) {
    selectedBottomTabIndex.value = index;
  }
}
