import 'package:get/get.dart';

class HistoryController extends GetxController {
  var showBottomSheet = true.obs;
  final List<String> dateRangeOptions = [
    "1 hour",
    "Today",
    "Yesterday",
    "Week",
    "Custom",
  ];
  var selectedDateRange = "Today".obs;

  void updateDateRange(String value) {
    selectedDateRange.value = value;
    // Here you would typically also update fromDate and toDate based on the selection
  }

  var fromDate = "08 Oct 2025".obs;
  var toDate = "08 Oct 2025".obs;
  var vehicleId = "KL 07 D 0518".obs;

  var currentSpeed = "0 Kmph".obs;
  var duration = "00:00:00".obs;
  var totalDistance = "12.5 Km".obs;

  var playbackSpeed = "1X".obs;
  var isPlaying = false.obs;
  var progress = 0.0.obs;

  void toggleBottomSheet() {
    showBottomSheet.value = !showBottomSheet.value;
  }
}
