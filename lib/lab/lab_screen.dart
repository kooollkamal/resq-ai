import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../models/facility.dart';
import '../services/location_service.dart';
import '../services/osm_services.dart';
import '../theme/app_theme.dart';
import 'real_graph.dart';
import 'real_pathfinding.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  static const double _maxHospitalMeters = 2800;

  final _map = MapController();
  bool _mapReady = false;

  bool _loading = true;
  String _status = 'Getting your location...';
  String? _error;

  UserLocation? _user;
  RealGraph? _graph;
  List<Facility> _hospitals = [];
  int _selected = 0;

  PathResult? _dij;
  PathResult? _ast;
  double? _osrmKm;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _setStatus(String s) {
    if (mounted) setState(() => _status = s);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _status = 'Getting your location...';
    });

    try {
      final user = await LocationService().current();

      _setStatus('Finding hospitals nearby...');
      final all = await PlacesService().nearby(
        lat: user.lat,
        lng: user.lng,
        types: const ['hospital'],
      );
      final near = all
          .where((f) =>
              haversineMeters(user.lat, user.lng, f.lat, f.lng) <=
              _maxHospitalMeters)
          .toList();
      if (near.isEmpty) {
        throw Exception(
            'No hospital within 2.8 km of this location. Set the emulator '
            'location to a city area and try again.');
      }

      _setStatus('Downloading real road network...');
      final graph = await RealGraphLoader.load(user.lat, user.lng, radius: 3000);
      if (graph.nodeCount == 0) {
        throw Exception('No road data found around this location.');
      }

      if (!mounted) return;
      setState(() {
        _user = user;
        _graph = graph;
        _hospitals = near;
        _selected = 0;
        _loading = false;
      });
      _solve();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _solve() async {
    final g = _graph;
    final u = _user;
    if (g == null || u == null || _hospitals.isEmpty) return;

    final sel = _selected;
    final h = _hospitals[sel];
    final s = g.nearestNode(u.lat, u.lng);
    final t = g.nearestNode(h.lat, h.lng);
    if (s < 0 || t < 0) return;

    final d = PathFinder.dijkstra(g, s, t);
    final a = PathFinder.astar(g, s, t);

    setState(() {
      _dij = d;
      _ast = a;
      _osrmKm = null;
    });
    _fitCamera();

    try {
      final r = await RoutesService().drive(
        fromLat: u.lat,
        fromLng: u.lng,
        toLat: h.lat,
        toLng: h.lng,
      );
      if (!mounted || sel != _selected) return;
      if (r.isNotEmpty) setState(() => _osrmKm = r.first.km);
    } catch (_) {}
  }

  void _select(int i) {
    setState(() {
      _selected = i;
      _dij = null;
      _ast = null;
      _osrmKm = null;
    });
    _solve();
  }

  void _fitCamera() {
    final u = _user;
    if (!_mapReady || u == null || _hospitals.isEmpty) return;
    final h = _hospitals[_selected];
    try {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(
              [LatLng(u.lat, u.lng), LatLng(h.lat, h.lng)]),
          padding: const EdgeInsets.all(50),
          maxZoom: 17,
        ),
      );
    } catch (_) {}
  }

  List<Marker> _markers() {
    final list = <Marker>[];
    for (var i = 0; i < _hospitals.length; i++) {
      final h = _hospitals[i];
      final sel = i == _selected;
      list.add(Marker(
        point: LatLng(h.lat, h.lng),
        width: 44,
        height: 44,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () => _select(i),
          child: Icon(
            Icons.local_hospital,
            size: sel ? 40 : 30,
            color: sel ? Colors.green.shade700 : AppColors.red,
          ),
        ),
      ));
    }
    final u = _user;
    if (u != null) {
      list.add(Marker(
        point: LatLng(u.lat, u.lng),
        width: 36,
        height: 36,
        child: const Icon(Icons.my_location,
            size: 28, color: Color(0xFF1565C0)),
      ));
    }
    return list;
  }

  List<Polyline> _polylines() {
    final g = _graph;
    final list = <Polyline>[];
    if (g == null) return list;
    final d = _dij;
    final a = _ast;
    if (d != null && d.found) {
      list.add(Polyline(
        points: pathToPoints(g, d.path),
        strokeWidth: 9,
        color: Colors.orange,
      ));
    }
    if (a != null && a.found) {
      list.add(Polyline(
        points: pathToPoints(g, a.path),
        strokeWidth: 4,
        color: const Color(0xFF1565C0),
      ));
    }
    return list;
  }

  Widget _cell(String t, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color,
          ),
        ),
      );

  TableRow _row(String a, String b, String c, String d,
      {bool header = false, Color? color}) {
    return TableRow(children: [
      _cell(a, bold: header, color: color),
      _cell(b, bold: header),
      _cell(c, bold: header),
      _cell(d, bold: header),
    ]);
  }

  TableRow _resultRow(PathResult? r, Color color) {
    if (r == null) return _row('...', '', '', '', color: color);
    if (!r.found) {
      return _row(r.algorithm, 'No path', '${r.visited}',
          '${r.millis.toStringAsFixed(1)} ms',
          color: color);
    }
    return _row(
      r.algorithm,
      '${r.km.toStringAsFixed(2)} km',
      '${r.visited}',
      '${r.millis.toStringAsFixed(1)} ms',
      color: color,
    );
  }

  String _summary() {
    final d = _dij;
    final a = _ast;
    if (d == null || a == null) return 'Computing routes...';
    if (!d.found || !a.found) {
      return 'No connected path inside the downloaded area. Pick another hospital.';
    }
    if (d.visited == 0) return '';
    final saved = 100 * (d.visited - a.visited) / d.visited;
    return 'A* explored ${saved.toStringAsFixed(0)}% fewer road nodes than '
        'Dijkstra and found the same shortest distance.';
  }

  Widget _content() {
    final u = _user!;
    final g = _graph!;
    final h = _hospitals[_selected];

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: LatLng(u.lat, u.lng),
              initialZoom: 14,
              onMapReady: () {
                _mapReady = true;
                _fitCamera();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: AppConfig.tileUrl,
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: AppConfig.appPackage,
              ),
              PolylineLayer(polylines: _polylines()),
              MarkerLayer(markers: _markers()),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        if (u.isFallback)
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: const EdgeInsets.all(8),
            child: const Text(
              'GPS unavailable, using the city centre.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        Expanded(
          flex: 5,
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Text('To: ${h.name}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Real OpenStreetMap roads: ${g.nodeCount} junctions, '
                '${g.edgeCount} road segments. Tap a hospital pin to change '
                'the destination.',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.3),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.1),
                  3: FlexColumnWidth(1.0),
                },
                children: [
                  _row('Algorithm', 'Distance', 'Nodes', 'Time', header: true),
                  _resultRow(_dij, Colors.orange.shade800),
                  _resultRow(_ast, const Color(0xFF1565C0)),
                  _row(
                    'OSRM',
                    _osrmKm == null ? '...' : '${_osrmKm!.toStringAsFixed(2)} km',
                    '-',
                    '-',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_summary(), style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              const Text(
                'Orange line: Dijkstra. Blue line: A*. Both use your own code '
                'on the real road graph. OSRM is the reference routing engine.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.red),
            const SizedBox(height: 16),
            Text(_status, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.red),
            const SizedBox(height: 12),
            Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Algorithm Lab (real roads)')),
      body: _loading
          ? _loadingView()
          : _error != null
              ? _errorView()
              : _content(),
    );
  }
}