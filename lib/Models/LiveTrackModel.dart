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
      currentStatus: json['current_status']?.toString(),
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
      imei: json['imei']?.toString(),
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
      imei: json['imei']?.toString(),
      deviceTime: json['devicetime']?.toString(),
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      mode: json['mode']?.toString(),
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
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      speed: json['speed'] as num?,
      deviceTime: json['devicetime']?.toString(),
      ignition: json['ignition'] as int?,
      power: json['power'] as int?,
      altitude: json['altitude']?.toString(),
      gsmSignalStrength: json['gsm_signal_strength']?.toString(),
      mode: json['mode'] as String?,
      network: json['network'] as String?,
      lastUpdate: json['last_update']?.toString(),
    );
  }
}

/// Response for GET /live_track_snapshot?imei=...
class LiveTrackSnapshotModel {
  final bool? status;
  final String? message;
  final LiveTrackSnapshotData? data;

  const LiveTrackSnapshotModel({this.status, this.message, this.data});

  factory LiveTrackSnapshotModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LiveTrackSnapshotModel();
    final payload = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    return LiveTrackSnapshotModel(
      status: json['status'] is bool ? json['status'] as bool : null,
      message: json['message'] as String?,
      data: LiveTrackSnapshotData.fromJson(payload),
    );
  }
}

class LiveTrackSnapshotData {
  final LiveCurrentPosition? position;
  final LiveWebsocketInfo? websocket;
  final LiveWebsocketConfig? websocketConfig;
  final LiveTrackData? trackData;
  final String? status;
  final bool? isLive;

  const LiveTrackSnapshotData({
    this.position,
    this.websocket,
    this.websocketConfig,
    this.trackData,
    this.status,
    this.isLive,
  });

  /// Maps live_track_snapshot payload to LiveTrackData field names.
  static Map<String, dynamic> _normalizeSnapshotPayload(
    Map<String, dynamic> json,
  ) {
    final normalized = <String, dynamic>{};

    final vehicle = json['vehicle'] ?? json['vehicle_info'];
    if (vehicle is Map) {
      normalized['vehicle_info'] = Map<String, dynamic>.from(vehicle);
    }

    final position = json['position'] ?? json['current_position'];
    if (position is Map) {
      final pos = Map<String, dynamic>.from(position);
      normalized['current_position'] = pos;
      normalized['current_position_api'] = {
        'success': true,
        'data': pos,
      };
    }

    if (json['today_statistics'] is Map<String, dynamic>) {
      normalized['today_statistics'] = json['today_statistics'];
    }

    final status = json['current_status'] ?? json['status'];
    if (status != null) {
      normalized['current_status'] = status.toString();
    }

    return normalized;
  }

  factory LiveTrackSnapshotData.fromJson(Map<String, dynamic> json) {
    final positionRaw = json['position'] ?? json['current_position'];
    final positionJson =
        positionRaw is Map ? Map<String, dynamic>.from(positionRaw) : null;
    final normalized = _normalizeSnapshotPayload(json);
    final trackData = normalized.isNotEmpty
        ? LiveTrackData.fromJson(normalized)
        : null;

    return LiveTrackSnapshotData(
      position: positionJson != null
          ? LiveCurrentPosition.fromJson(positionJson)
          : null,
      websocket: json['websocket'] is Map
          ? LiveWebsocketInfo.fromJson(
              Map<String, dynamic>.from(json['websocket'] as Map),
            )
          : null,
      websocketConfig: json['websocket_config'] is Map
          ? LiveWebsocketConfig.fromJson(
              Map<String, dynamic>.from(json['websocket_config'] as Map),
            )
          : null,
      trackData: trackData,
      status: json['status']?.toString(),
      isLive: json['is_live'] is bool
          ? json['is_live'] as bool
          : json['is_live'] == 1 || json['is_live']?.toString() == 'true',
    );
  }

  LiveTrackData toLiveTrackData() {
    if (trackData != null) {
      return LiveTrackData(
        vehicleInfo: trackData!.vehicleInfo,
        currentPosition: trackData!.currentPosition ?? position,
        currentStatus:
            trackData!.currentStatus ??
            status ??
            trackData!.currentPosition?.derivedStatus ??
            position?.derivedStatus,
        todayStatistics: trackData!.todayStatistics,
        currentPositionApi: trackData!.currentPositionApi,
      );
    }
    return LiveTrackData(
      currentPosition: position,
      currentStatus: status ?? position?.derivedStatus,
    );
  }

  /// Option A: channel from `websocket.channel`, else `websocket_config.channel_prefix.<imei>`.
  String? channelFor(String imei) {
    final fromWebsocket = websocket?.channel?.trim();
    if (fromWebsocket != null && fromWebsocket.isNotEmpty) {
      return fromWebsocket;
    }
    final prefix = websocketConfig?.channelPrefix?.trim();
    if (prefix != null && prefix.isNotEmpty) {
      return '$prefix.${imei.trim()}';
    }
    return null;
  }

  /// Option A: event from `websocket.event`, else `websocket_config.event_name`.
  String? eventNameFor() {
    final fromWebsocket = websocket?.event?.trim();
    if (fromWebsocket != null && fromWebsocket.isNotEmpty) {
      return fromWebsocket;
    }
    return websocketConfig?.eventName?.trim();
  }

  bool get hasWebSocketConnectionConfig {
    final url = websocketConfig?.websocketUrl?.trim();
    final key = websocketConfig?.appKey?.trim();
    return url != null &&
        url.isNotEmpty &&
        key != null &&
        key.isNotEmpty;
  }
}

class LiveWebsocketInfo {
  final String? channel;
  final String? event;

  const LiveWebsocketInfo({this.channel, this.event});

  factory LiveWebsocketInfo.fromJson(Map<String, dynamic> json) {
    return LiveWebsocketInfo(
      channel: json['channel'] as String?,
      event: json['event'] as String?,
    );
  }
}

class LiveWebsocketConfig {
  final String? websocketUrl;
  final String? appKey;
  final String? channelPrefix;
  final String? eventName;

  const LiveWebsocketConfig({
    this.websocketUrl,
    this.appKey,
    this.channelPrefix,
    this.eventName,
  });

  factory LiveWebsocketConfig.fromJson(Map<String, dynamic> json) {
    return LiveWebsocketConfig(
      websocketUrl: json['websocket_url'] as String?,
      appKey: json['app_key'] as String?,
      channelPrefix: json['channel_prefix'] as String?,
      eventName: json['event_name'] as String?,
    );
  }
}
