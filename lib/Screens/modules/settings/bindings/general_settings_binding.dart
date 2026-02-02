import 'package:get/get.dart';
import '../controllers/general_settings_controller.dart';

class GeneralSettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GeneralSettingsController>(() => GeneralSettingsController());
  }
}
