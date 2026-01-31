import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../reports/controllers/reports_controller.dart';
import '../../location/controllers/location_controller.dart';
import '../../settings/controllers/settings_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(HomeController());
    Get.put(DashboardController());
    Get.put(ReportsController());
    Get.put(LocationController());
    Get.put(SettingsController());
  }
}
