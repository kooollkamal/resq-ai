import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ai/facility_ranker.dart';
import '../config/app_config.dart';
import '../models/facility.dart';
import '../services/location_service.dart';
import '../services/osm_services.dart';
import '../theme/app_theme.dart';

class NearbyScreen extends StatefulWidget {
  final String type;
  final String severity;

  const NearbyScreen({super.key, required this.type, required this.severity});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final _places = PlacesService();
  final _routes = RoutesService();
  final _map = MapController();

  bool _mapReady = false;
  UserLocation? _user;
  List<Facility> _items = [];
  int _selected = 0;
  List<RouteInfo> _selectedRoutes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await LocationService().current();
      final found = await _places.nearby(
        lat: user.lat,
        lng: user.lng,
        types: AppConfig.placeTypesFor(widget.type),
      );
      if (found.isEmpty) {
        throw Exception(
            'No ${AppConfig.facilityLabel(widget.type)} found within '
            '${(AppConfig.searchRadiusMeters / 1000).round()} km.');
      }

      final estimates = await _routes.estimate(
        fromLat: user.lat,
        fromLng: user.lng,
        targets: found,
      );
      for (var i = 0; i < found.length; i++) {
        found[i].route = estimates[i];
      }

      final ranked = FacilityRanker.rank(found, widget.severity);
      if (!mounted) return;
      setState(() {
        _user = user;
        _items = ranked;
        _selected = 0;
        _selectedRoutes = [];
        _loading = false;
      });
      _loadRoute();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadRoute() async {
    final u = _user;
    if (u == null || _items.isEmpty) return;
    final index = _selected;
    final f = _items[index];
    _fitCamera();

    try {
      final routes = await _routes.drive(
        fromLat: u.lat,
        fromLng: u.lng,
        toLat: f.lat,
        toLng: f.lng,
        alternatives: true,
      );
      if (!mounted || index != _selected) return;
      if (routes.isNotEmpty) {
        setState(() {
          f.route = routes.first;
          _selectedRoutes = routes;
        });
      }
    } catch (_) {
      _toast('Could not draw the route line. Try again.');
    }
  }

  void _select(int i) {
    setState(() {
      _selected = i;
      _selectedRoutes = [];
    });
    _loadRoute();
  }

  void _fitCamera() {
    final u = _user;
    if (!_mapReady || u == null || _items.isEmpty) return;
    final f = _items[_selected];
    try {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(
              [LatLng(u.lat, u.lng), LatLng(f.lat, f.lng)]),
          padding: const EdgeInsets.all(60),
          maxZoom: 16,
        ),
      );
    } catch (_) {}
  }

  Future<void> _open(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _toast('Could not open this on the device.');
    } catch (_) {
      _toast('Could not open this on the device.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _navigate(Facility f) => _open(Uri.parse(
      'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car'
      '&route=${_user!.lat}%2C${_user!.lng}%3B${f.lat}%2C${f.lng}'));

  void _call(Facility f) {
    final number = (f.phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) return;
    _open(Uri(scheme: 'tel', path: number));
  }

  List<Marker> _markers() {
    final list = <Marker>[];
    for (var i = 0; i < _items.length; i++) {
      final f = _items[i];
      final selected = i == _selected;
      list.add(Marker(
        point: LatLng(f.lat, f.lng),
        width: 44,
        height: 44,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () => _select(i),
          child: Icon(
            Icons.location_on,
            size: selected ? 44 : 34,
            color: selected ? Colors.green.shade700 : AppColors.red,
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
    final list = <Polyline>[];
    for (var i = _selectedRoutes.length - 1; i >= 0; i--) {
      final pts = decodePolyline(_selectedRoutes[i].encodedPolyline);
      if (pts.isEmpty) continue;
      list.add(Polyline(
        points: pts,
        strokeWidth: i == 0 ? 6 : 4,
        color: i == 0 ? const Color(0xFF1565C0) : Colors.grey,
      ));
    }
    return list;
  }

  Widget _stat(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.black54),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(fontSize: 13, color: color ?? Colors.black87)),
      ],
    );
  }

  Widget _tile(int i) {
    final f = _items[i];
    final r = f.route;
    final selected = i == _selected;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.red : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _select(i),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: i == 0 ? AppColors.red : Colors.black26,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        if (f.address.isNotEmpty)
                          Text(f.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  if (i == 0)
                    const Text('BEST MATCH',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.red)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _stat(Icons.timer,
                      r == null ? 'No route' : '${r.minutes.round()} min'),
                  if (r != null)
                    _stat(Icons.straighten, '${r.km.toStringAsFixed(1)} km'),
                  if (f.hasEmergency == true)
                    _stat(Icons.emergency, 'Emergency dept',
                        color: Colors.green.shade700),
                  if (f.openingHours != null)
                    _stat(Icons.schedule, f.openingHours!),
                ],
              ),
              if (selected) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (f.phone != null) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _call(f),
                          icon: const Icon(Icons.call),
                          label: const Text('Call'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44)),
                        onPressed: () => _navigate(f),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigate'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final u = _user!;
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: LatLng(u.lat, u.lng),
              initialZoom: 13,
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
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => _open(
                        Uri.parse('https://www.openstreetmap.org/copyright')),
                  ),
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
              'GPS unavailable, showing results around the city centre.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            'Ranked by AI for a ${widget.severity.toLowerCase()} '
            '${widget.type.toLowerCase()} case: drive time (no live traffic), '
            'distance and emergency department.',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        Expanded(
          flex: 5,
          child: ListView.builder(
            itemCount: _items.length,
            itemBuilder: (_, i) => _tile(i),
          ),
        ),
      ],
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
      appBar: AppBar(
          title: Text('Nearby ${AppConfig.facilityLabel(widget.type)}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.red))
          : _error != null
              ? _errorView()
              : _content(),
    );
  }
}