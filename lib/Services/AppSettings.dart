import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VehicleIconSize { small, medium, large }

enum AppMapType { normal, satellite, terrain }

enum SpeedUnit { kmh, mph }

enum DistanceUnit { km, miles }

/// General Settings, saved on this phone and read across the app.
///
/// Values stay in km and km/h everywhere internally; only what is shown
/// changes. Use [speed], [distance] and [dateTime] to format for display.
class AppSettings extends GetxService {
  static AppSettings get to => Get.find<AppSettings>();

  /// Safe from code that may run before [init] (tests, background isolates).
  static AppSettings? get maybe =>
      Get.isRegistered<AppSettings>() ? Get.find<AppSettings>() : null;

  static const double _kmPerMile = 1.609344;

  final notifications = true.obs;
  final showHistoryOnLive = true.obs;
  final iconSize = VehicleIconSize.medium.obs;
  final use24HourTime = true.obs;
  final showSpeedometer = true.obs;
  final mapType = AppMapType.normal.obs;
  final speedUnit = SpeedUnit.kmh.obs;
  final distanceUnit = DistanceUnit.km.obs;

  late SharedPreferences _prefs;

  static Future<AppSettings> init() async {
    final s = AppSettings();
    s._prefs = await SharedPreferences.getInstance();
    s._load();
    // Explicit type: in an async function `return Get.put(s)` infers
    // FutureOr<AppSettings> and registers it under the wrong type.
    return Get.put<AppSettings>(s, permanent: true);
  }

  void _load() {
    notifications.value = _prefs.getBool('set_notifications') ?? true;
    showHistoryOnLive.value = _prefs.getBool('set_history_on_live') ?? true;
    use24HourTime.value = _prefs.getBool('set_24h') ?? true;
    showSpeedometer.value = _prefs.getBool('set_speedometer') ?? true;
    iconSize.value = _enum(
      VehicleIconSize.values,
      _prefs.getString('set_icon_size'),
      VehicleIconSize.medium,
    );
    mapType.value = _enum(
      AppMapType.values,
      _prefs.getString('set_map_type'),
      AppMapType.normal,
    );
    speedUnit.value = _enum(
      SpeedUnit.values,
      _prefs.getString('set_speed_unit'),
      SpeedUnit.kmh,
    );
    distanceUnit.value = _enum(
      DistanceUnit.values,
      _prefs.getString('set_distance_unit'),
      DistanceUnit.km,
    );
  }

  static T _enum<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  void setNotifications(bool v) {
    notifications.value = v;
    _prefs.setBool('set_notifications', v);
  }

  void setShowHistoryOnLive(bool v) {
    showHistoryOnLive.value = v;
    _prefs.setBool('set_history_on_live', v);
  }

  void setUse24HourTime(bool v) {
    use24HourTime.value = v;
    _prefs.setBool('set_24h', v);
  }

  void setShowSpeedometer(bool v) {
    showSpeedometer.value = v;
    _prefs.setBool('set_speedometer', v);
  }

  void setIconSize(VehicleIconSize v) {
    iconSize.value = v;
    _prefs.setString('set_icon_size', v.name);
  }

  void setMapType(AppMapType v) {
    mapType.value = v;
    _prefs.setString('set_map_type', v.name);
  }

  void setSpeedUnit(SpeedUnit v) {
    speedUnit.value = v;
    _prefs.setString('set_speed_unit', v.name);
  }

  void setDistanceUnit(DistanceUnit v) {
    distanceUnit.value = v;
    _prefs.setString('set_distance_unit', v.name);
  }

  // -------------------------------------------------------------------
  // Display helpers
  // -------------------------------------------------------------------

  /// Multiplier for vehicle icons on maps (medium = 1).
  double get iconScale {
    switch (iconSize.value) {
      case VehicleIconSize.small:
        return 0.75;
      case VehicleIconSize.large:
        return 1.3;
      case VehicleIconSize.medium:
        return 1.0;
    }
  }

  String get speedLabel => speedUnit.value == SpeedUnit.mph ? 'mph' : 'km/h';

  String get distanceLabel =>
      distanceUnit.value == DistanceUnit.miles ? 'mi' : 'km';

  /// km/h → the chosen unit.
  num convertSpeed(num kmh) =>
      speedUnit.value == SpeedUnit.mph ? kmh / _kmPerMile : kmh;

  /// km → the chosen unit.
  num convertDistance(num km) =>
      distanceUnit.value == DistanceUnit.miles ? km / _kmPerMile : km;

  /// "45.0 km/h" / "28.0 mph".
  String speed(num? kmh, {int decimals = 1, bool withUnit = true}) {
    if (kmh == null) return '—';
    final v = convertSpeed(kmh).toStringAsFixed(decimals);
    return withUnit ? '$v $speedLabel' : v;
  }

  /// "12.34 km" / "7.67 mi".
  String distance(num? km, {int decimals = 2, bool withUnit = true}) {
    if (km == null) return '—';
    final v = convertDistance(km).toStringAsFixed(decimals);
    return withUnit ? '$v $distanceLabel' : v;
  }

  /// Re-formats an API date-time ("2026-11-16 14:32:37") in 12 or 24 hour
  /// time. Text it can't read is returned unchanged.
  String dateTime(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return text;
    final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    if (parsed == null) return text;
    final pattern =
        use24HourTime.value ? 'yyyy-MM-dd HH:mm:ss' : 'yyyy-MM-dd hh:mm:ss a';
    return DateFormat(pattern).format(parsed);
  }
}
