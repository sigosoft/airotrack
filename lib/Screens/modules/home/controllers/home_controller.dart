import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:airotrack/Configs/ApiConfigs.dart';
import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Utils/Utils.dart';

class Vehicle {
  final int id;
  final String plateNumber;
  final String status; // 'Running', 'Stopped', 'Idle', 'Expired', 'Inactive', 'No data'
  final String statusDuration;
  final String lastUpdated;
  /// Place name from API `location` (home endpoint).
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

  /// Status text shown to the user.
  String get statusLabel => status;

  /// Type number from the rules table; 0 when the status has no type.
  int get typeNumber {
    switch (status) {
      case 'Running':
        return 2;
      case 'Idle':
        return 3;
      case 'Stopped':
        return 4;
      case 'Expired':
        return 5;
      case 'Inactive':
        return 6;
      case 'No data':
        return 7;
      default:
        return 0;
    }
  }

  /// Everything the home card shows. Equal signatures mean nothing visible
  /// changed, so a background refresh can skip the rebuild.
  String get signature => [
        id,
        plateNumber,
        status,
        statusDuration,
        lastUpdated,
        address,
        latitude,
        longitude,
        speed,
        distance,
        todayKm,
        validityDays,
        isIgnitionOn,
        isLocked,
        deviceId,
      ].join('|');

  /// The table rule that gives this vehicle its status.
  String get ruleText {
    switch (status) {
      case 'Running':
        return 'ignition = 1, speed > 0, last_update within 5 min';
      case 'Idle':
        return 'ignition = 1 and not running';
      case 'Stopped':
        return 'ignition = 0';
      case 'Inactive':
        return 'last_update older than 45 min';
      case 'No data':
        return 'no last_update in the cache';
      case 'Expired':
        return 'expirationtime in the past';
      default:
        return '';
    }
  }

  /// Display text from API `location` (no client reverse-geocode).
  String get locationLabel {
    final text = address.trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    return 'Location unavailable';
  }

  Vehicle copyWith({
    String? status,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    return Vehicle(
      id: id,
      plateNumber: plateNumber,
      status: status ?? this.status,
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
    final speed = double.tryParse(json['speed']?.toString() ?? '0') ?? 0;
    final ignitionRaw = json['ignition'];
    final ignition = ignitionRaw == 1 ||
        ignitionRaw == true ||
        ignitionRaw?.toString() == '1';

    final derivedStatus = statusByRule(
      lastUpdate: (json['last_update'] ?? '').toString(),
      expiry: _parseExpirationDate(json['expirationtime']),
      speed: speed,
      ignition: ignition,
      now: DateTime.now(),
    );

    final lat = double.tryParse(json['latitude']?.toString() ?? '');
    final lng = double.tryParse(json['longitude']?.toString() ?? '');

    // API `location` only (no reverse-geocode / no address fallbacks).
    final locationRaw = json['location'];
    String address = '';
    if (locationRaw is String) {
      final text = locationRaw.trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        address = text;
      }
    }

    return Vehicle(
      id: json['id'] ?? 0,
      plateNumber: (json['vehicle_number'] ?? json['name'] ?? '').toString(),
      status: derivedStatus,
      statusDuration: (json['duration'] ?? '').toString(),
      lastUpdated:
          (json['last_update'] ?? json['device_time'] ?? '').toString(),
      address: address,
      latitude: lat,
      longitude: lng,
      speed: speed.toStringAsFixed(1),
      distance: (json['distance'] ?? 0).toString(),
      todayKm: _formatTodayKm(json['today_km']),
      validityDays: _daysFromExpiration(json['expirationtime']),
      isIgnitionOn: ignition,
      isLocked: json['lock'] != 0,
      deviceId: (json['imei'] ?? json['device_id'] ?? '').toString(),
    );
  }

  static String _formatTodayKm(dynamic raw) {
    if (raw == null) return '0 Km';
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw.toString()) ?? 0.0;
    if (value == value.roundToDouble()) {
      return '${value.toInt()} Km';
    }
    return '${value.toStringAsFixed(2)} Km';
  }

  /// Days between today and API `expirationtime` (calendar days remaining).
  /// Returns `0` when missing or invalid — no other field fallbacks.
  static String _daysFromExpiration(dynamic expirationRaw) {
    final expiry = _parseExpirationDate(expirationRaw);
    if (expiry == null) return '0';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(expiry.year, expiry.month, expiry.day);
    final days = end.difference(today).inDays;
    return days < 0 ? '0' : days.toString();
  }

  /// Parses API values like `2027-04-24 12:00:00`.
  static DateTime? _parseExpirationDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;

    // Prefer string/num only — avoid toString() on unexpected Map/List payloads.
    final String text;
    if (raw is String) {
      text = raw.trim();
    } else if (raw is num) {
      // Treat large values as unix seconds.
      if (raw > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(
          (raw > 1000000000000 ? raw : raw * 1000).toInt(),
        );
      }
      text = raw.toString();
    } else {
      return null;
    }

    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    // "yyyy-MM-dd HH:mm:ss" → ISO-friendly
    final normalized = text.contains('T')
        ? text
        : text.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized) ?? DateTime.tryParse(text);
  }

  /// Status from the table's rules, checked in this order:
  /// No data, Expired, Inactive, Running, Idle, Stopped.
  /// The table does not give an order; Inactive is checked before Stopped
  /// because an old update with ignition off is Inactive.
  static String statusByRule({
    required String lastUpdate,
    required DateTime? expiry,
    required double speed,
    required bool ignition,
    required DateTime now,
  }) {
    final text = lastUpdate.trim();
    final updated = text.isEmpty ? null : DateTime.tryParse(text);
    if (updated == null) return 'No data';
    if (expiry != null && expiry.isBefore(now)) return 'Expired';

    final age = now.difference(updated);
    if (age > const Duration(minutes: 45)) return 'Inactive';
    if (ignition && speed > 0 && age <= const Duration(minutes: 5)) {
      return 'Running';
    }
    if (ignition) return 'Idle';
    return 'Stopped';
  }
}

class HomeController extends GetxController with WidgetsBindingObserver {
  /// How often the home list refreshes itself in the background.
  /// A tick is skipped while the previous request is still in flight, so a
  /// slow server never stacks requests.
  static const Duration autoRefreshInterval = Duration(seconds: 3);

  Timer? _autoRefreshTimer;
  bool _silentRefreshBusy = false;
  bool _appInForeground = true;

  final vehicles = <Vehicle>[].obs;
  final isLoading = false.obs;
  final isMoreLoading = false.obs;
  final hasMore = true.obs;
  final errorMessage = ''.obs;
  final RxInt selectedIndex = 1.obs;
  final ScrollController scrollController = ScrollController();
  int currentPage = 1;

  // Status counts
  final totalCount = "0".obs;
  final runningCount = "0".obs;
  final stoppedCount = "0".obs;
  final idleCount = "0".obs;
  final expiredCount = "0".obs;
  final inactiveVehiclesCount = "0".obs;
  final noDataCount = "0".obs;

  /// Search query for filtering vehicles (plate number, address, device id).
  final searchQuery = ''.obs;

  /// Vehicles for the selected type (1 All, 2 Running, 3 Idle, 4 Stop,
  /// 5 Expired) as returned by the API, narrowed by search only.
  List<Vehicle> get filteredVehicles {
    var list = vehicles.toList();

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
    WidgetsBinding.instance.addObserver(this);
    _initializeAndFetch();
    _startAutoRefresh();
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

  // ---------------------------------------------------------------------
  // Automatic refresh
  // ---------------------------------------------------------------------

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer =
        Timer.periodic(autoRefreshInterval, (_) => refreshSilently());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _appInForeground) return;
    _appInForeground = foreground;
    if (foreground) {
      // Back in the app: show fresh data now, then keep the timer going.
      refreshSilently();
      _startAutoRefresh();
    } else {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
    }
  }

  // ---------------------------------------------------------------------
  // One list, one set of rules
  //
  // The server's type lists and counts follow its own rules: it counts every
  // vehicle with ignition off as "stopped", inactive ones included. The app
  // labels each vehicle with the rules table (Vehicle.statusByRule), so an
  // inactive vehicle showed in the Stop tab with an Inactive label, and the
  // counts didn't match the lists. Now all vehicles are loaded once (type 1)
  // and every tab and count is built from the app's own status.
  // ---------------------------------------------------------------------

  /// Every vehicle (type 1), for the counts and for filtering the tabs.
  final allVehicles = <Vehicle>[].obs;

  /// One page large enough for the whole fleet.
  static const int _fetchLimit = 500;

  /// Vehicles for tab [type]: 1 = all, else the app's type number
  /// (2 Running, 3 Idle, 4 Stop, 5 Expired, 6 Inactive, 7 No data).
  List<Vehicle> _forType(List<Vehicle> all, int type) =>
      type <= 1 ? all : all.where((v) => v.typeNumber == type).toList();

  /// Every vehicle from the API, or null when the request failed.
  Future<List<Vehicle>?> _fetchAll() async {
    final response = await DioClient().get(
      ApiEndPoints.home,
      query: {'type': '1', 'page': '1', 'limit': '$_fetchLimit'},
    );
    final data = response.data is Map ? response.data['data'] : null;
    if (data is! Map) return null;
    final rows = data['vehicles_data'];
    if (rows is! List) return const [];
    return _uniqueVehicles(_parseVehicles(rows));
  }

  /// Shows [all]: the selected tab's list and every count, changing the
  /// observables only when something visible changed (no blink).
  void _applyAll(List<Vehicle> all) {
    if (!_sameVehicles(allVehicles, all)) allVehicles.assignAll(all);
    final shown = _forType(all, selectedType.value ?? 1);
    if (!_sameVehicles(vehicles, shown)) vehicles.assignAll(shown);
    _applyCounts(all);
  }

  /// RxString only notifies on a real change, so unchanged counts never
  /// rebuild the status cards.
  void _applyCounts(List<Vehicle> all) {
    String countOf(int type) =>
        all.where((v) => v.typeNumber == type).length.toString();
    totalCount.value = all.length.toString();
    runningCount.value = countOf(2);
    idleCount.value = countOf(3);
    stoppedCount.value = countOf(4);
    expiredCount.value = countOf(5);
    inactiveVehiclesCount.value = countOf(6);
    noDataCount.value = countOf(7);
  }

  /// Re-reads every vehicle without the loading spinner and only touches the
  /// observable lists when something visible changed, so the screen never
  /// blinks. Errors keep the current list.
  Future<void> refreshSilently() async {
    if (!_appInForeground) return;
    if (_silentRefreshBusy || isLoading.value) return;
    _silentRefreshBusy = true;
    try {
      final all = await _fetchAll();
      // A full load started meanwhile (pull to refresh): let it win.
      if (isClosed || isLoading.value || all == null) return;
      _applyAll(all);
    } catch (e) {
      debugPrint('[Home] auto refresh skipped: $e');
    } finally {
      _silentRefreshBusy = false;
    }
  }

  List<Vehicle> _parseVehicles(List<dynamic> rows) {
    final parsed = <Vehicle>[];
    for (final row in rows) {
      try {
        final map = row is Map<String, dynamic>
            ? row
            : Map<String, dynamic>.from(row as Map);
        parsed.add(Vehicle.fromJson(map));
      } catch (e) {
        debugPrint('[Home] skip vehicle parse error: $e');
      }
    }
    return parsed;
  }

  bool _sameVehicles(List<Vehicle> a, List<Vehicle> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].signature != b[i].signature) return false;
    }
    return true;
  }

  /// Shows tab [type]. Switching tabs filters the vehicles already loaded at
  /// once (no spinner) and refreshes in the background; the first load, or
  /// pull to refresh, loads every vehicle with the spinner.
  Future<void> fetchVehicles({int? type, bool force = false}) async {
    selectedType.value = type ?? 1;
    currentPage = 1;
    hasMore.value = false; // one page holds the whole fleet
    errorMessage.value = '';

    if (allVehicles.isNotEmpty && !force) {
      _applyAll(allVehicles.toList());
      refreshSilently();
      return;
    }

    try {
      isLoading.value = true;
      final all = await _fetchAll();
      if (all != null) _applyAll(all);
    } catch (e) {
      errorMessage.value = "An error occurred: $e";
      debugPrint("Error loading data: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// Every vehicle is in one page now, so there is nothing more to load.
  Future<void> loadMoreVehicles() async {}

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

  void changeTab(int index) {
    selectedIndex.value = index;
  }

  @override
  void onClose() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    scrollController.dispose();
    super.onClose();
  }
}
