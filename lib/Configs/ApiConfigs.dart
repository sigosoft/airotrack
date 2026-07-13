class ApiConfig {
  // This is the Test Server URL
  static String baseUrl =
      //"https://api.airotrack.in/website/";
      //"https://dev-api.airotrack.in/airotrack-api/public/website/";
      "https://api-dev.airotrack.in/website/";

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
  static String home = "home";
  static String alerts = "alerts";
  static String vehicleHistory = "track_vehicle";
  static String liveTrack = "live_track";
}
