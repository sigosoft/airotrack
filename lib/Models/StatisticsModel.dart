import 'package:airotrack/Utils/ApiHelpers.dart';

class StatisticsModel {
  final String routeLength;
  final String moveDuration;
  final String stopDuration;
  final String idleDuration;
  final String topSpeed;
  final String averageSpeed;
  final String overSpeedCount;
  final String stopCount;
  final String engineHours;
  final String odometer;

  const StatisticsModel({
    this.routeLength = '—',
    this.moveDuration = '—',
    this.stopDuration = '—',
    this.idleDuration = '—',
    this.topSpeed = '—',
    this.averageSpeed = '—',
    this.overSpeedCount = '—',
    this.stopCount = '—',
    this.engineHours = '—',
    this.odometer = '—',
  });

  /// Maps `GET statistics` → `data.statistics` fields from the API.
  factory StatisticsModel.fromJson(dynamic raw) {
    final root = asStringKeyedMap(raw) ?? {};
    final data = asStringKeyedMap(root['data']) ?? root;
    final stats = asStringKeyedMap(data['statistics']) ?? data;

    return StatisticsModel(
      routeLength: _formatKm(stats['route_length_km']),
      moveDuration: _formatDuration(stats['move_duration']),
      stopDuration: _formatDuration(stats['stop_duration']),
      idleDuration: _formatDuration(stats['idle_duration']),
      topSpeed: _formatSpeed(stats['top_speed']),
      averageSpeed: _formatSpeed(stats['average_speed']),
      overSpeedCount: _formatCount(stats['overspeed_count']),
      stopCount: _formatCount(stats['stop_count']),
      engineHours: _formatDuration(stats['engine_hours']),
      odometer: _formatKm(stats['odometer_km']),
    );
  }

  static String _formatKm(dynamic raw) {
    if (raw == null) return '—';
    final n = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (n == null) return '—';
    if (n == n.roundToDouble()) return '${n.toInt()} km';
    return '${n.toStringAsFixed(2)} km';
  }

  static String _formatSpeed(dynamic raw) {
    if (raw == null) return '—';
    final n = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (n == null) return '—';
    if (n == n.roundToDouble()) return '${n.toInt()} kmph';
    return '${n.toStringAsFixed(2)} kmph';
  }

  static String _formatDuration(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '—';
    return text;
  }

  static String _formatCount(dynamic raw) {
    if (raw == null) return '—';
    if (raw is num) return raw.toInt().toString();
    final text = raw.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '—';
    return text;
  }
}
