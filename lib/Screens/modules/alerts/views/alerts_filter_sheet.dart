import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/alerts_controller.dart';

/// Opens the Alerts filter sheet. Choices reach the list only on Apply.
Future<void> showAlertsFilterSheet() {
  return Get.bottomSheet(
    const AlertsFilterSheet(),
    backgroundColor: Colors.white,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  );
}

enum _FilterTab { eventTypes, vehicles, date }

/// One selectable alert: [key] is the API `alert` value, [label] is what the user sees.
class _AlertOption {
  final String key;
  final String label;
  const _AlertOption(this.key, this.label);
}

const List<_AlertOption> _alertOptions = [
  _AlertOption('ignitionOn', 'Ignition On'),
  _AlertOption('ignitionOff', 'Ignition Off'),
  _AlertOption('emergencyOn', 'Emergency On'),
  _AlertOption('emergencyOff', 'Emergency Off'),
  _AlertOption('wireDisconnect', 'Wire Disconnect'),
  _AlertOption('powerDisconnect', 'Power Disconnect'),
  _AlertOption('powerRestored', 'Power Restored'),
  _AlertOption('tilt', 'Tilt'),
  _AlertOption('boxOpen', 'Box Open'),
  _AlertOption('rashTurning', 'Rash Turning'),
  _AlertOption('deviceOverspeed', 'Device Overspeed'),
  _AlertOption('geofenceEntry', 'Geofence Entry'),
  _AlertOption('geofenceExit', 'Geofence Exit'),
  _AlertOption('geofenceOverspeed', 'Geofence Overspeed'),
  _AlertOption('impactCrash', 'Impact Crash'),
];

class AlertsFilterSheet extends StatefulWidget {
  const AlertsFilterSheet({super.key});

  @override
  State<AlertsFilterSheet> createState() => _AlertsFilterSheetState();
}

class _AlertsFilterSheetState extends State<AlertsFilterSheet> {
  static const Color _accent = Color(0xFF009FE3);
  static const Color _unchecked = Color(0xFFBDC1C6);
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  final AlertsController _controller = Get.find<AlertsController>();

  _FilterTab _tab = _FilterTab.eventTypes;

  // Local copies: nothing reaches the list until Apply.
  // _types holds the API alert keys (e.g. "ignitionOn").
  late final Set<String> _types = {..._controller.selectedTypes};
  late final Set<String> _vehicles = {..._controller.selectedVehicles};
  late DateTime? _from = _controller.fromDate.value;
  late DateTime? _to = _controller.toDate.value;

  void _apply() {
    _controller.selectedTypes
      ..clear()
      ..addAll(_types);
    _controller.selectedVehicles
      ..clear()
      ..addAll(_vehicles);
    _controller.fromDate.value = _from;
    _controller.toDate.value = _to;
    _controller.applyFilters();
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.68;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sidebar(),
                Container(
                  width: 1.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(1, 0),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _content()),
              ],
            ),
          ),
          _footer(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- sidebar

  Widget _sidebar() {
    return SizedBox(
      width: 130,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sidebarItem('Event Types', _FilterTab.eventTypes),
            _sidebarItem('Vehicles', _FilterTab.vehicles),
            _sidebarItem('Date', _FilterTab.date),
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem(String label, _FilterTab tab) {
    final selected = _tab == tab;
    return InkWell(
      onTap: () => setState(() => _tab = tab),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? _accent : Colors.black,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- content

  Widget _content() {
    switch (_tab) {
      case _FilterTab.eventTypes:
        return _checkList(
          allLabel: 'All Events',
          options: _alertOptions,
          selected: _types,
        );
      case _FilterTab.vehicles:
        return _checkList(
          allLabel: 'All Vehicles',
          options: _controller.vehicleNumbers
              .map((v) => _AlertOption(v, v))
              .toList(),
          selected: _vehicles,
        );
      case _FilterTab.date:
        return _dateTab();
    }
  }

  /// "All" is checked when nothing specific is selected.
  Widget _checkList({
    required String allLabel,
    required List<_AlertOption> options,
    required Set<String> selected,
  }) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      children: [
        _checkRow(
          allLabel,
          selected.isEmpty,
          () => setState(selected.clear),
        ),
        for (final o in options)
          _checkRow(o.label, selected.contains(o.key), () {
            setState(() {
              if (!selected.remove(o.key)) selected.add(o.key);
            });
          }),
      ],
    );
  }

  Widget _checkRow(String label, bool checked, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: checked ? _accent : _unchecked,
                borderRadius: BorderRadius.circular(3),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- date

  Widget _dateTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _dateBox(
          label: 'From',
          value: _from,
          firstDate: DateTime(2000),
          lastDate: _to ?? DateTime(2100),
          onPick: (d) => setState(() => _from = d),
          onClear: () => setState(() => _from = null),
        ),
        const SizedBox(height: 12),
        _dateBox(
          label: 'To',
          value: _to,
          firstDate: _from ?? DateTime(2000),
          lastDate: DateTime(2100),
          onPick: (d) => setState(() => _to = d),
          onClear: () => setState(() => _to = null),
        ),
      ],
    );
  }

  Widget _dateBox({
    required String label,
    required DateTime? value,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onPick,
    required VoidCallback onClear,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        var initial = value ?? DateTime.now();
        if (initial.isBefore(firstDate)) initial = firstDate;
        if (initial.isAfter(lastDate)) initial = lastDate;
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value == null ? 'Any' : _dateFormat.format(value),
                    style: const TextStyle(fontSize: 13, color: Colors.black),
                  ),
                ],
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 18, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- footer

  Widget _footer() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}