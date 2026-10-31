import 'package:get/get.dart';

import '../controllers/configure_alerts_controller.dart';

class ConfigureAlertsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ConfigureAlertsController>(() => ConfigureAlertsController());
  }
}
