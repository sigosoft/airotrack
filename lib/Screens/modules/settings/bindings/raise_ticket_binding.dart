import 'package:get/get.dart';
import '../controllers/raise_ticket_controller.dart';

class RaiseTicketBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RaiseTicketController>(() => RaiseTicketController());
  }
}
