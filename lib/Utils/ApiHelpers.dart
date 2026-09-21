import 'package:airotrack/Configs/DioClient.dart';
import 'package:airotrack/Utils/Utils.dart';
import 'package:intl/intl.dart';

/// Ensures the Dio client has the saved Bearer token applied.
Future<void> ensureApiToken() async {
  final token = await getSavedObject('token');
  if (token != null) {
    DioClient().updateToken(token.toString().trim());
  }
}

/// Date + period helpers shared by dashboard / statistics / reports.
class PeriodQuery {
  final String period;
  final String fromDate;
  final String toDate;
  final int days;

  const PeriodQuery({
    required this.period,
    required this.fromDate,
    required this.toDate,
    required this.days,
  });

  Map<String, dynamic> toQuery({
    String? imei,
    int? limit,
    bool includeDays = false,
    bool includePeriod = true,
  }) {
    final map = <String, dynamic>{
      if (imei != null) 'imei': imei,
      if (includePeriod) 'period': period,
      'from_date': fromDate,
      'to_date': toDate,
      if (includeDays) 'days': days.toString(),
      if (limit != null) 'limit': limit.toString(),
    };
    return map;
  }

  static final _fmt = DateFormat('yyyy-MM-dd');

  static PeriodQuery fromLabel(String label, {DateTime? customFrom, DateTime? customTo}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (label.toLowerCase()) {
      case 'yesterday':
        final y = today.subtract(const Duration(days: 1));
        return PeriodQuery(
          period: 'yesterday',
          fromDate: _fmt.format(y),
          toDate: _fmt.format(y),
          days: 1,
        );
      case 'week':
        final from = today.subtract(const Duration(days: 6));
        return PeriodQuery(
          period: 'week',
          fromDate: _fmt.format(from),
          toDate: _fmt.format(today),
          days: 7,
        );
      case 'month':
        final from = DateTime(today.year, today.month, 1);
        final days = today.difference(from).inDays + 1;
        return PeriodQuery(
          period: 'month',
          fromDate: _fmt.format(from),
          toDate: _fmt.format(today),
          days: days,
        );
      case 'custom':
        final from = customFrom ?? today;
        final to = customTo ?? today;
        final start = DateTime(from.year, from.month, from.day);
        final end = DateTime(to.year, to.month, to.day);
        final days = end.difference(start).inDays + 1;
        return PeriodQuery(
          period: 'custom',
          fromDate: _fmt.format(start),
          toDate: _fmt.format(end),
          days: days < 1 ? 1 : days,
        );
      case 'today':
      default:
        return PeriodQuery(
          period: 'today',
          fromDate: _fmt.format(today),
          toDate: _fmt.format(today),
          days: 1,
        );
    }
  }
}

/// Pulls a nested map from common API envelopes.
Map<String, dynamic>? asStringKeyedMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

/// Finds the first non-null string among candidate keys.
String pickString(Map<String, dynamic>? map, List<String> keys, {String fallback = ''}) {
  if (map == null) return fallback;
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return fallback;
}

num pickNum(Map<String, dynamic>? map, List<String> keys, {num fallback = 0}) {
  if (map == null) return fallback;
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    if (value is num) return value;
    final parsed = num.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return fallback;
}

/// Extracts a list payload from varied report/dashboard response shapes.
List<dynamic> extractList(dynamic data, {List<String> preferredKeys = const []}) {
  if (data is List) return data;
  final map = asStringKeyedMap(data);
  if (map == null) return const [];

  for (final key in preferredKeys) {
    final value = map[key];
    if (value is List) return value;
  }

  const fallbackKeys = [
    'reports',
    'data',
    'list',
    'items',
    'records',
    'rows',
    'alerts',
    'result',
  ];
  for (final key in fallbackKeys) {
    final value = map[key];
    if (value is List) return value;
  }

  // Sometimes the list is nested one level deeper: data.reports.list
  for (final entry in map.entries) {
    if (entry.value is List) return entry.value as List;
    final nested = asStringKeyedMap(entry.value);
    if (nested != null) {
      for (final key in [...preferredKeys, ...fallbackKeys]) {
        final value = nested[key];
        if (value is List) return value;
      }
    }
  }
  return const [];
}
