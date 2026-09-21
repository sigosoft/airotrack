import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/DashboardModel.dart';
import 'package:airotrack/Screens/modules/home/controllers/home_controller.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:get/get.dart';

class DashboardController extends GetxController {
  final isLoading = false.obs;
  final dashboard = const DashboardModel().obs;
  final selectedImei = ''.obs;
  final selectedPlate = 'Select vehicle'.obs;
  final selectedPeriod = 'Week'.obs;

  Worker? _vehiclesWorker;

  List<Vehicle> get vehicles {
    if (Get.isRegistered<HomeController>()) {
      return Get.find<HomeController>().vehicles.toList();
    }
    return const [];
  }

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final vehicle = await _waitForFirstVehicle();
    if (vehicle != null) {
      selectVehicle(vehicle);
      return;
    }

    // Home list may still be loading — react when vehicles arrive.
    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      _vehiclesWorker?.dispose();
      _vehiclesWorker = ever<List<Vehicle>>(home.vehicles, (list) {
        if (selectedImei.value.isNotEmpty) return;
        if (list.isEmpty) return;
        selectVehicle(list.first);
        _vehiclesWorker?.dispose();
        _vehiclesWorker = null;
      });
    }
  }

  /// Waits for HomeController to finish its first fetch (or timeout).
  Future<Vehicle?> _waitForFirstVehicle() async {
    if (!Get.isRegistered<HomeController>()) return null;
    final home = Get.find<HomeController>();

    if (home.vehicles.isNotEmpty) return home.vehicles.first;

    // Poll while home is still loading vehicles.
    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (home.vehicles.isNotEmpty) return home.vehicles.first;
      if (!home.isLoading.value && home.vehicles.isEmpty) break;
    }
    return home.vehicles.isNotEmpty ? home.vehicles.first : null;
  }

  void selectVehicle(Vehicle vehicle) {
    final imei = vehicle.deviceId.trim();
    if (imei.isEmpty) return;
    selectedImei.value = imei;
    selectedPlate.value =
        vehicle.plateNumber.isEmpty ? imei : vehicle.plateNumber;
    loadDashboard();
  }

  void setPeriod(String period) {
    if (selectedPeriod.value == period) return;
    selectedPeriod.value = period;
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    final imei = selectedImei.value.trim();
    if (imei.isEmpty) {
      // Never call dashboard without a vehicle — avoids 422 toast on startup.
      return;
    }
    try {
      isLoading.value = true;
      await ensureApiToken();
      final range = PeriodQuery.fromLabel(selectedPeriod.value);
      final response = await DioClient().get(
        ApiEndPoints.dashboard,
        query: range.toQuery(
          imei: imei,
          includeDays: true,
          includePeriod: false,
        ),
      );
      if (response.data != null) {
        dashboard.value = DashboardModel.fromJson(response.data);
      }
    } catch (e) {
      showErrorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _vehiclesWorker?.dispose();
    super.onClose();
  }
}
