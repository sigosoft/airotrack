import 'package:airotrack/Utils/ApiHelpers.dart';
import 'package:fl_chart/fl_chart.dart';

class FleetStatus {
  final int total;
  final int running;
  final int stopped;
  final int idle;
  final int expired;
  final int inactive;
  final int noData;

  const FleetStatus({
    this.total = 0,
    this.running = 0,
    this.stopped = 0,
    this.idle = 0,
    this.expired = 0,
    this.inactive = 0,
    this.noData = 0,
  });

  factory FleetStatus.fromJson(Map<String, dynamic>? map) {
    final running = pickNum(map, [
      'running',
      'running_vehicles',
      'running_count',
    ]).toInt();
    final stopped = pickNum(map, [
      'stopped',
      'stopped_vehicles',
      'stopped_count',
    ]).toInt();
    final idle = pickNum(map, ['idle', 'idle_vehicles', 'idle_count']).toInt();
    final expired = pickNum(map, [
      'expired',
      'expired_vehicles',
      'expired_count',
    ]).toInt();
    final inactive = pickNum(map, [
      'inactive',
      'inactive_vehicles',
      'inactive_count',
    ]).toInt();
    final noData = pickNum(map, [
      'no_data',
      'nodata',
      'no_data_vehicles',
      'no_data_count',
    ]).toInt();
    var total = pickNum(map, [
      'total',
      'total_vehicles',
      'total_count',
    ]).toInt();
    if (total <= 0) {
      total = running + stopped + idle + expired + inactive + noData;
    }
    return FleetStatus(
      total: total,
      running: running,
      stopped: stopped,
      idle: idle,
      expired: expired,
      inactive: inactive,
      noData: noData,
    );
  }

  String padded(int value) => value.toString().padLeft(2, '0');
}

class ChartPoint {
  final String label;
  final double value;

  const ChartPoint({required this.label, required this.value});
}

class DashboardModel {
  final FleetStatus fleet;
  final List<ChartPoint> engineHours;
  final List<ChartPoint> travelDistance;

  const DashboardModel({
    this.fleet = const FleetStatus(),
    this.engineHours = const [],
    this.travelDistance = const [],
  });

  factory DashboardModel.fromJson(dynamic raw) {
    final root = asStringKeyedMap(raw) ?? {};
    final data = asStringKeyedMap(root['data']) ?? root;

    final fleetMap =
        asStringKeyedMap(data['fleet_status']) ??
        asStringKeyedMap(data['statistics']) ??
        asStringKeyedMap(data['fleet']) ??
        data;

    final engine = _parseSeries(
      data['engine_hours'] ??
          data['engineHours'] ??
          data['engine_hour_chart'] ??
          data['engine_hours_chart'],
      valueKeys: const ['hours', 'value', 'y', 'count', 'seconds'],
    );
    final distance = _parseSeries(
      data['travel_distance'] ??
          data['travelDistance'] ??
          data['distance_chart'] ??
          data['travel_distance_chart'],
      valueKeys: const [
        'distance_km',
        'distance',
        'km',
        'value',
        'y',
        'count',
      ],
    );

    return DashboardModel(
      fleet: FleetStatus.fromJson(fleetMap),
      engineHours: engine,
      travelDistance: distance,
    );
  }

  static List<ChartPoint> _parseSeries(
    dynamic raw, {
    List<String> valueKeys = const [
      'value',
      'hours',
      'distance_km',
      'km',
      'distance',
      'y',
      'count',
    ],
  }) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((item) {
        if (item is num) {
          return ChartPoint(label: '', value: item.toDouble());
        }
        final map = asStringKeyedMap(item) ?? {};
        return ChartPoint(
          label: pickString(map, ['label', 'date', 'day', 'x', 'name']),
          value: pickNum(map, valueKeys).toDouble(),
        );
      }).toList();
    }
    final map = asStringKeyedMap(raw);
    if (map == null) return const [];
    // Object map of date -> value
    return map.entries.map((e) {
      final v = e.value;
      final numVal = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
      return ChartPoint(label: e.key, value: numVal);
    }).toList();
  }

  List<FlSpot> engineSpots() {
    if (engineHours.isEmpty) return const [];
    return [
      for (var i = 0; i < engineHours.length; i++)
        FlSpot((i + 1).toDouble(), engineHours[i].value),
    ];
  }

  List<String> engineLabels() =>
      engineHours.map((e) => e.label.isEmpty ? '' : e.label).toList();

  List<String> distanceLabels() =>
      travelDistance.map((e) => e.label.isEmpty ? '' : e.label).toList();
}
