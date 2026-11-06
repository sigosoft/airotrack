import 'package:get/get.dart';
import '../controllers/notification_controller.dart';
import '../../reminders/controllers/reminders_controller.dart';

class NotificationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NotificationController>(() => NotificationController());
    // Created now (not lazily) so reminders are already loaded when the
    // Reminders tab is tapped; switching tabs then shows them at once.
    Get.put<RemindersController>(RemindersController());
  }
}
