import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:intl/intl.dart';

/// Generic report row used across ignition / stoppage / trip / etc. lists.
class ReportItem {
  final String vehicleNumber;
  final String startTime;
  final String endTime;
  final String duration;
  final String distance;
  final String location;
  final String startLocation;
  final String endLocation;
  final String speed;
  final String status;
  final String engineHours;
  final String running;
  final String stopped;
  final String idle;
  final String averageSpeed;
  final String maxSpeed;
  final String startOdometer;
  final String endOdometer;
  final bool ignitionOn;
  final bool isGeofenceEnter;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> raw;

  const ReportItem({
    this.vehicleNumber = '',
    this.startTime = '',
    this.endTime = '',
    this.duration = '',
    this.distance = '',
    this.location = '',
    this.startLocation = '',
    this.endLocation = '',
    this.speed = '',
    this.status = '',
    this.engineHours = '',
    this.running = '',
    this.stopped = '',
    this.idle = '',
    this.averageSpeed = '',
    this.maxSpeed = '',
    this.startOdometer = '',
    this.endOdometer = '',
    this.ignitionOn = false,
    this.isGeofenceEnter = true,
    this.latitude,
    this.longitude,
    this.raw = const {},
  });

  factory ReportItem.fromJson(
    dynamic raw, {
    String? fallbackVehicleNumber,
  }) {
    final map = asStringKeyedMap(raw) ?? {};

    final ignitionOn = _parseIgnitionOn(map);
    final isEnter = _parseGeofenceEnter(map);

    final lat = double.tryParse(
      pickString(map, [
        'start_latitude',
        'latitude',
        'lat',
        'start_lat',
      ]),
    );
    final lng = double.tryParse(
      pickString(map, [
        'start_longitude',
        'longitude',
        'lng',
        'lon',
        'start_lng',
      ]),
    );

    var vehicleNumber = pickString(map, [
      'vehicle_number',
      'plate_number',
      'name',
      'device_name',
    ]);
    // Nested vehicle object on the row itself.
    if (vehicleNumber.isEmpty) {
      final nested = asStringKeyedMap(map['vehicle']);
      vehicleNumber = pickString(nested, ['vehicle_number', 'name']);
    }
    if (vehicleNumber.isEmpty &&
        fallbackVehicleNumber != null &&
        fallbackVehicleNumber.trim().isNotEmpty) {
      vehicleNumber = fallbackVehicleNumber.trim();
    }

    final rawTime = pickString(map, [
      'datetime',
      'date_time',
      'start_time',
      'from_time',
      'start',
      'time',
      'created_at',
    ]);
    final rawEndTime = pickString(map, [
      'end_time',
      'to_time',
      'end',
      'stop_time',
      'departure_time',
    ]);

    final location = pickString(map, [
      'location',
      'address',
      'place',
      'start_address',
      'start_location',
    ]);

    var duration = formatDurationHm(pickString(map, [
      'duration',
      'total_duration',
      'time_duration',
      'stop_duration',
      'stopped_duration',
    ]));
    if (duration.isEmpty) {
      duration = formatDurationHm(pickString(map, ['duration_seconds']));
    }
    if (duration.isEmpty) {
      duration = formatDurationHm(_durationBetween(rawTime, rawEndTime));
    }

    return ReportItem(
      vehicleNumber: vehicleNumber,
      startTime: _formatDateTime(rawTime),
      endTime: _formatDateTime(rawEndTime),
      duration: duration,
      distance: _formatDistanceKm(map),
      location: location,
      startLocation: pickString(map, [
        'start_address',
        'start_location',
        'from_location',
        'from_address',
        'location',
      ]),
      endLocation: pickString(map, [
        'end_address',
        'end_location',
        'to_location',
        'to_address',
        'stop_location',
      ]),
      speed: _formatSpeed(pickString(map, [
        'speed',
        'overspeed_speed',
        'current_speed',
        'max_speed',
        'top_speed',
        'overspeed',
      ])),
      status: pickString(map, ['event', 'alert', 'status', 'alert_type', 'type']),
      engineHours: _formatDurationWithH(pickString(map, [
        'engine_hours',
        'engine_hour',
        'engineHours',
      ])),
      running: _formatDurationWithH(pickString(map, [
        'running',
        'running_duration',
        'move_duration',
      ])),
      stopped: _formatDurationWithH(pickString(map, [
        'stopped',
        'stop_duration',
        'stopped_duration',
      ])),
      idle: _formatDurationWithH(pickString(map, ['idle', 'idle_duration'])),
      averageSpeed: _formatSpeed(pickString(map, [
        'average_speed',
        'avg_speed',
        'averageSpeed',
      ])),
      maxSpeed: _formatSpeed(pickString(map, [
        'top_speed',
        'max_speed',
        'maximum_speed',
      ])),
      startOdometer: _resolveStartOdometer(map),
      endOdometer: _formatOdometer(pickString(map, [
        'end_odometer',
        'odometer_end',
        'end_odo',
        'odometer_km',
        'odometer',
      ])),
      ignitionOn: ignitionOn,
      isGeofenceEnter: isEnter,
      latitude: lat,
      longitude: lng,
      raw: map,
    );
  }

  /// API often sends only `odometer_km` (end). Derive start as end − route length.
  static String _resolveStartOdometer(Map<String, dynamic> map) {
    final explicit = _formatOdometer(pickString(map, [
      'start_odometer',
      'odometer_start',
      'start_odo',
      'start_odometer_km',
    ]));
    if (explicit.isNotEmpty) return explicit;

    final endRaw = pickString(map, [
      'end_odometer',
      'odometer_end',
      'end_odo',
      'odometer_km',
      'odometer',
    ]);
    final routeRaw = pickString(map, [
      'route_length_km',
      'distance_km',
      'distance',
    ]);
    final end = num.tryParse(endRaw);
    final route = num.tryParse(routeRaw);
    if (end == null || route == null) return '';
    final start = end - route;
    if (start < 0) return '';
    return _formatOdometer(start.toString());
  }

  /// Handles API values like `geofenceEntry` / `geofenceExit` / `Geofence Enter`.
  static bool _parseGeofenceEnter(Map<String, dynamic> map) {
    final alert = pickString(map, [
      'alert',
      'alert_type',
      'alert_types',
      'event',
      'geofence_status',
      'event_type',
      'type',
      'action',
      'status',
    ]).toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
    if (alert.contains('exit') || alert.contains('leave')) return false;
    if (alert.contains('enter') || alert.contains('entry')) return true;
    return true;
  }

  /// Handles API values like `ignitionOn` / `ignitionOff` / `Ignition On`.
  static bool _parseIgnitionOn(Map<String, dynamic> map) {
    final alert = pickString(map, ['alert'])
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');
    if (alert == 'ignitionon') return true;
    if (alert == 'ignitionoff') return false;

    final event = pickString(map, ['event', 'status', 'type']).toLowerCase();
    if (event.contains('off')) return false;
    if (event.contains('on')) return true;

    final ignitionRaw = map['ignition'] ?? map['ignition_status'];
    return ignitionRaw == 1 ||
        ignitionRaw == true ||
        ignitionRaw?.toString() == '1';
  }

  static String _formatDateTime(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    DateTime? parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    parsed ??= DateTime.tryParse(text);
    if (parsed == null) return text;
    return DateFormat('MMM dd, yyyy hh:mm:ss a').format(parsed);
  }

  /// Formats duration as `02h 40m` from seconds, `HH:MM:SS`, or similar.
  static String formatDurationHm(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';

    // Already in desired style.
    final already = RegExp(r'^\d{1,2}h\s+\d{1,2}m$', caseSensitive: false);
    if (already.hasMatch(text)) {
      final parts = text.toLowerCase().split(RegExp(r'\s+'));
      final h = int.tryParse(parts[0].replaceAll('h', '')) ?? 0;
      final m = int.tryParse(parts[1].replaceAll('m', '')) ?? 0;
      return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
    }

    // HH:MM:SS or HH:MM
    final colonParts = text.split(':');
    if (colonParts.length >= 2) {
      final h = int.tryParse(colonParts[0]) ?? 0;
      final m = int.tryParse(colonParts[1]) ?? 0;
      return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
    }

    // Pure seconds / minutes number.
    final asNum = num.tryParse(text);
    if (asNum != null) {
      // Values >= 100 treated as seconds; smaller may be minutes.
      final totalSeconds = asNum >= 100 ? asNum.round() : (asNum * 60).round();
      final h = totalSeconds ~/ 3600;
      final m = (totalSeconds % 3600) ~/ 60;
      return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
    }

    // "2 hr 40 min" / "2h 40m" / "2 hours 40 minutes"
    final hrMatch = RegExp(
      r'(\d+)\s*(?:h|hr|hrs|hour|hours)',
      caseSensitive: false,
    ).firstMatch(text);
    final minMatch = RegExp(
      r'(\d+)\s*(?:m|min|mins|minute|minutes)',
      caseSensitive: false,
    ).firstMatch(text);
    if (hrMatch != null || minMatch != null) {
      final h = int.tryParse(hrMatch?.group(1) ?? '0') ?? 0;
      final m = int.tryParse(minMatch?.group(1) ?? '0') ?? 0;
      return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
    }

    return text;
  }

  static String _formatDistanceKm(Map<String, dynamic> map) {
    final raw = pickString(map, [
      'route_length_km',
      'distance_km',
      'distance',
      'km',
      'total_km',
      'route_length',
    ]);
    if (raw.isEmpty) return '';
    if (raw.toLowerCase().contains('km')) return raw;
    final n = num.tryParse(raw);
    if (n == null) return '$raw Km';
    final text = (n == n.roundToDouble())
        ? '${n.toInt()}.0'
        : n.toStringAsFixed(2);
    return '$text Km';
  }

  /// Design style for daily stats: `11:13:40h`
  static String _formatDurationWithH(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '—';
    if (text.toLowerCase().endsWith('h')) return text;
    if (text.contains(':')) return '${text}h';
    return text;
  }

  static String _formatSpeed(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '—';
    if (text.toLowerCase().contains('km')) return text;
    final n = num.tryParse(text);
    if (n == null) return '$text kmph';
    final value = (n == n.roundToDouble())
        ? n.toInt().toString()
        : n.toStringAsFixed(2);
    return '$value kmph';
  }

  static String _formatOdometer(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    final n = num.tryParse(text);
    if (n == null) return text;
    // Prefer whole km for odometer pill display.
    return n.round().toString().padLeft(9, '0');
  }

  static String _durationBetween(String startRaw, String endRaw) {
    DateTime? parse(String raw) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text.replaceFirst(' ', 'T')) ??
          DateTime.tryParse(text);
    }

    final start = parse(startRaw);
    final end = parse(endRaw);
    if (start == null || end == null) return '';
    final seconds = end.difference(start).inSeconds;
    if (seconds < 0) return '';
    return seconds.toString();
  }
}
