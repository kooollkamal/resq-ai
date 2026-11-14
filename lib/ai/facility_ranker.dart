import '../models/facility.dart';

class _Weights {
  final double eta;
  final double distance;
  final double emergency;
  const _Weights(this.eta, this.distance, this.emergency);
}

class FacilityRanker {
  static _Weights _weights(String severity) {
    switch (severity) {
      case 'Critical':
        return const _Weights(1.0, 0.2, 10.0);
      case 'Serious':
        return const _Weights(1.0, 0.3, 6.0);
      default:
        return const _Weights(1.0, 0.5, 2.0);
    }
  }

  static List<Facility> rank(List<Facility> items, String severity) {
    final w = _weights(severity);
    for (final f in items) {
      final r = f.route;
      if (r == null) {
        f.score = double.infinity;
        continue;
      }
      double s = w.eta * r.minutes + w.distance * r.km;
      if (f.hasEmergency == true) s -= w.emergency;
      if (f.hasEmergency == false) s += w.emergency;
      f.score = s;
    }
    final ranked = List<Facility>.of(items)
      ..sort((a, b) => a.score.compareTo(b.score));
    return ranked;
  }
}