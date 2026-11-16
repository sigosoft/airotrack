import 'package:flutter/foundation.dart';

import '../Configs/ApiConfigs.dart';
import '../Configs/DioClient.dart';
import '../Utils/ApiHelpers.dart';

/// Converts the GPS device's own km count into the vehicle's odometer.
///
/// The server keeps two counters per vehicle:
/// * `kilometer`: what the tracker has counted since it was fitted.
/// * `odometer`: the vehicle's real odometer. Users set it from Track
///   ("update odometer") to match the dashboard; Home and Track show it.
///
/// Statistics and the reports return the device count (`odometer_km`), so
/// they disagreed with Home and Track. The gap (odometer − kilometer) is fixed
/// per vehicle, and the live-track snapshot returns both, so adding it to the
/// device count gives the vehicle's odometer.
class OdometerOffsetService {
  OdometerOffsetService._();

  static final Map<String, num> _offsets = {};
  static final Map<String, Future<num>> _pending = {};

  /// Offset in km for [imei]; 0 when it can't be worked out.
  static Future<num> offsetFor(String imei) {
    final key = imei.trim();
    if (key.isEmpty) return Future.value(0);
    final known = _offsets[key];
    if (known != null) return Future.value(known);
    return _pending[key] ??= _fetch(key).whenComplete(() {
      _pending.remove(key);
    });
  }

  /// Call after the user changes a vehicle's odometer.
  static void forget(String imei) => _offsets.remove(imei.trim());

  static Future<num> _fetch(String imei) async {
    try {
      final response = await DioClient().get(
        ApiEndPoints.liveTrackSnapshot,
        query: {'imei': imei},
      );
      final root = asStringKeyedMap(response.data);
      final data = asStringKeyedMap(root?['data']);
      final position = asStringKeyedMap(data?['position']);
      final odometer = _num(position?['odometer']);
      final kilometer = _num(position?['kilometer']);
      if (odometer == null || kilometer == null) return 0;
      final offset = odometer - kilometer;
      _offsets[imei] = offset;
      return offset;
    } catch (e) {
      debugPrint('[Odometer] offset unavailable for $imei: $e');
      return 0;
    }
  }

  static num? _num(dynamic raw) {
    if (raw is num) return raw;
    return num.tryParse(raw?.toString() ?? '');
  }

  /// Adds [offset] to the odometer fields of a report/statistics row.
  static Map<String, dynamic> applyTo(
    Map<String, dynamic> row,
    num offset,
  ) {
    if (offset == 0) return row;
    final out = Map<String, dynamic>.from(row);
    for (final key in const [
      'odometer_km',
      'odometer',
      'start_odometer',
      'odometer_start',
      'start_odo',
      'start_odometer_km',
      'end_odometer',
      'odometer_end',
      'end_odo',
    ]) {
      final value = _num(out[key]);
      if (value != null) out[key] = value + offset;
    }
    return out;
  }
}
