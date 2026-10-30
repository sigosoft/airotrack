class ApiConfig {
  // This is the Test Server URL
  static String baseUrl =
      "https://api-dev.airotrack.in/website/";
      //"https://api.airotrack.in/website/";
      //"https://dev-api.airotrack.in/airotrack-api/public/website/";

  // Push notification server. Only push notification traffic uses this domain;
  // every other API keeps using [baseUrl].
  static const String pushBaseUrl = "https://device.airotrack.in/";

  // TCP server base URL — used for real-time device position (live tracking)
  static const String tcpBaseUrl =
      "https://dev-api.airotrack.in/airotrack-tcp/public";

  // This is the base Image URL
  static String imageUrl =
      "https://ourworks.co.in/saimpex-backend/public/storage/";

  /// Mapbox public token for Map Matching API (snap GPS track to road).
  static const String mapboxAccessToken =
      'pk.eyJ1Ijoic2FpbXBleGRldmxvcG1lbnQiLCJhIjoiY21rZXg1ZDA4MGFjZDNqcXptZmN6eXJwYyJ9.MhqmUUhQgPHXj-0nwnz9ww';
}

class ApiEndPoints {
  static String login = "login";
  static String logout = "logout";
  static String home = "home";
  static String alerts = "alerts";
  /// Sends this device's FCM token to the website API (base URL).
  static String updateFcmToken = "update_fcm_token";
  /// Push notifications are read from the push server ([ApiConfig.pushBaseUrl]).
  static String get pushNotificationsUrl => "${ApiConfig.pushBaseUrl}notifications";
  static String vehicleHistory = "track_vehicle";
  static String liveTrack = "live_track";
  static String liveTrackSnapshot = "live_track_snapshot";
  static String updateOdometer = "update_odometer";
  static String addGeofence = "add_geofence";
  static String updateGeofence = "update_geofence";
  static String deleteGeofence = "delete_geofence";
  static String geofences = "geofences";
  static String geofenceSyncedVehicles = "geofence_synced_vehicles";
  static String geofenceUnsyncedVehicles = "geofence_unsynced_vehicles";
  /// Sync selected vehicles onto a geofence: geofence_id + vehicle_ids[]
  static String syncGeofenceVehicles = "sync_geofence_vehicles";
  /// Sync selected geofences onto a vehicle: vehicle_id + geofence_ids[]
  static String syncVehicleGeofences = "sync_vehicle_geofences";
  static String vehicleSyncedGeofences = "vehicle_synced_geofences";
  static String vehicleUnsyncedGeofences = "vehicle_unsynced_geofences";
  /// Linked geofences for a vehicle (full geometry for map display).
  static String vehicleGeofences = "vehicle_geofences";

  // Profile / account
  static String profile = "profile";
  static String updateProfile = "update_profile";
  static String changePassword = "change_password";
  static String deleteAccount = "delete_account";

  // Dashboard / statistics
  static String dashboard = "dashboard";
  static String statistics = "statistics";

  // Reports
  static String reportsIgnition = "reports/ignition";
  /// Backend path spelling as provided by API.
  static String reportsStoppage = "reports/stoppage";
  static String reportsTrip = "reports/trip";
  static String reportsDaily = "reports/daily";
  static String reportsSummary = "reports/summary";
  static String reportsOverspeed = "reports/overspeed";
  static String reportsGeofence = "reports/geofence";
  static String reportsAlerts = "reports/alerts";
}
