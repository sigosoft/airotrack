# Vehicle Travel History on Map – Implementation Package

Use this file to add **vehicle travel history on a map** (date range, polyline route, optional playback) to another Flutter project. Replace `YOUR_PACKAGE_NAME` with your app’s package name (e.g. from `pubspec.yaml`).

---

## 1. Dependencies (add to `pubspec.yaml`)

```yaml
dependencies:
  google_maps_flutter: ^2.10.1
  geolocator: ^14.0.1
  dio: ^5.8.0+1
  get: ^4.7.2
  shared_preferences: ^2.5.3
```

---

## 2. Assets

- Add a **vehicle/marker icon** for the moving marker (e.g. `lib/assets/image/marker2.png` or `assets/images/marker2.png`).
- Register the folder in `pubspec.yaml` under `flutter: assets:` (e.g. `assets/images/` or `lib/assets/image/`).

---

## 3. API configuration

Your backend should expose a **vehicle history** endpoint that accepts:

- `imei` (query)
- `from_date` (query, e.g. `yyyy-MM-dd`)
- `to_date` (query, e.g. `yyyy-MM-dd`)
- Header: `Authorization: Bearer <token>`

Response JSON shape expected by the model:

- Top level: `status`, `message`, `data`.
- `data.location_history`: list of objects with at least:
  - `latitude`, `longitude` (numeric or string)
  - Optional: `devicetime`, `speed`, `mode`, `ignition`, `power`, `alert_id`, `created_at`, `is_stopped`

Adjust `ApiConfigs.BASE_URL` and `ApiEndPoints.vehicleHistory` to match your API.

---

## 4. Files to add or update

### 4.1 Routes

**File: `lib/AppRoutes/AppRoutes.dart`** (add constant)

```dart
static const String history = '/history';
```

**File: `lib/AppRoutes/RoutePages.dart`** (add GetPage)

```dart
GetPage(
  name: AppRoutes.history,
  page: () => HistoryScreen(imei: Get.parameters['imei'] ?? ''),
),
```

**File: `lib/main.dart`** (if using custom toast with overlay)

```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// and pass navigatorKey to GetMaterialApp / MaterialApp
```

---

### 4.2 API config

**File: `lib/ApiConfigs/ApiConfigs.dart`**

```dart
class ApiConfigs {
  static String BASE_URL = "https://api.airotrack.in/website/";
  static String IMAGE_URL = "";
}

class ApiEndPoints {
  static String login = "login";
  static String home = "home";
  static String vehicleHistory = "track_vehicle";
}
```

---

### 4.3 Model

**File: `lib/Model/VehicleTrackingModel.dart`**

```dart
class VehicleTrackingModel {
  final bool status;
  final Data? data;
  final String message;

  VehicleTrackingModel({
    required this.status,
    this.data,
    required this.message,
  });

  factory VehicleTrackingModel.fromJson(Map<String, dynamic>? json) {
    return VehicleTrackingModel(
      status: json?['status'] ?? false,
      data: json?['data'] != null ? Data.fromJson(json?['data']) : null,
      message: json?['message'] ?? '',
    );
  }
}

class Data {
  final VehicleInfo? vehicleInfo;
  final List<LocationDetails> locationHistory;
  final StopAnalysis? stopAnalysis;
  final SpeedStatistics? speedStatistics;
  final DateRange? dateRange;
  final int totalRecords;

  Data({
    this.vehicleInfo,
    required this.locationHistory,
    this.stopAnalysis,
    this.speedStatistics,
    this.dateRange,
    required this.totalRecords,
  });

  factory Data.fromJson(Map<String, dynamic>? json) {
    return Data(
      vehicleInfo: json?['vehicle_info'] != null
          ? VehicleInfo.fromJson(json?['vehicle_info'])
          : null,
      locationHistory: (json?['location_history'] as List<dynamic>?)
          ?.map((e) => LocationDetails.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      stopAnalysis: json?['stop_analysis'] != null
          ? StopAnalysis.fromJson(json?['stop_analysis'])
          : null,
      speedStatistics: json?['speed_statistics'] != null
          ? SpeedStatistics.fromJson(json?['speed_statistics'])
          : null,
      dateRange: json?['date_range'] != null
          ? DateRange.fromJson(json?['date_range'])
          : null,
      totalRecords: json?['total_records'] ?? 0,
    );
  }
}

class VehicleInfo {
  final int id;
  final String vehicleNumber;
  final String imei;
  final int ignition;
  final int power;
  final int gnssFix;
  final String lastUpdate;
  final String latitude;
  final String longitude;
  final String mode;
  final double speed;
  final String expirationTime;

  VehicleInfo({
    required this.id,
    required this.vehicleNumber,
    required this.imei,
    required this.ignition,
    required this.power,
    required this.gnssFix,
    required this.lastUpdate,
    required this.latitude,
    required this.longitude,
    required this.mode,
    required this.speed,
    required this.expirationTime,
  });

  factory VehicleInfo.fromJson(Map<String, dynamic>? json) {
    return VehicleInfo(
      id: json?['id'] ?? 0,
      vehicleNumber: json?['vehicle_number'] ?? '',
      imei: json?['imei'] ?? '',
      ignition: json?['ignition'] ?? 0,
      power: json?['power'] ?? 0,
      gnssFix: json?['gnss_fix'] ?? 0,
      lastUpdate: json?['last_update'] ?? '',
      latitude: json?['latitude'] ?? '',
      longitude: json?['longitude'] ?? '',
      mode: json?['mode'] ?? '',
      speed: json?['speed'] != null
          ? double.tryParse(json!['speed'].toString()) ?? 0.0
          : 0.0,
      expirationTime: json?['expirationtime'] ?? '',
    );
  }
}

class StopAnalysis {
  final int totalStops;
  final List<dynamic> stopLocations;

  StopAnalysis({required this.totalStops, required this.stopLocations});

  factory StopAnalysis.fromJson(Map<String, dynamic>? json) {
    return StopAnalysis(
      totalStops: json?['total_stops'] ?? 0,
      stopLocations: json?['stop_locations'] != null
          ? List<dynamic>.from(json?['stop_locations'] ?? [])
          : [],
    );
  }
}

class SpeedStatistics {
  final dynamic averageSpeed;
  final dynamic maximumSpeed;

  SpeedStatistics({required this.averageSpeed, required this.maximumSpeed});

  factory SpeedStatistics.fromJson(Map<String, dynamic>? json) {
    return SpeedStatistics(
      averageSpeed: (json?['average_speed'] ?? 0.0).toDouble(),
      maximumSpeed: (json?['maximum_speed'] ?? ""),
    );
  }
}

class DateRange {
  final String fromDate;
  final String toDate;

  DateRange({required this.fromDate, required this.toDate});

  factory DateRange.fromJson(Map<String, dynamic>? json) {
    return DateRange(
      fromDate: json?['from_date'] ?? '',
      toDate: json?['to_date'] ?? '',
    );
  }
}

class LocationDetails {
  final String? imei;
  final String? deviceTime;
  final double? latitude;
  final double? longitude;
  final double? speed;
  final String? mode;
  final bool? ignition;
  final bool? power;
  final int? alertId;
  final String? createdAt;
  final bool? isStopped;

  LocationDetails({
    this.imei,
    this.deviceTime,
    this.latitude,
    this.longitude,
    this.speed,
    this.mode,
    this.ignition,
    this.power,
    this.alertId,
    this.createdAt,
    this.isStopped,
  });

  factory LocationDetails.fromJson(Map<String, dynamic> json) {
    return LocationDetails(
      imei: json['imei'] as String?,
      deviceTime: json['devicetime'] as String?,
      latitude: (json['latitude'] != null)
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: (json['longitude'] != null)
          ? double.tryParse(json['longitude'].toString())
          : null,
      speed: (json['speed'] != null)
          ? double.tryParse(json['speed'].toString())
          : null,
      mode: json['mode'] as String?,
      ignition: json['ignition'] == null
          ? null
          : (json['ignition'] == 1 || json['ignition'] == true),
      power: json['power'] == null
          ? null
          : (json['power'] == 1 || json['power'] == true),
      alertId: json['alert_id'] != null
          ? int.tryParse(json['alert_id'].toString())
          : null,
      createdAt: json['created_at'] as String?,
      isStopped: json['is_stopped'] as bool?,
    );
  }
}
```

---

### 4.4 Utils (format date, bearing, shared prefs, toast)

**File: `lib/Utils/UtilityFunctions/DateTimeFormatting.dart`**

```dart
String formatDate(String dateTimeString) {
  try {
    DateTime parsedDate = DateTime.parse(dateTimeString);
    return "${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}";
  } catch (e) {
    return dateTimeString;
  }
}
```

**File: `lib/Utils/UtilityFunctions/getBearing.dart`**

```dart
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

double getBearing(LatLng start, LatLng end) {
  final lat1 = start.latitude * math.pi / 180.0;
  final lon1 = start.longitude * math.pi / 180.0;
  final lat2 = end.latitude * math.pi / 180.0;
  final lon2 = end.longitude * math.pi / 180.0;
  final dLon = lon2 - lon1;
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  final bearing = math.atan2(y, x);
  return (bearing * 180.0 / math.pi + 360.0) % 360.0;
}
```

**File: `lib/Utils/UtilityFunctions/SharedPrefUtils.dart`**

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

saveObject(String key, value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(value));
  } catch (e) {
    throw e;
  }
}

Future<String?> getSavedObject(String key) async {
  final prefs = await SharedPreferences.getInstance();
  var data = prefs.getString(key);
  return data != null ? json.decode(data) : null;
}
```

**File: `lib/Utils/UtilityFunctions/FlutterToast.dart`** (minimal – uses SnackBar so no navigatorKey/image needed)

```dart
import 'package:flutter/material.dart';

void showToast({
  required String message,
  Duration duration = const Duration(seconds: 2),
}) {
  // Call from a context that has Scaffold: use ScaffoldMessenger.of(context).showSnackBar
  // If you have a global navigatorKey: navigatorKey.currentContext
  final ctx = WidgetsBinding.instance.platformDispatcher.views.first;
  // Fallback: app should call showToast with BuildContext or use a global key
  // For simplicity, this signature matches the original; pass context from caller if needed.
  debugPrint('Toast: $message');
}

void showToastWithContext(BuildContext context, {required String message}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
}
```

Your app must provide **`void showToast({required String message})`** (used by HistoryController). Options:
- Use **fluttertoast**: `Fluttertoast.showToast(msg: message);` and implement `showToast` as a wrapper.
- Or use **SnackBar** with a global `BuildContext` (e.g. `navigatorKey.currentContext`) and implement `showToast` to call `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));`
- Or keep your existing toast helper and ensure it has the same signature.

---

### 4.5 Isolate API + parsing

**File: `lib/Controller/IsolateFunctions.dart`**

Replace `YOUR_PACKAGE_NAME` with your package name.

```dart
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:YOUR_PACKAGE_NAME/ApiConfigs/ApiConfigs.dart';
import 'package:YOUR_PACKAGE_NAME/Model/VehicleTrackingModel.dart';

Future<Map<String, dynamic>> fetchVehicleHistoryIsolate(
    Map<String, String> params) async {
  final Dio dio = Dio();
  final String url = ApiConfigs.BASE_URL + ApiEndPoints.vehicleHistory;
  final imei = params['imei'] ?? '';
  final fromDate = params['from_Date'] ?? '';
  final toDate = params['to_Date'] ?? '';
  final token = params['token'] ?? '';
  final response = await dio.get(
    url,
    options: Options(headers: {'Authorization': 'Bearer $token'}),
    queryParameters: {'imei': imei, 'from_date': fromDate, 'to_date': toDate},
  );
  return {
    'statusCode': response.statusCode,
    'data': response.data,
    'queryParams': response.requestOptions.queryParameters,
  };
}

VehicleTrackingModel parseVehicleTrackingModel(Map<String, dynamic> json) {
  return VehicleTrackingModel.fromJson(json);
}

List<LatLng> processChunkData(Map<String, dynamic> data) {
  final List<LatLng> chunkSmoothed = [];
  if (data['matchings'] != null && data['matchings'].isNotEmpty) {
    final coords = data['matchings'][0]['geometry']['coordinates'];
    for (var c in coords) {
      chunkSmoothed.add(LatLng(c[1], c[0]));
    }
  }
  return chunkSmoothed;
}
```

---

### 4.6 History controller

**File: `lib/Controller/HistoryController.dart`**

Replace `YOUR_PACKAGE_NAME` and the marker asset path (`lib/assets/image/marker2.png`) as needed.

```dart
import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:YOUR_PACKAGE_NAME/Model/VehicleTrackingModel.dart';
import 'package:YOUR_PACKAGE_NAME/Utils/UtilityFunctions/DateTimeFormatting.dart';
import 'package:YOUR_PACKAGE_NAME/Utils/UtilityFunctions/SharedPrefUtils.dart';
import 'package:YOUR_PACKAGE_NAME/Utils/UtilityFunctions/getBearing.dart';
import 'package:YOUR_PACKAGE_NAME/Utils/UtilityFunctions/FlutterToast.dart';
import 'package:YOUR_PACKAGE_NAME/Controller/IsolateFunctions.dart';

class HistoryController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    getToken();
    getIcons();
  }

  @override
  void onClose() {
    super.onClose();
  }

  late GoogleMapController mapController;
  Marker? deliveryMarker;
  Timer? locationTimer;
  int currentIndex = 0;
  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  Set<Polyline> polylines = {};
  List<LatLng> mockPath = [];
  List<LatLng> travelPath = [];
  BitmapDescriptor? icon;
  bool playButtonValue = false;

  double _degToRad(double deg) => deg * (pi / 180);
  bool isLoading = false;
  String token = '';
  String imeiNumber = "";

  getIcons() async {
    var icon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration.empty,
      "lib/assets/image/marker2.png",
    );
    this.icon = icon;
    update();
  }

  int currentSegment = 0;
  Timer? animationTimer;

  void startSmoothMovement(TickerProvider vsync) {
    if (travelPath.length < 2) return;
    animateToNextPoint(vsync);
  }

  AnimationController? _controller;
  Animation<double>? _animation;
  Set<Marker> markers = {};

  void animateToNextPoint(TickerProvider vsync) async {
    if (currentSegment >= travelPath.length - 1) {
      _controller?.dispose();
      return;
    }
    LatLng start = travelPath[currentSegment];
    LatLng end = travelPath[currentSegment + 1];
    double distance = Geolocator.distanceBetween(
      start.latitude, start.longitude,
      end.latitude, end.longitude,
    );
    Duration totalDuration = Duration(
      milliseconds: (distance * 1).toInt().clamp(1500, 8000),
    );
    _controller?.dispose();
    _controller = AnimationController(
      vsync: vsync,
      duration: totalDuration,
    );
    _animation = CurvedAnimation(parent: _controller!, curve: Curves.linear);

    _controller!.addListener(() {
      double t = _animation!.value;
      double lat = lerp(start.latitude, end.latitude, t);
      double lng = lerp(start.longitude, end.longitude, t);
      LatLng interpolatedPos = LatLng(lat, lng);
      double bearing = getBearing(start, interpolatedPos);
      _updateMarker(interpolatedPos, bearing, icon!);
      update();
      if ((_controller!.lastElapsedDuration?.inMilliseconds ?? 0) % 300 == 0) {
        mapController.animateCamera(CameraUpdate.newLatLng(interpolatedPos));
      }
    });
    _controller!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        currentSegment++;
        animateToNextPoint(vsync);
      }
    });
    _controller!.forward();
  }

  double lerp(double a, double b, double t) => a + (b - a) * t;

  void _updateMarker(LatLng pos, double bearing, BitmapDescriptor icon) {
    final updatedMarker = Marker(
      markerId: const MarkerId("delivery"),
      position: pos,
      icon: icon,
      rotation: bearing,
      anchor: const Offset(0.5, 0.5),
    );
    markers.removeWhere((m) => m.markerId == updatedMarker.markerId);
    markers.add(updatedMarker);
    update();
  }

  Future<void> getPolyline(List<LatLng> polyLinePath) async {
    Polyline polyline = Polyline(
      polylineId: PolylineId("mockRoute"),
      points: polyLinePath,
      color: Colors.blue,
      width: 4,
    );
    polylines.add(polyline);
    update();
  }

  void getToken() async {
    token = await getSavedObject("token") ?? "";
  }

  Future<void> runInIsolate() async {
    try {
      polylines.clear();
      travelPath.clear();
      mockPath.clear();
      markers.clear();
      update();

      final result = await compute(fetchVehicleHistoryIsolate, {
        'imei': imeiNumber,
        'from_Date': fromDateController.text,
        'to_Date': toDateController.text,
        'token': token,
      });
      if (result['statusCode'] == 200) {
        VehicleTrackingModel historyData = await compute(
          parseVehicleTrackingModel,
          result['data'] as Map<String, dynamic>,
        );
        await convertingToLatLng(historyData);
      } else {
        showToast(message: "Request failed");
      }
    } catch (e, stackTrace) {
      debugPrint("Error: $e");
      debugPrint("StackTrace: $stackTrace");
      showToast(message: "Something went wrong, please try again");
    }
  }

  Future<void> convertingToLatLng(VehicleTrackingModel historyData) async {
    try {
      mockPath = historyData.data?.locationHistory
              .map((e) => LatLng(e.latitude ?? 0.0, e.longitude ?? 0.0))
              .toList() ?? [];
      mockPath = mockPath.where((p) {
        return p.latitude != 0 && p.longitude != 0 &&
            p.latitude.abs() <= 90 && p.longitude.abs() <= 180;
      }).toList();
      const double minDistance = 0.0005;
      List<LatLng> minimized = [];
      LatLng? lastPoint;
      for (var point in mockPath) {
        if (lastPoint == null) {
          minimized.add(point);
          lastPoint = point;
        } else {
          double distance = _calculateDistance(lastPoint, point);
          if (distance > minDistance) {
            minimized.add(point);
            lastPoint = point;
          }
        }
      }
      mockPath = minimized;
      await segregatingMockPath();
    } catch (e, stack) {
      debugPrint("Error in convertingToLatLng: $e");
      showToast(message: "Error processing route");
    }
  }

  Future<void> segregatingMockPath() async {
    final dio = Dio();
    List<LatLng> smoothedPath = [];
    try {
      isLoading = true;
      update();
      for (int i = 0; i < mockPath.length; i += 20) {
        final chunk = mockPath.sublist(
          i,
          i + 20 > mockPath.length ? mockPath.length : i + 20,
        );
        final coords = chunk
            .map((p) => "${p.longitude},${p.latitude}")
            .join(";");
        final url =
            "http://router.project-osrm.org/match/v1/driving/$coords?geometries=geojson&overview=full";
        final response = await dio.get(url);
        if (response.statusCode == 200) {
          final chunkSmoothed =
              await compute<Map<String, dynamic>, List<LatLng>>(
                processChunkData,
                response.data as Map<String, dynamic>,
              );
          if (smoothedPath.isNotEmpty &&
              chunkSmoothed.isNotEmpty &&
              smoothedPath.last == chunkSmoothed.first) {
            chunkSmoothed.removeAt(0);
          }
          smoothedPath.addAll(chunkSmoothed);
          travelPath.addAll(chunkSmoothed);
          getPolyline(chunkSmoothed);
        }
      }
      if (smoothedPath.isEmpty) {
        showToast(message: "No data found for the selected date range");
      }
    } catch (e, stackTrace) {
      debugPrint("Error processing chunks: $e\n$stackTrace");
      showToast(message: "Error drawing route");
    } finally {
      isLoading = false;
      update();
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const double R = 6371;
    double dLat = _degToRad(p2.latitude - p1.latitude);
    double dLon = _degToRad(p2.longitude - p1.longitude);
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degToRad(p1.latitude)) *
            cos(_degToRad(p2.latitude)) *
            (sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> selectFromDate(BuildContext context) async {
    DateTime? fromDate;
    final DateTime? selected = await showDatePicker(
      helpText: "From Date",
      context: context,
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue,
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (selected != null && selected != fromDate) {
      fromDate = selected;
      fromDateController.text = formatDate(fromDate.toString());
      update();
    }
  }

  Future<void> selectToDate(BuildContext context) async {
    DateTime? toDate;
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue,
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (selected != null && selected != toDate) {
      toDate = selected;
      toDateController.text = formatDate(toDate.toString());
      update();
    }
  }

  void onPlayTapped(TickerProvider vsync) {
    try {
      playButtonValue = !playButtonValue;
      startSmoothMovement(vsync);
      update();
    } catch (e, stackTrace) {
      debugPrint("Error in onPlayTapped: $e");
    }
  }

  void onTapSubmit() {
    try {
      if (imeiNumber.toString().isEmpty ||
          imeiNumber.toString().toLowerCase() == "null") {
        showToast(message: "IMEI is missing");
        return;
      }
      if (fromDateController.text.isEmpty) {
        showToast(message: "Please select From Date");
        return;
      }
      if (toDateController.text.isEmpty) {
        showToast(message: "Please select To Date");
        return;
      }
      runInIsolate();
    } catch (e, stackTrace) {
      debugPrint("Error in onTapSubmit: $e");
      showToast(message: "Something went wrong, please try again");
    }
  }

  void onMapCreated(GoogleMapController googleMapController) async {
    await Future.delayed(const Duration(milliseconds: 300));
    mapController = googleMapController;
    if (mockPath.isNotEmpty) {
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(mockPath.first, 8),
      );
    } else {
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(const LatLng(9.9312, 76.2673), 8),
      );
    }
  }

  void imeiInitialAssign(String? imei) {
    try {
      if (imei != null && imei.isNotEmpty && imei.toLowerCase() != "null") {
        imeiNumber = imei;
      }
    } catch (e, stackTrace) {
      debugPrint("Error in imeiInitialAssign: $e");
    }
  }
}
```

---

### 4.7 History screen UI

**File: `lib/View/HistoryScreen/HistoryScreen.dart`**

Replace `YOUR_PACKAGE_NAME`. Ensure you have a `ShowButtonWidget` and `PlayBackControllingWidget` (or inline equivalent). Colors can be your app’s theme.

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:YOUR_PACKAGE_NAME/Controller/HistoryController.dart';
import 'package:YOUR_PACKAGE_NAME/Utils/Widgets/ShowButtonWidget.dart';
import 'package:YOUR_PACKAGE_NAME/Utils/Widgets/PlayBackControllingWidget.dart';

class HistoryScreen extends StatefulWidget {
  final String imei;

  const HistoryScreen({super.key, required this.imei});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "History",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF009FE3),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: SizedBox(
          width: media.width,
          child: GetBuilder<HistoryController>(
            init: HistoryController(),
            didChangeDependencies: (state) {
              state.controller?.imeiInitialAssign(widget.imei);
            },
            builder: (controller) => Padding(
              padding: EdgeInsets.symmetric(horizontal: media.width * 0.02),
              child: Column(
                children: [
                  SizedBox(height: media.height * 0.02),
                  Container(
                    height: media.height * 0.45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(9.9312, 76.2673),
                        ),
                        markers: controller.markers,
                        polylines: controller.polylines,
                        onMapCreated: (googleMapController) =>
                            controller.onMapCreated(googleMapController),
                        gestureRecognizers:
                            <Factory<OneSequenceGestureRecognizer>>{
                          Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: media.height * 0.02),
                  PlayBackControllingWidget(
                    playValue: controller.playButtonValue,
                    onPlayTapped: () => controller.onPlayTapped(this),
                    fromDate: controller.fromDateController.text,
                    toDate: controller.toDateController.text,
                    onFromDateTapped: () => controller.selectFromDate(context),
                    onToDateTapped: () => controller.selectToDate(context),
                  ),
                  SizedBox(height: media.height * 0.02),
                  controller.isLoading
                      ? SizedBox(
                          height: media.height * 0.02,
                          width: media.width * 0.05,
                          child: CircularProgressIndicator(
                            color: Color(0xFF12A370),
                          ),
                        )
                      : GestureDetector(
                          onTap: () => controller.onTapSubmit(),
                          child: Container(
                            width: media.width * 0.4,
                            height: media.height * 0.05,
                            decoration: BoxDecoration(
                              color: Color(0xFF005F06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "Show",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

If you keep `ShowButtonWidget` and `PlayBackControllingWidget`, use this instead of the inline button:

```dart
ShowButtonWidget(
  media: media,
  buttonText: "Show",
  onTap: () => controller.onTapSubmit(),
),
```

---

### 4.8 Playback + date widget (optional but used by screen above)

**File: `lib/Utils/Widgets/PlayBackControllingWidget.dart`**

Replace `YOUR_PACKAGE_NAME` and adjust colors if needed.

```dart
import 'package:flutter/material.dart';

class PlayBackControllingWidget extends StatelessWidget {
  final VoidCallback onFromDateTapped;
  final VoidCallback onToDateTapped;
  final String fromDate;
  final String toDate;
  final VoidCallback onPlayTapped;
  final bool playValue;

  const PlayBackControllingWidget({
    super.key,
    required this.onFromDateTapped,
    required this.onToDateTapped,
    required this.fromDate,
    required this.toDate,
    required this.onPlayTapped,
    required this.playValue,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    return Card(
      elevation: 5,
      child: Container(
        padding: EdgeInsets.all(media.width * 0.02),
        margin: EdgeInsets.symmetric(
          horizontal: media.width * 0.02,
          vertical: media.height * 0.01,
        ),
        width: double.infinity,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: onFromDateTapped,
                  child: Row(
                    children: [
                      Text("From Date :  ", style: TextStyle(fontSize: 13)),
                      Text(fromDate, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onToDateTapped,
                  child: Row(
                    children: [
                      Text("To Date :  ", style: TextStyle(fontSize: 13)),
                      Text(toDate, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: onPlayTapped,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFDC0000),
                    child: Icon(playValue ? Icons.pause : Icons.play_arrow,
                        size: 30, color: Colors.white),
                  ),
                ),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFDC0000),
                  child: Text("1x", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                ),
                InkWell(onTap: () {}, child: CircleAvatar(radius: 20, backgroundColor: Color(0xFFDC0000), child: Icon(Icons.replay, size: 20, color: Colors.white))),
                InkWell(onTap: () {}, child: CircleAvatar(radius: 20, backgroundColor: Color(0xFFDC0000), child: Icon(Icons.forward, size: 20, color: Colors.white))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### 4.9 Navigating to History from your list

From any screen where you have a vehicle IMEI, navigate like this (GetX):

```dart
Get.toNamed(
  AppRoutes.history,
  parameters: {"imei": vehicleImei},
);
```

Example from a vehicle card:

```dart
onTapShowHistory: () {
  Get.toNamed(
    AppRoutes.history,
    parameters: {"imei": controller.vehicleDetails[index].imei ?? ""},
  );
},
```

---

## 5. Android / iOS setup for Google Maps

- **Android**: `android/app/src/main/AndroidManifest.xml` – add inside `<application>`:
  ```xml
  <meta-data
      android:name="com.google.android.geo.API_KEY"
      android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
  ```
- **iOS**: `ios/Runner/AppDelegate.swift` – add Google Maps API key and ensure `GoogleMaps` is registered.

---

## 6. Prompt to paste (for Cursor or another AI)

Copy the block below and paste it into Cursor (or another assistant) in the **target project** so it can apply the same steps and file changes there.

---

**START OF PROMPT (copy from here)**

I want to add a **vehicle travel history** feature to this Flutter project, matching the behavior of an existing reference app. The feature should:

1. **Screen**: A “History” screen that accepts an `imei` (vehicle identifier) and shows:
   - A Google Map with the vehicle’s travelled route as a **polyline** for a selected date range.
   - **From date** and **To date** pickers.
   - A **Show** button that fetches history for that range and draws the route (optionally smoothed via OSRM).
   - Optional: **Play** button to animate a marker along the route.

2. **Backend**: One API endpoint – vehicle history – called with query params `imei`, `from_date`, `to_date` (format `yyyy-MM-dd`) and header `Authorization: Bearer <token>`. Response JSON has `data.location_history` as a list of objects with `latitude`, `longitude` (and optionally `devicetime`, `speed`, etc.). Use the project’s existing base URL and add a path like `track_vehicle` (or whatever the backend uses).

3. **Dependencies**: Add to `pubspec.yaml`: `google_maps_flutter`, `geolocator`, `dio`, `get`, `shared_preferences`.

4. **Files to create/update** (use the structure and logic from the reference; adjust package name and paths to this project):
   - **Routes**: Add a named route for history (e.g. `/history`) and a GetPage that opens `HistoryScreen(imei: Get.parameters['imei'] ?? '')`.
   - **Model**: A `VehicleTrackingModel` that parses the API response and has `Data` with `locationHistory` as list of items with `latitude`, `longitude` (and any other fields the API returns).
   - **API**: Config for base URL and vehicle-history endpoint; one function that calls this endpoint with `imei`, `from_date`, `to_date`, and Bearer token (token can come from SharedPreferences key `token`).
   - **Controller**: `HistoryController` (GetX) that: gets token; loads a marker icon from assets; has `fromDateController`, `toDateController`; calls the API in an isolate; converts `location_history` to `List<LatLng>`; optionally filters invalid points and minimizes redundant points; optionally sends chunks to OSRM (`http://router.project-osrm.org/match/v1/driving/...`) for smoothing and builds polylines; exposes `polylines`, `markers`, `isLoading`; has `onTapSubmit()` to run the fetch and draw; has `selectFromDate` / `selectToDate`; optional playback that animates a marker along the path using `AnimationController` and bearing.
   - **Screen**: `HistoryScreen(imei)` with a map, date controls, Show button, and loading indicator; use GetBuilder with `HistoryController`, pass `imei` in `didChangeDependencies` via `imeiInitialAssign`.
   - **Utils**: Date formatting (`formatDate` for `yyyy-MM-dd`), `getBearing` for two `LatLng`s, SharedPrefs read for token, and a simple toast/snackbar for errors (e.g. “IMEI missing”, “Please select From/To Date”, “No data for selected range”).
   - **Isolate**: Top-level function that runs the Dio GET and returns status + data; separate top-level function to parse JSON into `VehicleTrackingModel`; optional top-level function to process OSRM chunk response into `List<LatLng>` for polyline.

5. **Navigation**: From the existing vehicle list/card, add a “Show History” (or similar) action that calls `Get.toNamed(AppRoutes.history, parameters: {'imei': vehicleImei})`.

6. **Assets**: One marker image for the map (e.g. `assets/images/marker2.png`); register the asset folder in `pubspec.yaml`.

7. **Maps**: Ensure Android/iOS are configured with a Google Maps API key so the map and polylines render.

Please implement the above in this project: create or update the listed files, use the existing package name and style (GetX, Dio, SharedPreferences), and keep the same steps as in the reference (fetch by date range → parse → build lat/lng list → optional OSRM smoothing → draw polylines → optional playback). If the project already has an API config or theme colors, reuse them instead of duplicating.

**END OF PROMPT**

---

You can save this file and use it in the other project: follow the steps manually, or paste the **Prompt to paste** section into Cursor there so it can apply the changes for you.
