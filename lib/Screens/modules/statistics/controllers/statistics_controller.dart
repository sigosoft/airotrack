import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Models/StatisticsModel.dart';
import 'package:airotrack/Screens/modules/home/controllers/home_controller.dart';
import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class StatisticsController extends GetxController {
  final selectedPeriod = 'Today'.obs;
  final isLoading = false.obs;
  final stats = const StatisticsModel().obs;
  final selectedImei = ''.obs;
  final selectedPlate = 'Select vehicle'.obs;
  DateTime? customFrom;
  DateTime? customTo;

  List<Vehicle> get vehicles {
    if (Get.isRegistered<HomeController>()) {
      return Get.find<HomeController>().vehicles.toList();
    }
    return const [];
  }

  @override
  void onInit() {
    super.onInit();
    final paramImei = Get.parameters['imei'];
    if (paramImei != null && paramImei.isNotEmpty) {
      selectedImei.value = paramImei;
      selectedPlate.value = Get.parameters['plate'] ?? paramImei;
      loadStatistics();
    } else {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    if (!Get.isRegistered<HomeController>()) return;
    final home = Get.find<HomeController>();

    if (home.vehicles.isNotEmpty) {
      selectVehicle(home.vehicles.first);
      return;
    }

    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (home.vehicles.isNotEmpty) {
        selectVehicle(home.vehicles.first);
        return;
      }
      if (!home.isLoading.value && home.vehicles.isEmpty) break;
    }
  }

  void selectVehicle(Vehicle vehicle) {
    final imei = vehicle.deviceId.trim();
    if (imei.isEmpty) return;
    selectedImei.value = imei;
    selectedPlate.value =
        vehicle.plateNumber.isEmpty ? imei : vehicle.plateNumber;
    loadStatistics();
  }

  void setPeriod(String period) {
    selectedPeriod.value = period;
    if (period.toLowerCase() != 'custom') {
      customFrom = null;
      customTo = null;
    }
    loadStatistics();
  }

  void setCustomRange(DateTime from, DateTime to) {
    customFrom = from;
    customTo = to;
    selectedPeriod.value = 'Custom';
    loadStatistics();
  }

  String get customRangeLabel {
    if (customFrom == null || customTo == null) return 'Custom';
    final fmt = DateFormat('dd MMM');
    return '${fmt.format(customFrom!)} - ${fmt.format(customTo!)}';
  }

  Future<void> loadStatistics() async {
    final imei = selectedImei.value.trim();
    if (imei.isEmpty) return;
    try {
      isLoading.value = true;
      await ensureApiToken();
      final range = PeriodQuery.fromLabel(
        selectedPeriod.value,
        customFrom: customFrom,
        customTo: customTo,
      );
      final response = await DioClient().get(
        ApiEndPoints.statistics,
        query: range.toQuery(imei: imei),
      );
      if (response.data != null) {
        stats.value = StatisticsModel.fromJson(response.data);
      }
    } catch (e) {
      showErrorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }
}
