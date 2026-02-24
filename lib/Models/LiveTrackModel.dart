/// Response model for live_track API.
///
/// Actual API shape (GET /live_track?imei=...):
/// {
///   "status": true,
///   "message": "Success",
///   "data": {
///     "vehicle_info": { "id", "vehicle_number", "imei", "company_id", "total_kilometers_traveled" },
///     "current_position": { "id", "imei", "devicetime", "latitude", "longitude",
///                           "mode", "speed", "ignition", "power", "alert_id", "kilometer" },
///     "current_status": "Running",
///     "today_statistics": { "total_kilometers_today", "total_stop_hours", "total_idle_hours" },
///     "current_position_api": {
///       "success": true,
///       "data": { "imei", "deviceid", "latitude", "longitude", "speed", "devicetime",
///                 "ignition", "power", "altitude", "gsm_signal_strength", "mode",
///                 "network", "alert_id", "last_update" }
///     }
///   }
/// }
class LiveTrackModel {
  final bool? status;
  final String? message;
  final LiveTrackData? data;

  const LiveTrackModel({this.status, this.message, this.data});

  factory LiveTrackModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LiveTrackModel();
    return LiveTrackModel(
      status: json['status'] as bool?,
      message: json['message'] as String?,
      data: json['data'] != null
          ? LiveTrackData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class LiveTrackData {
  final LiveVehicleInfo? vehicleInfo;
  final LiveCurrentPosition? currentPosition;
  final String? currentStatus;
  final LiveTodayStatistics? todayStatistics;
  final LiveCurrentPositionApi? currentPositionApi;

  const LiveTrackData({
    this.vehicleInfo,
    this.currentPosition,
    this.currentStatus,
    this.todayStatistics,
    this.currentPositionApi,
  });

  factory LiveTrackData.fromJson(Map<String, dynamic> json) {
    return LiveTrackData(
      vehicleInfo: json['vehicle_info'] != null
          ? LiveVehicleInfo.fromJson(
              json['vehicle_info'] as Map<String, dynamic>,
            )
          : null,
      currentPosition: json['current_position'] != null
          ? LiveCurrentPosition.fromJson(
              json['current_position'] as Map<String, dynamic>,
            )
          : null,
      currentStatus: json['current_status'] as String?,
      todayStatistics: json['today_statistics'] != null
          ? LiveTodayStatistics.fromJson(
              json['today_statistics'] as Map<String, dynamic>,
            )
          : null,
      currentPositionApi: json['current_position_api'] != null
          ? LiveCurrentPositionApi.fromJson(
              json['current_position_api'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// Basic vehicle identity info returned by the API.
class LiveVehicleInfo {
  final int? id;
  final String? vehicleNumber;
  final String? imei;
  final int? companyId;
  final String? totalKilometersTraveled;

  const LiveVehicleInfo({
    this.id,
    this.vehicleNumber,
    this.imei,
    this.companyId,
    this.totalKilometersTraveled,
  });

  factory LiveVehicleInfo.fromJson(Map<String, dynamic> json) {
    return LiveVehicleInfo(
      id: json['id'] as int?,
      vehicleNumber: json['vehicle_number'] as String?,
      imei: json['imei'] as String?,
      companyId: json['company_id'] as int?,
      totalKilometersTraveled: json['total_kilometers_traveled']?.toString(),
    );
  }
}

/// The latest GPS position for the vehicle.
class LiveCurrentPosition {
  final int? id;
  final String? imei;
  final String? deviceTime;
  final String? latitude;
  final String? longitude;
  final String? mode;
  final num? speed;
  final int? ignition;
  final int? power;
  final String? kilometer;

  const LiveCurrentPosition({
    this.id,
    this.imei,
    this.deviceTime,
    this.latitude,
    this.longitude,
    this.mode,
    this.speed,
    this.ignition,
    this.power,
    this.kilometer,
  });

  factory LiveCurrentPosition.fromJson(Map<String, dynamic> json) {
    return LiveCurrentPosition(
      id: json['id'] as int?,
      imei: json['imei'] as String?,
      deviceTime: json['devicetime'] as String?,
      latitude: json['latitude'] as String?,
      longitude: json['longitude'] as String?,
      mode: json['mode'] as String?,
      speed: json['speed'] as num?,
      ignition: json['ignition'] as int?,
      power: json['power'] as int?,
      kilometer: json['kilometer']?.toString(),
    );
  }

  bool get isIgnitionOn => ignition == 1;
  bool get isPowerOn => power == 1;

  /// Derived vehicle status from mode / ignition / speed.
  /// Mode codes per official API guide:
  ///   M = Moving, S = Stopped, H = Idle (TCP server)
  ///   R/RUNNING, I/IDLE, INACTIVE (legacy)
  String get derivedStatus {
    final m = mode?.toUpperCase();
    final spd = speed?.toDouble() ?? 0;
    if (m == 'M' || m == 'R' || m == 'RUNNING' || spd > 0) return 'Running';
    if (m == 'H' || m == 'I' || m == 'IDLE' || (ignition == 1 && spd == 0))
      return 'Idle';
    if (m == 'S' || m == 'STOPPED') return 'Stopped';
    if (m == 'INACTIVE') return 'Inactive';
    return 'Stopped';
  }
}

/// Today's overall statistics for the vehicle.
class LiveTodayStatistics {
  final num? totalKilometersToday;
  final num? totalStopHours;
  final num? totalIdleHours;

  const LiveTodayStatistics({
    this.totalKilometersToday,
    this.totalStopHours,
    this.totalIdleHours,
  });

  factory LiveTodayStatistics.fromJson(Map<String, dynamic> json) {
    return LiveTodayStatistics(
      totalKilometersToday: json['total_kilometers_today'] as num?,
      totalStopHours: json['total_stop_hours'] as num?,
      totalIdleHours: json['total_idle_hours'] as num?,
    );
  }
}

/// The current_position_api nested object.
class LiveCurrentPositionApi {
  final bool? success;
  final LiveCurrentPositionApiData? data;

  const LiveCurrentPositionApi({this.success, this.data});

  factory LiveCurrentPositionApi.fromJson(Map<String, dynamic> json) {
    return LiveCurrentPositionApi(
      success: json['success'] as bool?,
      data: json['data'] != null
          ? LiveCurrentPositionApiData.fromJson(
              json['data'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class LiveCurrentPositionApiData {
  final String? imei;
  final int? deviceId;
  final String? latitude;
  final String? longitude;
  final num? speed;
  final String? deviceTime;
  final int? ignition;
  final int? power;
  final String? altitude;
  final String? gsmSignalStrength;
  final String? mode;
  final String? network;
  final String? lastUpdate;

  const LiveCurrentPositionApiData({
    this.imei,
    this.deviceId,
    this.latitude,
    this.longitude,
    this.speed,
    this.deviceTime,
    this.ignition,
    this.power,
    this.altitude,
    this.gsmSignalStrength,
    this.mode,
    this.network,
    this.lastUpdate,
  });

  factory LiveCurrentPositionApiData.fromJson(Map<String, dynamic> json) {
    return LiveCurrentPositionApiData(
      imei: json['imei'] as String?,
      deviceId: json['deviceid'] as int?,
      latitude: json['latitude'] as String?,
      longitude: json['longitude'] as String?,
      speed: json['speed'] as num?,
      deviceTime: json['devicetime'] as String?,
      ignition: json['ignition'] as int?,
      power: json['power'] as int?,
      altitude: json['altitude']?.toString(),
      gsmSignalStrength: json['gsm_signal_strength']?.toString(),
      mode: json['mode'] as String?,
      network: json['network'] as String?,
      lastUpdate: json['last_update'] as String?,
    );
  }
}
