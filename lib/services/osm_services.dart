import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../models/facility.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  factory ApiException.fromResponse(String api, int status, String body) {
    String detail = body;
    try {
      final j = jsonDecode(body);
      detail = (j['error']?['message'] as String?) ?? body;
    } catch (_) {}
    if (detail.length > 160) detail = detail.substring(0, 160);
    return ApiException('$api error $status: $detail');
  }

  @override
  String toString() => message;
}

double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180.0;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  int index = 0, lat = 0, lng = 0;

  while (index < encoded.length) {
    int shift = 0, result = 0, b = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}

class PlacesService {
  Future<List<Facility>> nearby({
    required double lat,
    required double lng,
    required List<String> types,
  }) async {
    final radius = AppConfig.searchRadiusMeters.round();
    final filters = types
        .map((t) => '  nwr["amenity"="$t"](around:$radius,$lat,$lng);')
        .join('\n');
    final query = '[out:json][timeout:30];\n(\n$filters\n);\nout center 80;';

    Object? lastError;
    for (final url in [AppConfig.overpassUrl, AppConfig.overpassFallbackUrl]) {
      try {
        final res = await http
            .post(
              Uri.parse(url),
              headers: {'User-Agent': AppConfig.userAgent},
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 35));
        if (res.statusCode != 200) {
          throw ApiException.fromResponse(
              'Hospital search', res.statusCode, res.body);
        }
        return _parse(res.body, lat, lng, types.first);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? ApiException('Hospital search failed.');
  }

  List<Facility> _parse(String body, double lat, double lng, String type) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final elements = (data['elements'] as List?) ?? const [];
    final fallbackName = type == 'fire_station' ? 'Fire station' : 'Hospital';

    double dist(Facility f) => haversineMeters(lat, lng, f.lat, f.lng);

    final named = <String, Facility>{};
    final unnamed = <Facility>[];
    for (final e in elements) {
      final f = Facility.fromOverpass(e as Map<String, dynamic>, fallbackName);
      if (f == null) continue;
      if (f.isNamed) {
        final key = f.name.toLowerCase();
        final old = named[key];
        if (old == null || dist(f) < dist(old)) named[key] = f;
      } else {
        unnamed.add(f);
      }
    }

    final list = named.isNotEmpty ? named.values.toList() : unnamed;
    list.sort((a, b) => dist(a).compareTo(dist(b)));
    return list.take(AppConfig.maxResults).toList();
  }
}

class RoutesService {
  Map<String, String> get _headers => {'User-Agent': AppConfig.userAgent};

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await http
        .get(Uri.parse('${AppConfig.osrmBaseUrl}$path'), headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw ApiException.fromResponse('Routing', res.statusCode, res.body);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') {
      throw ApiException('Routing error: ${data['code']} ${data['message'] ?? ''}');
    }
    return data;
  }

  Future<List<RouteInfo?>> estimate({
    required double fromLat,
    required double fromLng,
    required List<Facility> targets,
  }) async {
    final coords = [
      '$fromLng,$fromLat',
      for (final t in targets) '${t.lng},${t.lat}',
    ].join(';');
    final data = await _get(
        '/table/v1/driving/$coords?sources=0&annotations=duration,distance');

    final durs = (data['durations'] as List).first as List;
    final dists =
        data['distances'] == null ? null : (data['distances'] as List).first as List;

    return [
      for (var i = 0; i < targets.length; i++)
        if (durs[i + 1] == null)
          null
        else
          RouteInfo(
            durationSeconds: (durs[i + 1] as num).round(),
            distanceMeters: (dists != null && dists[i + 1] != null)
                ? (dists[i + 1] as num).round()
                : (haversineMeters(fromLat, fromLng, targets[i].lat,
                            targets[i].lng) *
                        1.3)
                    .round(),
            encodedPolyline: '',
          ),
    ];
  }

  Future<List<RouteInfo>> drive({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    bool alternatives = false,
  }) async {
    final data = await _get(
        '/route/v1/driving/$fromLng,$fromLat;$toLng,$toLat'
        '?overview=full&geometries=polyline&alternatives=$alternatives');
    final routes = (data['routes'] as List?) ?? const [];
    return [
      for (final r in routes)
        RouteInfo(
          durationSeconds: ((r as Map)['duration'] as num).round(),
          distanceMeters: (r['distance'] as num).round(),
          encodedPolyline: r['geometry'] as String,
        ),
    ];
  }
}