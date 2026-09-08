import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Services/ReverseGeocodeService.dart';
import 'package:airotrack/Utils/Utils.dart';

class Vehicle {
  final int id;
  final String plateNumber;
  final String status; // 'Running', 'Stopped', 'Idle', 'Inactive'
  final String statusDuration;
  final String lastUpdated;
  final String address;
  final double? latitude;
  final double? longitude;
  final String speed;
  final String distance;
  /// Today's traveled km from API `today_km`.
  final String todayKm;
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
    this.latitude,
    this.longitude,
    required this.speed,
    required this.distance,
    required this.todayKm,
    required this.validityDays,
    this.isIgnitionOn = false,
    this.isLocked = true,
    required this.deviceId,
  });

  bool get hasValidCoordinates {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    return !(lat == 0 && lng == 0);
  }

  /// Place name for UI — same style as History (no raw lat/lng).
  String get locationLabel {
    final text = address.trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return ReverseGeocodeService.withoutPincode(text);
    }
    if (hasValidCoordinates) return 'Fetching location…';
    return 'Location unavailable';
  }

  Vehicle copyWith({
    String? address,
    double? latitude,
    double? longitude,
  }) {
    return Vehicle(
      id: id,
      plateNumber: plateNumber,
      status: status,
      statusDuration: statusDuration,
      lastUpdated: lastUpdated,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed,
      distance: distance,
      todayKm: todayKm,
      validityDays: validityDays,
      isIgnitionOn: isIgnitionOn,
      isLocked: isLocked,
      deviceId: deviceId,
    );
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final mode = json['mode']?.toString().toUpperCase();
    final speed = double.tryParse(json['speed']?.toString() ?? '0') ?? 0;
    final ignitionRaw = json['ignition'];
    final ignition = ignitionRaw == 1 ||
        ignitionRaw == true ||
        ignitionRaw?.toString() == '1';

    // Prefer explicit status string from API when present (not bool flags).
    final rawStatus =
        json['current_status'] ?? json['vehicle_status'] ?? json['status'];
    final apiStatus = rawStatus is String ? rawStatus.trim() : null;

    final derivedStatus = _resolveVehicleStatus(
      apiStatus: apiStatus,
      mode: mode,
      speed: speed,
      ignition: ignition,
    );

    final lat = double.tryParse(json['latitude']?.toString() ?? '');
    final lng = double.tryParse(json['longitude']?.toString() ?? '');

    final rawAddress =
        (json['location'] ?? json['address'])?.toString().trim() ?? '';
    final address = rawAddress.isNotEmpty &&
            rawAddress.toLowerCase() != 'null' &&
            !_looksLikeRawCoordinates(rawAddress)
        ? ReverseGeocodeService.withoutPincode(rawAddress)
        : '';

    return Vehicle(
      id: json['id'] ?? 0,
      plateNumber: json['vehicle_number'] ?? json['name'] ?? '',
      status: derivedStatus,
      statusDuration: json['duration'] ?? '',
      lastUpdated: json['last_update'] ?? json['device_time'] ?? '',
      address: address,
      latitude: lat,
      longitude: lng,
      speed: speed.toStringAsFixed(1),
      distance: (json['distance'] ?? 0).toString(),
      todayKm: _formatTodayKm(
        json['today_km'] ??
            json['total_kilometers_today'] ??
            json['todayKm'] ??
            json['distance'],
      ),
      validityDays: _daysFromExpiration(
        json['expirationtime'] ??
            json['expiration_time'] ??
            json['expirationTime'],
      ),
      isIgnitionOn: ignition,
      isLocked: json['lock'] != 0,
      deviceId: (json['imei'] ?? json['device_id'] ?? '').toString(),
    );
  }

  static bool _looksLikeRawCoordinates(String value) {
    final parts = value.split(',');
    if (parts.length != 2) return false;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    return lat != null && lng != null;
  }

  static String _formatTodayKm(dynamic raw) {
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0.0;
    if (value == value.roundToDouble()) {
      return '${value.toInt()} Km';
    }
    return '${value.toStringAsFixed(2)} Km';
  }

  /// Days between today and `expirationtime` (calendar days remaining).
  /// Returns `0` when `expirationtime` is missing or invalid.
  static String _daysFromExpiration(dynamic expirationRaw, {dynamic fallback}) {
    final expiry = _parseExpirationDate(expirationRaw);
    if (expiry == null) return '0';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(expiry.year, expiry.month, expiry.day);
    final days = end.difference(today).inDays;
    return days < 0 ? '0' : days.toString();
  }

  static DateTime? _parseExpirationDate(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    final direct = DateTime.tryParse(text);
    if (direct != null) return direct;

    // Common API form: "yyyy-MM-dd HH:mm:ss"
    final withT = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    if (withT != null) return withT;

    final parts = text.split(RegExp(r'[/\-.]'));
    if (parts.length == 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2].split(RegExp(r'\s')).first);
      if (a != null && b != null && c != null) {
        // yyyy-MM-dd vs dd-MM-yyyy
        if (parts[0].length == 4) {
          return DateTime(a, b, c);
        }
        if (parts[2].length == 4) {
          return DateTime(c, b, a);
        }
      }
    }
    return null;
  }

  /// Aligns with live-track modes: M/R = Running, H/I = Idle, S = Stopped.
  static String _resolveVehicleStatus({
    String? apiStatus,
    String? mode,
    required double speed,
    required bool ignition,
  }) {
    if (apiStatus != null && apiStatus.isNotEmpty) {
      final s = apiStatus.toLowerCase();
      if (s.contains('inactive') || s.contains('expired')) return 'Inactive';
      if (s.contains('run') || s.contains('mov')) return 'Running';
      if (s.contains('idle')) return 'Idle';
      if (s.contains('stop')) return 'Stopped';
    }

    final m = mode?.toUpperCase();
    if (m == 'INACTIVE' || m == 'EXPIRED') return 'Inactive';
    // Mode is authoritative — do not override Stopped with noisy speed.
    if (m == 'M' || m == 'R' || m == 'RUNNING' || m == 'MOVING') {
      return 'Running';
    }
    if (m == 'H' || m == 'I' || m == 'IDLE') return 'Idle';
    if (m == 'S' || m == 'STOPPED' || m == 'STOP') return 'Stopped';

    // Fallback when mode is missing.
    if (speed > 1.0) return 'Running';
    if (ignition) return 'Idle';
    return 'Stopped';
  }
}

class HomeController extends GetxController {
  final vehicles = <Vehicle>[].obs;
  final isLoading = false.obs;
  final isMoreLoading = false.obs;
  final hasMore = true.obs;
  final errorMessage = ''.obs;
  final RxInt selectedIndex = 1.obs;
  final ScrollController scrollController = ScrollController();
  int currentPage = 1;
  int _geocodeRunId = 0;

  // Status counts
  final totalCount = "0".obs;
  final runningCount = "0".obs;
  final stoppedCount = "0".obs;
  final idleCount = "0".obs;
  final inactiveCount = "0".obs;

  /// Search query for filtering vehicles (plate number, address, device id).
  final searchQuery = ''.obs;

  /// API type → status: 1 Stopped, 2 Running, 3 Idle, 4 Inactive.
  String? get _selectedStatusFilter {
    switch (selectedType.value) {
      case 1:
        return 'Stopped';
      case 2:
        return 'Running';
      case 3:
        return 'Idle';
      case 4:
        return 'Inactive';
      default:
        return null;
    }
  }

  /// Vehicles for the selected tab (+ search). Always status-filtered on device
  /// so Stopped never appears under Running even if the API mix is wrong.
  List<Vehicle> get filteredVehicles {
    var list = vehicles.toList();
    final status = _selectedStatusFilter;
    if (status != null) {
      list = list.where((v) => v.status == status).toList();
    }

    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where(
          (v) =>
              v.plateNumber.toLowerCase().contains(q) ||
              v.address.toLowerCase().contains(q) ||
              v.deviceId.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    _initializeAndFetch();
    scrollController.addListener(() {
      try {
        if (!scrollController.hasClients) return;
        final position = scrollController.position;
        if (position.pixels >= position.maxScrollExtent - 200) {
          if (!isLoading.value && !isMoreLoading.value && hasMore.value) {
            loadMoreVehicles();
          }
        }
      } catch (_) {
        // ScrollController not attached or has multiple clients (e.g. during rebuild)
      }
    });
  }

  Future<void> _initializeAndFetch() async {
    final token = await getSavedObject('token');
    if (token != null) {
      DioClient().updateToken(token is String ? token : token.toString());
    }
    await fetchVehicles();
  }

  final selectedType = RxnInt();

  Future<void> fetchVehicles({int? type}) async {
    try {
      selectedType.value = type;
      currentPage = 1;
      hasMore.value = true;
      isLoading.value = true;
      errorMessage.value = '';

      final response = await DioClient().get(
        ApiEndPoints.home,
        query: {
          'type': type != null ? type.toString() : '',
          'page': '1',
          'limit': '20',
        },
      );
      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        if (data['vehicles_data'] != null) {
          final List<dynamic> vehiclesList = data['vehicles_data'];
          vehicles.value = _uniqueVehicles(
            vehiclesList.map((json) => Vehicle.fromJson(json)).toList(),
          );
          // No more pages when first page is shorter than the page size.
          hasMore.value = vehiclesList.length >= 20;
          _resolveVehicleAddresses();
        } else {
          vehicles.clear();
          hasMore.value = false;
        }
        if (data['statistics'] != null) {
          final stats = data['statistics'];
          totalCount.value = stats['total_vehicles']?.toString() ?? "0";
          runningCount.value = stats['running_vehicles']?.toString() ?? "0";
          stoppedCount.value = stats['stopped_vehicles']?.toString() ?? "0";
          idleCount.value = stats['idle_vehicles']?.toString() ?? "0";
          inactiveCount.value = stats['expired_vehicles']?.toString() ?? "0";
        } else {
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

  Future<void> loadMoreVehicles() async {
    if (isLoading.value || isMoreLoading.value || !hasMore.value) return;
    try {
      isMoreLoading.value = true;
      final nextPage = currentPage + 1;

      final response = await DioClient().get(
        ApiEndPoints.home,
        query: {
          'type': selectedType.value != null
              ? selectedType.value.toString()
              : '',
          'page': nextPage.toString(),
          'limit': '20',
        },
      );

      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];

        if (data['vehicles_data'] != null) {
          final List<dynamic> vehiclesList = data['vehicles_data'];
          if (vehiclesList.isEmpty) {
            hasMore.value = false;
          } else {
            final newVehicles = vehiclesList
                .map((json) => Vehicle.fromJson(json))
                .toList();
            final unique = _dedupeVehicles(newVehicles);
            if (unique.isEmpty) {
              // API repeated page-1 vehicles — stop paging.
              hasMore.value = false;
            } else {
              final startIndex = vehicles.length;
              vehicles.addAll(unique);
              currentPage = nextPage;
              if (newVehicles.length < 20) {
                hasMore.value = false;
              }
              _resolveVehicleAddresses(startIndex: startIndex);
            }
          }
        } else {
          hasMore.value = false;
        }
      } else {
        hasMore.value = false;
      }
    } catch (e) {
      hasMore.value = false;
    } finally {
      isMoreLoading.value = false;
    }
  }

  /// Keeps only vehicles not already in [vehicles] (by id, else IMEI/plate).
  List<Vehicle> _dedupeVehicles(List<Vehicle> incoming) {
    final existingKeys = <String>{};
    for (final v in vehicles) {
      existingKeys.add(_vehicleKey(v));
    }
    return incoming.where((v) => existingKeys.add(_vehicleKey(v))).toList();
  }

  /// Dedupes within a single page response.
  List<Vehicle> _uniqueVehicles(List<Vehicle> incoming) {
    final seen = <String>{};
    return incoming.where((v) => seen.add(_vehicleKey(v))).toList();
  }

  String _vehicleKey(Vehicle v) {
    if (v.id != 0) return 'id:${v.id}';
    if (v.deviceId.trim().isNotEmpty) return 'imei:${v.deviceId.trim()}';
    return 'plate:${v.plateNumber.trim().toLowerCase()}';
  }

  /// Reverse-geocode home vehicles so the list shows place names like History.
  Future<void> _resolveVehicleAddresses({int startIndex = 0}) async {
    final runId = ++_geocodeRunId;
    final count = vehicles.length;
    if (startIndex < 0 || startIndex >= count) return;

    for (var i = startIndex; i < count; i++) {
      if (isClosed || runId != _geocodeRunId) return;
      if (i >= vehicles.length) return;

      final vehicle = vehicles[i];
      if (!vehicle.hasValidCoordinates) continue;

      final place = await ReverseGeocodeService.instance.reverse(
        vehicle.latitude!,
        vehicle.longitude!,
      );
      if (isClosed || runId != _geocodeRunId) return;
      if (i >= vehicles.length) return;

      if (place != null && place.isNotEmpty) {
        vehicles[i] = vehicle.copyWith(address: place);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  void changeTab(int index) {
    selectedIndex.value = index;
  }

  @override
  void onClose() {
    _geocodeRunId++;
    scrollController.dispose();
    super.onClose();
  }
}
