import 'package:get/get.dart';

class Vehicle {
  final String plateNumber;
  final String status; // 'Running', 'Stopped', 'Idle', 'Inactive'
  final String statusDuration;
  final String lastUpdated;
  final String address;
  final String speed;
  final double distance;
  final int validityDays;
  final bool isIgnitionOn;
  final bool isAcOn;
  final bool isGpsOn;
  final bool isLocked;
  final String imageUrl;

  Vehicle({
    required this.plateNumber,
    required this.status,
    required this.statusDuration,
    required this.lastUpdated,
    required this.address,
    required this.speed,
    required this.distance,
    required this.validityDays,
    this.isIgnitionOn = false,
    this.isAcOn = false,
    this.isGpsOn = true,
    this.isLocked = true,
    this.imageUrl = 'lib/Asset/Icons/Car.png',
  });
}

class HomeController extends GetxController {
  final vehicles = <Vehicle>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final RxInt selectedIndex = 1.obs;

  @override
  void onInit() {
    super.onInit();
    loadDummyData();
  }

  Future<void> loadDummyData() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Simulating a network delay
      await Future.delayed(const Duration(milliseconds: 100));

      // Simulating data fetching
      vehicles.value = [
        Vehicle(
          plateNumber: "KL 07 A 0518",
          status: "Running",
          statusDuration: "08h 30m",
          lastUpdated: "Jul 31, 2025 05:30:08 PM",
          address: "Puthiyakavu Junction, Karunagappally, Kerala 690518, India",
          speed: "20",
          distance: 30.12,
          validityDays: 596,
          isIgnitionOn: true,
          isAcOn: true,
          imageUrl: 'lib/Asset/Icons/Car.png',
        ),
        Vehicle(
          plateNumber: "KL 07 A 0518",
          status: "Stopped",
          statusDuration: "05h 30m",
          lastUpdated: "Jul 31, 2025 05:38:08 PM",
          address: "Puthiyakavu Junction, Karunagappally, Kerala 690518, India",
          speed: "00",
          distance: 30.12,
          validityDays: 596,
          isIgnitionOn: false,
          isAcOn: false,
          imageUrl: 'lib/Asset/Icons/Car.png',
        ),
        Vehicle(
          plateNumber: "KL 07 A 0518",
          status: "Running",
          statusDuration: "08h 30m",
          lastUpdated: "Jul 31, 2025 05:30:08 PM",
          address: "Puthiyakavu Junction, Karunagappally, Kerala 690518, India",
          speed: "20",
          distance: 30.12,
          validityDays: 596,
          isIgnitionOn: true,
          isAcOn: true,
          imageUrl: 'lib/Asset/Icons/Car.png',
        ),
        Vehicle(
          plateNumber: "KL 07 A 0518",
          status: "Stopped",
          statusDuration: "05h 30m",
          lastUpdated: "Jul 31, 2025 05:30:08 PM",
          address: "Puthiyakavu Junction, Karunagappally, Kerala 690518, India",
          speed: "00",
          distance: 30.12,
          validityDays: 596,
          isIgnitionOn: false,
          isAcOn: false,
        ),
      ];
    } catch (e) {
      errorMessage.value = "An error occurred: $e";
      // Optionally log the error
      print("Error loading data: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void changeTab(int index) {
    selectedIndex.value = index;
  }
}
