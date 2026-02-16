import 'package:get/get.dart';
import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Utils/Utils.dart';

class Vehicle {
  final int id;
  final String plateNumber;
  final String status; // 'Running', 'Stopped', 'Idle', 'Inactive'
  final String statusDuration;
  final String lastUpdated;
  final String address;
  final String speed;
  final String distance;
  final String validityDays;
  final bool isIgnitionOn;
  final bool isLocked;
  final String deviceId;

  Vehicle({
    required this.id,
    required this.plateNumber,
    required this.status,
    required this.statusDuration,
    required this.lastUpdated,
    required this.address,
    required this.speed,
    required this.distance,
    required this.validityDays,
    this.isIgnitionOn = false,
    this.isLocked = true,
    required this.deviceId,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    // Derived status logic
    String derivedStatus = 'Stopped';
    final mode = json['mode']?.toString().toUpperCase();
    final speed = double.tryParse(json['speed']?.toString() ?? '0') ?? 0;
    final ignition = json['ignition'] == 1;

    if (mode == 'R' || mode == 'RUNNING' || speed > 0) {
      derivedStatus = 'Running';
    } else if (mode == 'I' || mode == 'IDLE' || (ignition && speed == 0)) {
      derivedStatus = 'Idle';
    } else if (mode == 'S' || mode == 'STOPPED') {
      derivedStatus = 'Stopped';
    } else if (mode == 'INACTIVE') {
      derivedStatus = 'Inactive';
    }

    return Vehicle(
      id: json['id'] ?? 0,
      plateNumber: json['vehicle_number'] ?? json['name'] ?? '',
      status: derivedStatus,
      statusDuration: json['duration'] ?? '',
      lastUpdated: json['last_update'] ?? json['device_time'] ?? '',
      address:
          json['location'] ??
          json['address'] ??
          (json['latitude'] != null
              ? "${json['latitude']}, ${json['longitude']}"
              : ''),
      speed: speed.toStringAsFixed(1),
      distance: (json['distance'] ?? 0).toString(),
      validityDays: (json['remaining_days'] ?? 0).toString(),
      isIgnitionOn: ignition,
      isLocked: json['lock'] != 0,
      deviceId: (json['imei'] ?? json['device_id'] ?? '').toString(),
    );
  }
}

class HomeController extends GetxController {
  final vehicles = <Vehicle>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final RxInt selectedIndex = 1.obs;

  // Status counts
  final totalCount = "0".obs;
  final runningCount = "0".obs;
  final stoppedCount = "0".obs;
  final idleCount = "0".obs;
  final inactiveCount = "0".obs;

  @override
  void onInit() {
    super.onInit();
    _initializeAndFetch();
  }

  Future<void> _initializeAndFetch() async {
    final token = await getSavedObject('token');
    if (token != null) {
      DioClient().updateToken(token);
    }
    fetchVehicles();
  }

  Future<void> fetchVehicles() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await DioClient().get(
        ApiEndPoints.home,
        query: {'type': ''},
      );

      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];

        // Parse vehicles from vehicles_data list
        if (data['vehicles_data'] != null) {
          final List<dynamic> vehiclesList = data['vehicles_data'];
          vehicles.value = vehiclesList
              .map((json) => Vehicle.fromJson(json))
              .toList();
        }

        // Update counts from statistics object
        if (data['statistics'] != null) {
          final stats = data['statistics'];
          totalCount.value = stats['total_vehicles']?.toString() ?? "0";
          runningCount.value = stats['running_vehicles']?.toString() ?? "0";
          stoppedCount.value = stats['stopped_vehicles']?.toString() ?? "0";
          idleCount.value = stats['idle_vehicles']?.toString() ?? "0";
          inactiveCount.value = stats['expired_vehicles']?.toString() ?? "0";
        } else {
          // Fallback to manual counting if statistics missing
          totalCount.value = vehicles.length.toString();
          runningCount.value = vehicles
              .where((v) => v.status == 'Running')
              .length
              .toString();
          stoppedCount.value = vehicles
              .where((v) => v.status == 'Stopped')
              .length
              .toString();
          idleCount.value = vehicles
              .where((v) => v.status == 'Idle')
              .length
              .toString();
          inactiveCount.value = vehicles
              .where((v) => v.status == 'Inactive')
              .length
              .toString();
        }
      }
    } catch (e) {
      errorMessage.value = "An error occurred: $e";
      print("Error loading data: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void changeTab(int index) {
    selectedIndex.value = index;
  }
}
