import 'package:geolocator/geolocator.dart';
import '../config/app_config.dart';

class UserLocation {
  final double lat;
  final double lng;
  final bool isFallback;
  const UserLocation(this.lat, this.lng, this.isFallback);
}

class LocationService {
  UserLocation _fallback() =>
      const UserLocation(AppConfig.fallbackLat, AppConfig.fallbackLng, true);

  Future<UserLocation> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _fallback();

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return _fallback();
      }

      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
        return UserLocation(p.latitude, p.longitude, false);
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return UserLocation(last.latitude, last.longitude, false);
        }
        return _fallback();
      }
    } catch (_) {
      return _fallback();
    }
  }
}