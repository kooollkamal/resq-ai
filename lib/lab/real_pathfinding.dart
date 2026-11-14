import 'package:latlong2/latlong.dart';
import '../services/osm_services.dart' show haversineMeters;
import 'real_graph.dart';

class PathResult {
  final String algorithm;
  final List<int> path;
  final double meters;
  final int visited;
  final int microseconds;

  const PathResult({
    required this.algorithm,
    required this.path,
    required this.meters,
    required this.visited,
    required this.microseconds,
  });

  bool get found => path.isNotEmpty;
  double get km => meters / 1000.0;
  double get millis => microseconds / 1000.0;
}

class _Entry {
  final int node;
  final double priority;
  const _Entry(this.node, this.priority);
}

class _MinHeap {
  final List<_Entry> _a = [];

  bool get isEmpty => _a.isEmpty;

  void push(int node, double priority) {
    _a.add(_Entry(node, priority));
    var i = _a.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_a[p].priority <= _a[i].priority) break;
      final t = _a[p];
      _a[p] = _a[i];
      _a[i] = t;
      i = p;
    }
  }

  _Entry pop() {
    final top = _a.first;
    final last = _a.removeLast();
    if (_a.isNotEmpty) {
      _a[0] = last;
      var i = 0;
      final n = _a.length;
      while (true) {
        final l = 2 * i + 1;
        final r = l + 1;
        var s = i;
        if (l < n && _a[l].priority < _a[s].priority) s = l;
        if (r < n && _a[r].priority < _a[s].priority) s = r;
        if (s == i) break;
        final t = _a[s];
        _a[s] = _a[i];
        _a[i] = t;
        i = s;
      }
    }
    return top;
  }
}

class PathFinder {
  static PathResult dijkstra(RealGraph g, int start, int goal) =>
      _run(g, start, goal, false);

  static PathResult astar(RealGraph g, int start, int goal) =>
      _run(g, start, goal, true);

  static PathResult _run(RealGraph g, int start, int goal, bool useAstar) {
    final name = useAstar ? 'A*' : 'Dijkstra';
    final sw = Stopwatch()..start();

    final goalNode = g.nodes[goal]!;
    double h(int id) {
      if (!useAstar) return 0;
      final n = g.nodes[id]!;
      return haversineMeters(n.lat, n.lng, goalNode.lat, goalNode.lng);
    }

    final dist = <int, double>{start: 0};
    final prev = <int, int>{};
    final closed = <int>{};
    final heap = _MinHeap()..push(start, h(start));
    var visited = 0;

    while (!heap.isEmpty) {
      final cur = heap.pop().node;
      if (!closed.add(cur)) continue;
      visited++;
      if (cur == goal) break;

      final d = dist[cur]!;
      for (final e in g.adj[cur] ?? const <RoadEdge>[]) {
        if (closed.contains(e.to)) continue;
        final nd = d + e.meters;
        if (nd < (dist[e.to] ?? double.infinity)) {
          dist[e.to] = nd;
          prev[e.to] = cur;
          heap.push(e.to, nd + h(e.to));
        }
      }
    }
    sw.stop();

    if (!closed.contains(goal)) {
      return PathResult(
        algorithm: name,
        path: const [],
        meters: 0,
        visited: visited,
        microseconds: sw.elapsedMicroseconds,
      );
    }

    final path = <int>[goal];
    var c = goal;
    while (c != start) {
      c = prev[c]!;
      path.add(c);
    }

    return PathResult(
      algorithm: name,
      path: path.reversed.toList(),
      meters: dist[goal]!,
      visited: visited,
      microseconds: sw.elapsedMicroseconds,
    );
  }
}

List<LatLng> pathToPoints(RealGraph g, List<int> path) => [
      for (final id in path) LatLng(g.nodes[id]!.lat, g.nodes[id]!.lng),
    ];