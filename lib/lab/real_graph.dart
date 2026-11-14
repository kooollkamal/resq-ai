import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/osm_services.dart' show haversineMeters;

class RoadNode {
  final int id;
  final double lat;
  final double lng;
  const RoadNode(this.id, this.lat, this.lng);
}

class RoadEdge {
  final int to;
  final double meters;
  final String name;
  const RoadEdge(this.to, this.meters, this.name);
}

class RealGraph {
  final Map<int, RoadNode> nodes = {};
  final Map<int, List<RoadEdge>> adj = {};

  int get nodeCount => nodes.length;
  int get edgeCount => adj.values.fold(0, (s, l) => s + l.length);

  void addEdge(int a, int b, double meters, String name) {
    adj.putIfAbsent(a, () => []).add(RoadEdge(b, meters, name));
  }

  /// Closest road node to a point, or -1 if the graph is empty.
  int nearestNode(double lat, double lng) {
    var best = -1;
    var bestDist = double.infinity;
    for (final n in nodes.values) {
      if (!adj.containsKey(n.id)) continue;
      final d = haversineMeters(lat, lng, n.lat, n.lng);
      if (d < bestDist) {
        bestDist = d;
        best = n.id;
      }
    }
    return best;
  }
}

class RealGraphLoader {
  static const _roadTypes =
      'motorway|trunk|primary|secondary|tertiary|unclassified|residential|'
      'motorway_link|trunk_link|primary_link|secondary_link|tertiary_link';

  static Future<RealGraph> load(double lat, double lng,
      {int radius = 3000}) async {
    final query = '[out:json][timeout:25];'
        'way["highway"~"^($_roadTypes)\$"](around:$radius,$lat,$lng);'
        'out geom;';

    Object? lastError;
    for (final url in [AppConfig.overpassUrl, AppConfig.overpassFallbackUrl]) {
      try {
        final res = await http
            .post(
              Uri.parse(url),
              headers: {'User-Agent': AppConfig.userAgent},
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 45));
        if (res.statusCode != 200) {
          throw Exception('Road data error ${res.statusCode}');
        }
        return _build(res.body);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Could not load road data.');
  }

  static RealGraph _build(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final elements = (data['elements'] as List?) ?? const [];
    final g = RealGraph();

    for (final e in elements) {
      final w = e as Map<String, dynamic>;
      if (w['type'] != 'way') continue;

      final ids = (w['nodes'] as List?) ?? const [];
      final geom = (w['geometry'] as List?) ?? const [];
      if (ids.length < 2 || geom.length != ids.length) continue;
      if (geom.any((p) => p == null)) continue;

      final tags =
          (w['tags'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final name =
          (tags['name'] ?? tags['ref'] ?? tags['highway'] ?? 'road').toString();

      final oneway = tags['oneway']?.toString();
      final roundabout = tags['junction'] == 'roundabout';
      final reverseOnly = oneway == '-1';
      final isOneWay = oneway == 'yes' || oneway == '1' || roundabout;
      final fwd = !reverseOnly;
      final bwd = reverseOnly || !isOneWay;

      for (var i = 0; i < ids.length; i++) {
        final p = geom[i] as Map;
        g.nodes.putIfAbsent(
          ids[i] as int,
          () => RoadNode(ids[i] as int, (p['lat'] as num).toDouble(),
              (p['lon'] as num).toDouble()),
        );
      }

      for (var i = 0; i < ids.length - 1; i++) {
        final a = ids[i] as int;
        final b = ids[i + 1] as int;
        final na = g.nodes[a]!;
        final nb = g.nodes[b]!;
        final d = haversineMeters(na.lat, na.lng, nb.lat, nb.lng);
        if (fwd) g.addEdge(a, b, d, name);
        if (bwd) g.addEdge(b, a, d, name);
      }
    }
    return g;
  }
}