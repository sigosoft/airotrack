import 'package:get/get.dart';

class GeneralSettingsController extends GetxController {
  var isVehicleIconSizeExpanded = false.obs;

  var selectedSize = 'Medium'.obs; // Small, Medium, Large

  void toggleVehicleIconSize() {
    isVehicleIconSizeExpanded.value = !isVehicleIconSizeExpanded.value;
  }

  void selectSize(String size) {
    selectedSize.value = size;
  }
}
