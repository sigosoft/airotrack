// Models for vehicle reminders, expenses and support tickets, matching the
// website API (`vehicle_reminders`, `expenses`, `support_tickets` and their
// view/add/update calls).

int _int(dynamic v, [int fallback = 0]) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback);

num? _numOrNull(dynamic v) =>
    v == null ? null : (v is num ? v : num.tryParse(v.toString()));

String _str(dynamic v) {
  if (v == null) return '';
  final s = v.toString().trim();
  return s.toLowerCase() == 'null' ? '' : s;
}

DateTime? _date(dynamic v) {
  final s = _str(v);
  if (s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}

/// One choice from an options endpoint: `{key: 1, label: "Service"}`.
class OptionItem {
  final int key;
  final String label;
  const OptionItem(this.key, this.label);

  factory OptionItem.fromJson(Map json) =>
      OptionItem(_int(json['key']), _str(json['label']));

  static List<OptionItem> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(OptionItem.fromJson)
        .where((o) => o.label.isNotEmpty)
        .toList();
  }

  /// Label for [key] from [options], or [fallback] when it is not listed.
  static String labelFor(List<OptionItem> options, int key, {String fallback = ''}) {
    for (final o in options) {
      if (o.key == key) return o.label;
    }
    return fallback;
  }
}

/// Pagination block the list endpoints return.
class PageInfo {
  final int currentPage;
  final int lastPage;
  final int total;
  const PageInfo({this.currentPage = 1, this.lastPage = 1, this.total = 0});

  factory PageInfo.fromJson(dynamic raw) {
    if (raw is! Map) return const PageInfo();
    return PageInfo(
      currentPage: _int(raw['current_page'], 1),
      lastPage: _int(raw['last_page'], 1),
      total: _int(raw['total']),
    );
  }

  bool get hasMore => currentPage < lastPage;
}

class ReminderModel {
  final int id;
  final String vehicleNumber;
  final String imei;
  final int type;
  final String typeLabel;
  final num startOdometer;
  final num period;
  final String remarks;
  final DateTime? createdAt;

  const ReminderModel({
    required this.id,
    required this.vehicleNumber,
    this.imei = '',
    required this.type,
    this.typeLabel = '',
    this.startOdometer = 0,
    this.period = 0,
    this.remarks = '',
    this.createdAt,
  });

  factory ReminderModel.fromJson(Map json) => ReminderModel(
        id: _int(json['id']),
        vehicleNumber: _str(json['vehicle_number']),
        imei: _str(json['imei']),
        type: _int(json['type']),
        typeLabel: _str(json['type_label']),
        startOdometer: _numOrNull(json['start_odometer']) ?? 0,
        period: _numOrNull(json['period']) ?? 0,
        remarks: _str(json['remarks']),
        createdAt: _date(json['created_at']),
      );

  /// Odometer reading at which this reminder is next due.
  num get dueAt => startOdometer + period;
}

class ExpenseModel {
  final int id;
  final String vehicleNumber;
  final String imei;
  final DateTime? expenseDate;
  final int expenseType;
  final String expenseTypeLabel;
  final num? quantity;
  final num amount;
  final int paymentMethod;
  final String paymentMethodLabel;
  final String description;
  final String image;
  final DateTime? createdAt;

  const ExpenseModel({
    required this.id,
    required this.vehicleNumber,
    this.imei = '',
    this.expenseDate,
    required this.expenseType,
    this.expenseTypeLabel = '',
    this.quantity,
    this.amount = 0,
    required this.paymentMethod,
    this.paymentMethodLabel = '',
    this.description = '',
    this.image = '',
    this.createdAt,
  });

  factory ExpenseModel.fromJson(Map json) => ExpenseModel(
        id: _int(json['id']),
        vehicleNumber: _str(json['vehicle_number']),
        imei: _str(json['imei']),
        // The server stores the picked date as local midnight in UTC
        // (e.g. 2026-11-17T18:30Z for 18 Nov in India), so convert to local.
        expenseDate: _date(json['expense_date']),
        expenseType: _int(json['expense_type']),
        expenseTypeLabel: _str(json['expense_type_label']),
        quantity: _numOrNull(json['quantity']),
        amount: _numOrNull(json['amount']) ?? 0,
        paymentMethod: _int(json['payment_method']),
        paymentMethodLabel: _str(json['payment_method_label']),
        description: _str(json['description']),
        image: _str(json['image']),
        createdAt: _date(json['created_at']),
      );
}

class TicketStatusLog {
  final int toStatus;
  final String toStatusLabel;
  final String remarks;
  final DateTime? createdAt;

  const TicketStatusLog({
    required this.toStatus,
    this.toStatusLabel = '',
    this.remarks = '',
    this.createdAt,
  });

  factory TicketStatusLog.fromJson(Map json) => TicketStatusLog(
        toStatus: _int(json['to_status']),
        toStatusLabel: _str(json['to_status_label']),
        remarks: _str(json['remarks']),
        createdAt: _date(json['created_at']),
      );
}

class SupportTicketModel {
  final int id;
  final String vehicleNumber;
  final String imei;
  final String contactNo;
  final int type;
  final String typeLabel;
  final String message;
  final String image;
  final int status;
  final String statusLabel;
  final DateTime? createdAt;
  final List<TicketStatusLog> statusLogs;

  const SupportTicketModel({
    required this.id,
    required this.vehicleNumber,
    this.imei = '',
    this.contactNo = '',
    required this.type,
    this.typeLabel = '',
    this.message = '',
    this.image = '',
    required this.status,
    this.statusLabel = '',
    this.createdAt,
    this.statusLogs = const [],
  });

  factory SupportTicketModel.fromJson(Map json) => SupportTicketModel(
        id: _int(json['id']),
        vehicleNumber: _str(json['vehicle_number']),
        imei: _str(json['imei']),
        contactNo: _str(json['contact_no']),
        type: _int(json['type']),
        typeLabel: _str(json['type_label']),
        message: _str(json['message']),
        image: _str(json['image']),
        status: _int(json['status']),
        statusLabel: _str(json['status_label']),
        createdAt: _date(json['created_at']),
        statusLogs: (json['status_logs'] is List)
            ? (json['status_logs'] as List)
                .whereType<Map>()
                .map(TicketStatusLog.fromJson)
                .toList()
            : const [],
      );
}
