import 'dart:typed_data';

import 'package:airotrack/Models/ReportItem.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'reports_controller.dart';

/// One PDF column: its header, relative width and the cell text of a row.
class _Col {
  const _Col(this.header, this.flex, this.value);
  final String header;
  final double flex;
  final String Function(ReportItem r) value;
}

/// Builds the downloadable PDF of a report: a table with the same fields the
/// report screen shows.
class ReportPdf {
  ReportPdf._();

  static String _v(String value) {
    final t = value.trim();
    // ReportItem uses '—' for "no value"; the PDF font has no '—'.
    return (t.isEmpty || t.toLowerCase() == 'null' || t == '—') ? '-' : t;
  }

  static String _loc(ReportItem r) =>
      _v(r.location.isNotEmpty ? r.location : r.startLocation);

  static String _odometer(String raw) {
    final n = num.tryParse(raw.trim());
    return n == null ? _v(raw) : '${n.round()} Km';
  }

  static final _vehicle = _Col('Vehicle', 2.6, (r) => _v(r.vehicleNumber));

  static List<_Col> _columns(ReportType type) {
    switch (type) {
      case ReportType.ignition:
        return [
          _vehicle,
          _Col('Status', 1.4,
              (r) => r.ignitionOn ? 'Ignition On' : 'Ignition Off'),
          _Col('Date Time', 2, (r) => _v(r.startTime)),
          _Col('Location', 4, _loc),
        ];
      case ReportType.stoppage:
        return [
          _vehicle,
          _Col('Start', 2, (r) => _v(r.startTime)),
          _Col('End', 2, (r) => _v(r.endTime)),
          _Col('Duration', 1.2, (r) => _v(r.duration)),
          _Col('Location', 4, _loc),
        ];
      case ReportType.trip:
        return [
          _vehicle,
          _Col('Start', 2, (r) => _v(r.startTime)),
          _Col('End', 2, (r) => _v(r.endTime)),
          _Col('Duration', 1.2, (r) => _v(r.duration)),
          _Col('Distance', 1.2, (r) => _v(r.distance)),
          _Col('Start Location', 3, (r) => _v(r.startLocation)),
          _Col('End Location', 3, (r) => _v(r.endLocation)),
        ];
      case ReportType.daily:
        return [
          _vehicle,
          _Col('Start', 2, (r) => _v(r.startTime)),
          _Col('End', 2, (r) => _v(r.endTime)),
          _Col('Distance', 1.2, (r) => _v(r.distance)),
          _Col('Running', 1.2, (r) => _v(r.running)),
          _Col('Stopped', 1.2, (r) => _v(r.stopped)),
          _Col('Idle', 1.2, (r) => _v(r.idle)),
          _Col('Engine Hours', 1.2, (r) => _v(r.engineHours)),
          _Col('Avg Speed', 1.2, (r) => _v(r.averageSpeed)),
          _Col('Max Speed', 1.2, (r) => _v(r.maxSpeed)),
          _Col('Start Odometer', 1.4, (r) => _odometer(r.startOdometer)),
          _Col('End Odometer', 1.4, (r) => _odometer(r.endOdometer)),
        ];
      case ReportType.summary:
        return [
          _vehicle,
          _Col('Distance', 1.2, (r) => _v(r.distance)),
          _Col('Running', 1.2, (r) => _v(r.running)),
          _Col('Stopped', 1.2, (r) => _v(r.stopped)),
          _Col('Idle', 1.2, (r) => _v(r.idle)),
          _Col('Engine Hours', 1.2, (r) => _v(r.engineHours)),
          _Col('Avg Speed', 1.2, (r) => _v(r.averageSpeed)),
          _Col('Max Speed', 1.2, (r) => _v(r.maxSpeed)),
          _Col('Start Odometer', 1.4, (r) => _odometer(r.startOdometer)),
          _Col('End Odometer', 1.4, (r) => _odometer(r.endOdometer)),
          _Col('Start Location', 2.5, (r) => _v(r.startLocation)),
          _Col('End Location', 2.5, (r) => _v(r.endLocation)),
        ];
      case ReportType.overspeed:
        return [
          _vehicle,
          _Col('Date Time', 2, (r) => _v(r.startTime)),
          _Col('Speed', 1.2, (r) => _v(r.speed)),
          _Col('Location', 4, _loc),
        ];
      case ReportType.geofence:
        return [
          _vehicle,
          _Col('Event', 1.5,
              (r) => r.isGeofenceEnter ? 'Geofence Enter' : 'Geofence Exit'),
          _Col('Date Time', 2, (r) => _v(r.startTime)),
          _Col('Location', 4, _loc),
        ];
      case ReportType.alerts:
        return [
          _vehicle,
          _Col('Alert', 1.8, (r) => _v(r.status)),
          _Col('Date Time', 2, (r) => _v(r.startTime)),
          _Col('Location', 4, _loc),
        ];
    }
  }

  /// [total], when given, is the server's row count when it is larger than
  /// [rows] (the server sends at most 2000 rows); the PDF then says so.
  static Future<Uint8List> build({
    required ReportType type,
    required String vehicle,
    required DateTime from,
    required DateTime to,
    required List<ReportItem> rows,
    int? total,
  }) async {
    // Leave out columns the API sent nothing for (e.g. Location in the
    // ignition report), instead of a column of dashes.
    final cols = _columns(type)
        .where((c) => rows.any((r) => c.value(r) != '-'))
        .toList();
    final wide = cols.length > 5;
    final dateFormat = DateFormat('dd MMM yyyy');
    final range = from == to
        ? dateFormat.format(from)
        : '${dateFormat.format(from)} - ${dateFormat.format(to)}';
    final fontSize = wide ? 7.0 : 9.0;

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: wide ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${type.title}  $vehicle',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                total == null
                    ? range
                    : '$range  (newest ${rows.length} of $total rows)',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: [for (final c in cols) c.header],
            data: [
              for (final r in rows) [for (final c in cols) c.value(r)],
            ],
            headerStyle: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: pw.TextStyle(fontSize: fontSize),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(
              vertical: 4,
              horizontal: 4,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              for (var i = 0; i < cols.length; i++)
                i: pw.FlexColumnWidth(cols[i].flex),
            },
          ),
        ],
      ),
    );
    return doc.save();
  }
}
