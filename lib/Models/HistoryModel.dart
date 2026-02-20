/// Response model for vehicle history API.
class HistoryModel {
  final bool? status;
  final HistoryData? data;

  const HistoryModel({
    this.status,
    this.data,
  });

  factory HistoryModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HistoryModel();
    return HistoryModel(
      status: json['status'] as bool?,
      data: json['data'] != null
          ? HistoryData.fromJson(json['data'] as Map<String, dynamic>?)
          : null,
    );
  }
}

class HistoryData {
  final VehicleInfo? vehicleInfo;
  final List<LocationHistoryItem>? locationHistory;

  const HistoryData({
    this.vehicleInfo,
    this.locationHistory,
  });

  factory HistoryData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HistoryData();
    final rawList = json['location_history'];
    return HistoryData(
      vehicleInfo: json['vehicle_info'] != null
          ? VehicleInfo.fromJson(
              json['vehicle_info'] as Map<String, dynamic>?,
            )
          : null,
      locationHistory: rawList is List
          ? (rawList)
              .map(
                (e) => LocationHistoryItem.fromJson(
                  e is Map<String, dynamic> ? e : null,
                ),
              )
              .toList()
          : null,
    );
  }
}

class VehicleInfo {
  final int? id;
  final String? vehicleNumber;
  final String? imei;
  final int? ignition;
  final int? power;
  final int? gnssFix;
  final String? lastUpdate;
  final String? latitude;
  final String? longitude;
  final String? mode;
  final num? speed;
  final String? expirationTime;

  const VehicleInfo({
    this.id,
    this.vehicleNumber,
    this.imei,
    this.ignition,
    this.power,
    this.gnssFix,
    this.lastUpdate,
    this.latitude,
    this.longitude,
    this.mode,
    this.speed,
    this.expirationTime,
  });

  factory VehicleInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VehicleInfo();
    return VehicleInfo(
      id: json['id'] as int?,
      vehicleNumber: json['vehicle_number'] as String?,
      imei: json['imei'] as String?,
      ignition: json['ignition'] as int?,
      power: json['power'] as int?,
      gnssFix: json['gnss_fix'] as int?,
      lastUpdate: json['last_update'] as String?,
      latitude: json['latitude'] as String?,
      longitude: json['longitude'] as String?,
      mode: json['mode'] as String?,
      speed: json['speed'] as num?,
      expirationTime: json['expirationtime'] as String?,
    );
  }
}

class LocationHistoryItem {
  final String? imei;
  final String? deviceTime;
  final String? latitude;
  final String? longitude;
  final String? speed;
  final String? mode;
  final String? ignition;
  final String? power;
  final String? alertId;
  final String? createdAt;
  final bool? isStopped;

  const LocationHistoryItem({
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

  factory LocationHistoryItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LocationHistoryItem();
    return LocationHistoryItem(
      imei: json['imei'] as String?,
      deviceTime: json['devicetime'] as String?,
      latitude: json['latitude'] as String?,
      longitude: json['longitude'] as String?,
      speed: json['speed']?.toString(),
      mode: json['mode'] as String?,
      ignition: json['ignition']?.toString(),
      power: json['power']?.toString(),
      alertId: json['alert_id'] as String?,
      createdAt: json['created_at'] as String?,
      isStopped: json['is_stopped'] as bool?,
    );
  }
}
