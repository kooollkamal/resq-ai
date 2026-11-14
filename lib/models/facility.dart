class RouteInfo {
  final int durationSeconds;
  final int distanceMeters;
  final String encodedPolyline;

  const RouteInfo({
    required this.durationSeconds,
    required this.distanceMeters,
    required this.encodedPolyline,
  });

  double get minutes => durationSeconds / 60.0;
  double get km => distanceMeters / 1000.0;
}

class Facility {
  final String id;
  final String name;
  final bool isNamed;
  final String address;
  final double lat;
  final double lng;
  final String? phone;
  final String? openingHours;
  final bool? hasEmergency;

  RouteInfo? route;
  double score = double.infinity;

  Facility({
    required this.id,
    required this.name,
    required this.isNamed,
    required this.address,
    required this.lat,
    required this.lng,
    this.phone,
    this.openingHours,
    this.hasEmergency,
  });

  static Facility? fromOverpass(Map<String, dynamic> j, String fallbackName) {
    final tags = (j['tags'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final center = j['center'] as Map?;
    final lat = (j['lat'] ?? center?['lat']) as num?;
    final lng = (j['lon'] ?? center?['lon']) as num?;
    if (lat == null || lng == null) return null;

    final name = (tags['name'] ?? tags['name:en']) as String?;
    final address = [
      tags['addr:housenumber'],
      tags['addr:street'],
      tags['addr:suburb'],
      tags['addr:city'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final emergency = tags['emergency'];

    return Facility(
      id: '${j['type']}/${j['id']}',
      name: name ?? fallbackName,
      isNamed: name != null,
      address: address,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      phone: (tags['phone'] ?? tags['contact:phone']) as String?,
      openingHours: tags['opening_hours'] as String?,
      hasEmergency:
          emergency == 'yes' ? true : (emergency == 'no' ? false : null),
    );
  }
}