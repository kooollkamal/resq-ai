class AppConfig {
  static const bool showAlgorithmLab = true;
  static const bool showEmergencyInfo = true;

  static const int maxResults = 8;
  static const double searchRadiusMeters = 8000;

  // Used when GPS is unavailable (centre of Hyderabad).
  static const double fallbackLat = 17.385;
  static const double fallbackLng = 78.4867;

  static const String appPackage = 'com.resqai.resq_ai';
  static const String userAgent = 'ResQAI/1.0 (com.resqai.resq_ai)';
  static const String tileUrl = 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
  static const String overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const String overpassFallbackUrl =
      'https://overpass.kumi.systems/api/interpreter';
  static const String osrmBaseUrl = 'https://router.project-osrm.org';

  static List<String> placeTypesFor(String emergencyType) {
    switch (emergencyType) {
      case 'Fire':
        return ['fire_station'];
      default:
        return ['hospital'];
    }
  }

  static String facilityLabel(String emergencyType) =>
      emergencyType == 'Fire' ? 'fire stations' : 'hospitals';
}